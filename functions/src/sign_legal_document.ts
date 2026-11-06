import {createHash, randomUUID} from "node:crypto";

import {
  DocumentSnapshot,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  PDFDocument,
  rgb,
  StandardFonts,
} from "pdf-lib";

interface SignLegalDocumentData {
  academyId?: unknown;
  assignmentId?: unknown;
  accepted?: unknown;
  signaturePngBase64?: unknown;
  imageChoices?: unknown;
}

interface ImageChoices {
  institutional: boolean;
  paidAdvertising: boolean;
}

interface SigningContext {
  documentType: string;
  imageChoices: ImageChoices | null;
  documentId: string;
  documentVersion: string;
  documentTitle: string;
  documentStoragePath: string;
  documentSha256: string;
  studentId: string;
  studentName: string;
  signerRole: string;
  signerName: string;
}

interface ExistingSignatureResult {
  alreadySigned: true;
  signatureStoragePath: string;
  signedPdfStoragePath: string;
  signedPdfSha256: string;
  signedAt: string;
}

interface PendingSignatureResult {
  alreadySigned: false;
  context: SigningContext;
}

type PreflightResult =
  | ExistingSignatureResult
  | PendingSignatureResult;

const acceptanceText =
  "Declaro que li integralmente o documento, compreendi seu " +
  "conteúdo e manifesto livremente minha concordância por meio " +
  "desta assinatura eletrônica.";

const idPattern = /^[A-Za-z0-9_-]{1,150}$/;
const sha256Pattern = /^[a-f0-9]{64}$/i;

const maxSignatureBytes = 1024 * 1024;
const maxDocumentBytes = 10 * 1024 * 1024;

const imageAcceptanceText =
  "Declaro que li o documento e confirmo as escolhas de autorização " +
  "e recusa registradas abaixo por meio desta assinatura eletrônica.";

function parseImageChoices(
  documentType: string,
  value: unknown,
): ImageChoices | null {
  if (documentType !== "imageAuthorization") {
    if (value !== undefined && value !== null) {
      throw new HttpsError(
        "invalid-argument",
        "Este documento não recebe escolhas de imagem.",
      );
    }
    return null;
  }

  const choices = recordValue(value);

  if (
    typeof choices.institutional !== "boolean" ||
    typeof choices.paidAdvertising !== "boolean" ||
    Object.keys(choices).some(
      (key) => key !== "institutional" && key !== "paidAdvertising",
    )
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Informe separadamente as duas escolhas de uso de imagem.",
    );
  }

  return {
    institutional: choices.institutional,
    paidAdvertising: choices.paidAdvertising,
  };
}

function parseId(
  value: unknown,
  fieldLabel: string,
): string {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldLabel} inválido.`,
    );
  }

  const normalized = value.trim();

  if (!idPattern.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldLabel} inválido.`,
    );
  }

  return normalized;
}

function recordValue(
  value: unknown,
): Record<string, unknown> {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    return {};
  }

  return value as Record<string, unknown>;
}

function snapshotData(
  snapshot: DocumentSnapshot,
  message: string,
): Record<string, unknown> {
  if (!snapshot.exists) {
    throw new HttpsError("not-found", message);
  }

  return recordValue(snapshot.data());
}

function requiredString(
  data: Record<string, unknown>,
  field: string,
  message: string,
): string {
  const value = data[field];

  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError(
      "failed-precondition",
      message,
    );
  }

  return value.trim();
}

function optionalString(
  value: unknown,
): string {
  return typeof value === "string" ? value.trim() : "";
}

function sha256(
  bytes: Uint8Array,
): string {
  return createHash("sha256")
    .update(bytes)
    .digest("hex");
}

function parseSignature(
  value: unknown,
): Buffer {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "A assinatura desenhada não foi enviada.",
    );
  }

  const normalized = value
    .trim()
    .replace(/^data:image\/png;base64,/i, "")
    .replace(/\s/g, "");

  if (
    normalized.length === 0 ||
    normalized.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(normalized)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A assinatura enviada não é um PNG válido.",
    );
  }

  const bytes = Buffer.from(normalized, "base64");

  if (
    bytes.length < 100 ||
    bytes.length > maxSignatureBytes
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A assinatura deve possuir no máximo 1 MB.",
    );
  }

  const hasPngHeader =
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a;

  if (!hasPngHeader) {
    throw new HttpsError(
      "invalid-argument",
      "A assinatura enviada não é um PNG válido.",
    );
  }

  return bytes;
}

function timestampValue(
  value: unknown,
): Timestamp | null {
  return value instanceof Timestamp ? value : null;
}

function validateAccess(
  requesterUid: string,
  memberSnapshot: DocumentSnapshot,
  studentSnapshot: DocumentSnapshot,
  assignmentSnapshot: DocumentSnapshot,
): {
  member: Record<string, unknown>;
  student: Record<string, unknown>;
  assignment: Record<string, unknown>;
} {
  const member = snapshotData(
    memberSnapshot,
    "Seu vínculo com a academia não foi encontrado.",
  );

  if (member.status !== "active") {
    throw new HttpsError(
      "permission-denied",
      "Seu acesso à academia não está ativo.",
    );
  }

  const student = snapshotData(
    studentSnapshot,
    "O aluno não foi encontrado.",
  );

  const assignment = snapshotData(
    assignmentSnapshot,
    "A atribuição do documento não foi encontrada.",
  );

  if (assignment.assignedSignerUserId !== requesterUid) {
    throw new HttpsError(
      "permission-denied",
      "Este documento não foi atribuído a você.",
    );
  }

  const signerRole = assignment.requiredSignerRole;

  if (signerRole === "student") {
    if (student.userId !== requesterUid) {
      throw new HttpsError(
        "permission-denied",
        "O aluno vinculado não corresponde ao usuário atual.",
      );
    }
  } else if (signerRole === "guardian") {
    const roles = recordValue(member.roles);
    const guardianIds = student.guardianIds;

    const isGuardian =
      roles.guardian === true &&
      Array.isArray(guardianIds) &&
      guardianIds.includes(requesterUid);

    if (!isGuardian) {
      throw new HttpsError(
        "permission-denied",
        "Você não é responsável por este aluno.",
      );
    }
  } else {
    throw new HttpsError(
      "failed-precondition",
      "O papel do assinante é inválido.",
    );
  }

  return {
    member,
    student,
    assignment,
  };
}

function validatePendingDocument(
  academyId: string,
  now: Timestamp,
  assignment: Record<string, unknown>,
  documentSnapshot: DocumentSnapshot,
): SigningContext {
  if (assignment.status !== "pending") {
    throw new HttpsError(
      "failed-precondition",
      "Este documento não está pendente de assinatura.",
    );
  }

  const assignmentExpiresAt =
    timestampValue(assignment.expiresAt);

  if (
    assignmentExpiresAt !== null &&
    now.toMillis() >= assignmentExpiresAt.toMillis()
  ) {
    throw new HttpsError(
      "failed-precondition",
      "O prazo para assinar este documento expirou.",
    );
  }

  const document = snapshotData(
    documentSnapshot,
    "O documento original não foi encontrado.",
  );

  if (document.status !== "published") {
    throw new HttpsError(
      "failed-precondition",
      "Este documento não está publicado.",
    );
  }

  const assignmentVersion = requiredString(
    assignment,
    "documentVersion",
    "A versão atribuída é inválida.",
  );

  const documentVersion = requiredString(
    document,
    "version",
    "A versão do documento é inválida.",
  );

  if (assignmentVersion !== documentVersion) {
    throw new HttpsError(
      "failed-precondition",
      "A versão atribuída não corresponde ao documento atual.",
    );
  }

  const effectiveAt = timestampValue(document.effectiveAt);
  const documentExpiresAt =
    timestampValue(document.expiresAt);

  if (
    effectiveAt !== null &&
    now.toMillis() < effectiveAt.toMillis()
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Este documento ainda não está vigente.",
    );
  }

  if (
    documentExpiresAt !== null &&
    now.toMillis() >= documentExpiresAt.toMillis()
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Este documento não está mais vigente.",
    );
  }

  const documentId = requiredString(
    assignment,
    "documentId",
    "O documento atribuído é inválido.",
  );

  const storagePath = requiredString(
    document,
    "storagePath",
    "O arquivo original não está configurado.",
  );

  const expectedPrefix =
    `academies/${academyId}/legalDocuments/`;

  if (!storagePath.startsWith(expectedPrefix)) {
    throw new HttpsError(
      "failed-precondition",
      "O caminho do documento original é inválido.",
    );
  }

  const documentSha256 = requiredString(
    document,
    "documentSha256",
    "O hash do documento original não está configurado.",
  ).toLowerCase();

  if (!sha256Pattern.test(documentSha256)) {
    throw new HttpsError(
      "failed-precondition",
      "O hash do documento original é inválido.",
    );
  }

  return {
    documentId,
    documentVersion,
    documentType: requiredString(
      document,
      "type",
      "O tipo do documento é inválido.",
    ),
    imageChoices: null,
    documentTitle: requiredString(
      document,
      "title",
      "O título do documento é inválido.",
    ),
    documentStoragePath: storagePath,
    documentSha256,
    studentId: requiredString(
      assignment,
      "studentId",
      "O aluno atribuído é inválido.",
    ),
    studentName: requiredString(
      assignment,
      "studentName",
      "O nome do aluno é inválido.",
    ),
    signerRole: requiredString(
      assignment,
      "requiredSignerRole",
      "O papel do assinante é inválido.",
    ),
    signerName: "",
  };
}

function existingSignature(
  requesterUid: string,
  snapshot: DocumentSnapshot,
): ExistingSignatureResult | null {
  if (!snapshot.exists) {
    return null;
  }

  const signature = recordValue(snapshot.data());

  if (signature.signerUserId !== requesterUid) {
    throw new HttpsError(
      "permission-denied",
      "A assinatura existente pertence a outro usuário.",
    );
  }

  const signedAt = timestampValue(signature.signedAt);

  return {
    alreadySigned: true,
    signatureStoragePath: requiredString(
      signature,
      "signatureStoragePath",
      "O arquivo da assinatura não foi localizado.",
    ),
    signedPdfStoragePath: requiredString(
      signature,
      "signedPdfStoragePath",
      "O PDF assinado não foi localizado.",
    ),
    signedPdfSha256: requiredString(
      signature,
      "signedPdfSha256",
      "O hash do PDF assinado não foi localizado.",
    ),
    signedAt: signedAt?.toDate().toISOString() ?? "",
  };
}

function asciiText(
  value: string,
): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\x20-\x7E]/g, "?");
}

function limitedText(
  value: string,
  maximumLength: number,
): string {
  const normalized = asciiText(value);

  if (normalized.length <= maximumLength) {
    return normalized;
  }

  return `${normalized.substring(0, maximumLength - 3)}...`;
}

async function createSignedPdf(
  originalPdfBytes: Buffer,
  signatureBytes: Buffer,
  context: SigningContext,
  assignmentId: string,
  signedAt: Timestamp,
  ipAddress: string,
  userAgent: string,
): Promise<Buffer> {
  let pdfDocument: PDFDocument;

  try {
    pdfDocument = await PDFDocument.load(
      originalPdfBytes,
      {
        ignoreEncryption: false,
        updateMetadata: false,
      },
    );
  } catch (error) {
    logger.warn(
      "PDF original inválido ou protegido.",
      {
        assignmentId,
        error: String(error),
      },
    );

    throw new HttpsError(
      "failed-precondition",
      "O PDF original é inválido ou possui proteção incompatível.",
    );
  }

  const font = await pdfDocument.embedFont(
    StandardFonts.Helvetica,
  );

  const boldFont = await pdfDocument.embedFont(
    StandardFonts.HelveticaBold,
  );

  let signatureImage;

  try {
    signatureImage = await pdfDocument.embedPng(
      signatureBytes,
    );
  } catch (error) {
    logger.warn(
      "Imagem de assinatura inválida.",
      {
        assignmentId,
        error: String(error),
      },
    );

    throw new HttpsError(
      "invalid-argument",
      "Não foi possível validar a assinatura desenhada.",
    );
  }

  const page = pdfDocument.addPage([595.28, 841.89]);

  page.drawText(
    "COMPROVANTE DE ASSINATURA ELETRONICA",
    {
      x: 48,
      y: 785,
      size: 15,
      font: boldFont,
      color: rgb(0.08, 0.16, 0.28),
    },
  );

  page.drawText(
    "Esta pagina integra o documento original e registra " +
      "as evidencias da assinatura.",
    {
      x: 48,
      y: 760,
      size: 9,
      font,
      color: rgb(0.3, 0.3, 0.3),
    },
  );

  const signedDate = new Intl.DateTimeFormat(
    "pt-BR",
    {
      timeZone: "America/Sao_Paulo",
      dateStyle: "long",
      timeStyle: "long",
    },
  ).format(signedAt.toDate());

  const rows = [
    ["Documento", context.documentTitle],
    ["Versao", context.documentVersion],
    ["Aluno", context.studentName],
    ["Assinante", context.signerName],
    [
      "Papel",
      context.signerRole === "guardian" ?
        "Responsavel legal" :
        "Aluno",
    ],
    ["Data e hora", signedDate],
    ["Identificador", assignmentId],
  ];

  let y = 720;

  for (const [label, value] of rows) {
    page.drawText(`${label}:`, {
      x: 48,
      y,
      size: 9,
      font: boldFont,
      color: rgb(0.1, 0.1, 0.1),
    });

    page.drawText(
      limitedText(value, 82),
      {
        x: 135,
        y,
        size: 9,
        font,
        color: rgb(0.1, 0.1, 0.1),
      },
    );

    y -= 25;
  }

  page.drawText("Declaracao de aceite:", {
    x: 48,
    y: 520,
    size: 10,
    font: boldFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  page.drawText(
    context.imageChoices === null ?
      "Declaro que li integralmente o documento, compreendi " +
        "seu conteudo e manifesto" :
      "Declaro que li o documento e confirmo as escolhas de autorizacao",
    {
      x: 48,
      y: 500,
      size: 9,
      font,
      color: rgb(0.1, 0.1, 0.1),
    },
  );

  page.drawText(
    context.imageChoices === null ?
      "livremente minha concordancia por meio desta " +
        "assinatura eletronica." :
      "e recusa registradas abaixo por meio desta assinatura eletronica.",
    {
      x: 48,
      y: 484,
      size: 9,
      font,
      color: rgb(0.1, 0.1, 0.1),
    },
  );

  page.drawText("Assinatura desenhada:", {
    x: 48,
    y: 445,
    size: 10,
    font: boldFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  const imageDimensions = signatureImage.scaleToFit(
    300,
    115,
  );

  page.drawRectangle({
    x: 48,
    y: 305,
    width: 320,
    height: 125,
    borderWidth: 1,
    borderColor: rgb(0.7, 0.7, 0.7),
    color: rgb(1, 1, 1),
  });

  page.drawImage(signatureImage, {
    x: 58,
    y: 310,
    width: imageDimensions.width,
    height: imageDimensions.height,
  });

  page.drawText("SHA-256 do documento original:", {
    x: 48,
    y: 270,
    size: 8,
    font: boldFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  page.drawText(context.documentSha256, {
    x: 48,
    y: 255,
    size: 7,
    font,
    color: rgb(0.15, 0.15, 0.15),
  });

  page.drawText("Endereco de rede registrado:", {
    x: 48,
    y: 225,
    size: 8,
    font: boldFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  page.drawText(
    limitedText(ipAddress.length === 0 ? "Nao informado" : ipAddress, 70),
    {
      x: 205,
      y: 225,
      size: 8,
      font,
      color: rgb(0.15, 0.15, 0.15),
    },
  );

  page.drawText("Dispositivo/navegador:", {
    x: 48,
    y: 200,
    size: 8,
    font: boldFont,
    color: rgb(0.1, 0.1, 0.1),
  });

  page.drawText(
    limitedText(
      userAgent.length === 0 ? "Nao informado" : userAgent,
      88,
    ),
    {
      x: 48,
      y: 184,
      size: 7,
      font,
      color: rgb(0.15, 0.15, 0.15),
    },
  );

  page.drawText(
    "Documento processado pelo NexTatame. " +
      "A integridade pode ser conferida pelos hashes registrados.",
    {
      x: 48,
      y: 70,
      size: 8,
      font,
      color: rgb(0.35, 0.35, 0.35),
    },
  );

  pdfDocument.setTitle(
    limitedText(
      `${context.documentTitle} - assinado`,
      100,
    ),
  );

  pdfDocument.setSubject(
    "Documento assinado eletronicamente no NexTatame",
  );

  if (context.imageChoices !== null) {
    const choicesPage = pdfDocument.addPage([595.28, 841.89]);
    const choices = context.imageChoices;

    const lines = [
      "REGISTRO DAS ESCOLHAS DE IMAGEM E VOZ",
      "",
      `Documento: ${limitedText(context.documentTitle, 78)}`,
      `Versao: ${limitedText(context.documentVersion, 65)}`,
      `Aluno: ${limitedText(context.studentName, 78)}`,
      `Assinante: ${limitedText(context.signerName, 74)}`,
      `Atribuicao: ${assignmentId}`,
      "",
      "Publicacoes institucionais no Instagram e WhatsApp da academia:",
      choices.institutional ? "AUTORIZO" : "NAO AUTORIZO",
      "",
      "Anuncios pagos da academia no Instagram e WhatsApp:",
      choices.paidAdvertising ? "AUTORIZO" : "NAO AUTORIZO",
      "",
      "As escolhas foram informadas separadamente pelo assinante.",
      "A recusa nao impede a matricula nem a participacao nas aulas.",
      "Estas escolhas integram o documento e seu comprovante de assinatura.",
      "",
      `Data e hora: ${limitedText(signedDate, 88)}`,
    ];

    let choicesY = 785;
    for (const line of lines) {
      choicesPage.drawText(asciiText(line), {
        x: 48,
        y: choicesY,
        size: line === lines[0] ? 12 : 10,
        font: line === lines[0] ? boldFont : font,
        color: rgb(0.1, 0.1, 0.1),
      });
      choicesY -= 27;
    }
  }

  pdfDocument.setCreator("NexTatame");
  pdfDocument.setProducer("NexTatame");
  pdfDocument.setModificationDate(signedAt.toDate());

  const saved = await pdfDocument.save({
    useObjectStreams: false,
  });

  return Buffer.from(saved);
}

async function deleteQuietly(
  storagePath: string,
): Promise<void> {
  try {
    await getStorage()
      .bucket()
      .file(storagePath)
      .delete({ignoreNotFound: true});
  } catch (error) {
    logger.warn(
      "Não foi possível remover arquivo temporário.",
      {
        storagePath,
        error: String(error),
      },
    );
  }
}

export const signLegalDocument = onCall(
  {
    region: "southamerica-east1",
    enforceAppCheck: false,
    maxInstances: 10,
    memory: "512MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError(
        "unauthenticated",
        "É necessário estar autenticado.",
      );
    }

    if (
      typeof request.data !== "object" ||
      request.data === null ||
      Array.isArray(request.data)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Os dados enviados são inválidos.",
      );
    }

    const data =
      request.data as SignLegalDocumentData;

    if (data.accepted !== true) {
      throw new HttpsError(
        "failed-precondition",
        "É necessário aceitar expressamente o documento.",
      );
    }

    const academyId = parseId(
      data.academyId,
      "A academia",
    );

    const assignmentId = parseId(
      data.assignmentId,
      "A atribuição",
    );

    const signatureBytes = parseSignature(
      data.signaturePngBase64,
    );

    const requesterUid = request.auth.uid;
    const firestore = getFirestore();

    const academyReference = firestore
      .collection("academies")
      .doc(academyId);

    const memberReference = academyReference
      .collection("members")
      .doc(requesterUid);

    const assignmentReference = academyReference
      .collection("documentAssignments")
      .doc(assignmentId);

    const signatureReference = academyReference
      .collection("documentSignatures")
      .doc(assignmentId);

    const assignmentSnapshot =
      await assignmentReference.get();

    const assignmentPreview = snapshotData(
      assignmentSnapshot,
      "A atribuição do documento não foi encontrada.",
    );

    const studentId = requiredString(
      assignmentPreview,
      "studentId",
      "O aluno atribuído é inválido.",
    );

    const documentId = requiredString(
      assignmentPreview,
      "documentId",
      "O documento atribuído é inválido.",
    );

    if (
      !idPattern.test(studentId) ||
      !idPattern.test(documentId)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "A atribuição possui identificadores inválidos.",
      );
    }

    const studentReference = academyReference
      .collection("students")
      .doc(studentId);

    const documentReference = academyReference
      .collection("legalDocuments")
      .doc(documentId);

    const now = Timestamp.now();

    const preflight =
      await firestore.runTransaction<PreflightResult>(
        async (transaction) => {
          const [
            memberSnapshot,
            studentSnapshot,
            currentAssignmentSnapshot,
            documentSnapshot,
            currentSignatureSnapshot,
          ] = await Promise.all([
            transaction.get(memberReference),
            transaction.get(studentReference),
            transaction.get(assignmentReference),
            transaction.get(documentReference),
            transaction.get(signatureReference),
          ]);

          const access = validateAccess(
            requesterUid,
            memberSnapshot,
            studentSnapshot,
            currentAssignmentSnapshot,
          );

          const existing = existingSignature(
            requesterUid,
            currentSignatureSnapshot,
          );

          if (existing !== null) {
            return existing;
          }

          const context = validatePendingDocument(
            academyId,
            now,
            access.assignment,
            documentSnapshot,
          );

          const authToken = recordValue(
            request.auth?.token,
          );

          const signerName =
            optionalString(access.member.displayName) ||
            optionalString(access.member.name) ||
            optionalString(authToken.name) ||
            optionalString(authToken.email) ||
            requesterUid;

          return {
            alreadySigned: false,
            context: {
              ...context,
              imageChoices: parseImageChoices(
                context.documentType,
                data.imageChoices,
              ),
              signerName,
            },
          };
        },
      );

    if (preflight.alreadySigned) {
      return {
        success: true,
        ...preflight,
      };
    }

    const context = preflight.context;
    const bucket = getStorage().bucket();
    const originalFile = bucket.file(
      context.documentStoragePath,
    );

    let originalPdfBytes: Buffer;

    try {
      const [metadata] =
        await originalFile.getMetadata();

      const fileSize = Number(metadata.size ?? 0);

      if (
        fileSize <= 0 ||
        fileSize > maxDocumentBytes
      ) {
        throw new HttpsError(
          "failed-precondition",
          "O PDF original deve possuir no máximo 10 MB.",
        );
      }

      const contentType =
        optionalString(metadata.contentType)
          .toLowerCase();

      if (contentType !== "application/pdf") {
        throw new HttpsError(
          "failed-precondition",
          "O arquivo original não está identificado como PDF.",
        );
      }

      [originalPdfBytes] =
        await originalFile.download();
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error(
        "Falha ao carregar PDF original.",
        {
          academyId,
          assignmentId,
          error: String(error),
        },
      );

      throw new HttpsError(
        "not-found",
        "Não foi possível carregar o PDF original.",
      );
    }

    const calculatedDocumentSha256 =
      sha256(originalPdfBytes);

    if (
      calculatedDocumentSha256 !==
      context.documentSha256
    ) {
      throw new HttpsError(
        "failed-precondition",
        "A integridade do documento original não pôde ser confirmada.",
      );
    }

    const ipAddress = optionalString(
      request.rawRequest.ip,
    ).substring(0, 128);

    const userAgent = optionalString(
      request.rawRequest.headers["user-agent"],
    ).substring(0, 512);

    const signedAt = Timestamp.now();

    const signedPdfBytes = await createSignedPdf(
      originalPdfBytes,
      signatureBytes,
      context,
      assignmentId,
      signedAt,
      ipAddress,
      userAgent,
    );

    const signatureSha256 = sha256(signatureBytes);
    const signedPdfSha256 = sha256(signedPdfBytes);

    const nonce = randomUUID().replace(/-/g, "");

    const signatureStoragePath =
      `academies/${academyId}/documentSignatures/` +
      `${context.studentId}/${assignmentId}/` +
      `${nonce}-signature.png`;

    const signedPdfStoragePath =
      `academies/${academyId}/signedDocuments/` +
      `${context.studentId}/${assignmentId}/` +
      `${nonce}-signed.pdf`;

    const signatureFile = bucket.file(
      signatureStoragePath,
    );

    const signedPdfFile = bucket.file(
      signedPdfStoragePath,
    );

    try {
      await signatureFile.save(
        signatureBytes,
        {
          resumable: false,
          validation: "crc32c",
          metadata: {
            contentType: "image/png",
            cacheControl:
              "private, max-age=0, no-transform",
            metadata: {
              academyId,
              assignmentId,
              studentId: context.studentId,
              sha256: signatureSha256,
            },
          },
        },
      );

      await signedPdfFile.save(
        signedPdfBytes,
        {
          resumable: false,
          validation: "crc32c",
          metadata: {
            contentType: "application/pdf",
            cacheControl:
              "private, max-age=0, no-transform",
            metadata: {
              academyId,
              assignmentId,
              studentId: context.studentId,
              sha256: signedPdfSha256,
            },
          },
        },
      );
    } catch (error) {
      await Promise.all([
        deleteQuietly(signatureStoragePath),
        deleteQuietly(signedPdfStoragePath),
      ]);

      logger.error(
        "Falha ao salvar arquivos assinados.",
        {
          academyId,
          assignmentId,
          error: String(error),
        },
      );

      throw new HttpsError(
        "internal",
        "Não foi possível salvar o documento assinado.",
      );
    }

    let finalResult: ExistingSignatureResult | null =
      null;

    try {
      finalResult = await firestore.runTransaction<
        ExistingSignatureResult | null
      >(
        async (transaction) => {
          const [
            memberSnapshot,
            studentSnapshot,
            currentAssignmentSnapshot,
            documentSnapshot,
            currentSignatureSnapshot,
          ] = await Promise.all([
            transaction.get(memberReference),
            transaction.get(studentReference),
            transaction.get(assignmentReference),
            transaction.get(documentReference),
            transaction.get(signatureReference),
          ]);

          const access = validateAccess(
            requesterUid,
            memberSnapshot,
            studentSnapshot,
            currentAssignmentSnapshot,
          );

          const existing = existingSignature(
            requesterUid,
            currentSignatureSnapshot,
          );

          if (existing !== null) {
            return existing;
          }

          const currentContext = validatePendingDocument(
            academyId,
            Timestamp.now(),
            access.assignment,
            documentSnapshot,
          );

          const unchangedFields: (keyof SigningContext)[] = [
            "documentId",
            "documentVersion",
            "documentTitle",
            "documentType",
            "documentStoragePath",
            "documentSha256",
            "studentId",
            "studentName",
            "signerRole",
          ];

          if (
            currentContext.studentId !== studentReference.id ||
            currentContext.documentId !== documentReference.id ||
            unchangedFields.some(
              (field) => currentContext[field] !== context[field],
            )
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Os dados mudaram durante a assinatura. " +
                "Reabra o documento e tente novamente.",
            );
          }

          const authToken = recordValue(
            request.auth?.token,
          );

          const signerEmail =
            optionalString(authToken.email);

          transaction.create(
            signatureReference,
            {
              assignmentId,
              documentId: context.documentId,
              documentVersion:
                context.documentVersion,
              documentTitle:
                context.documentTitle,
              documentSha256:
                context.documentSha256,
              studentId: context.studentId,
              studentName: context.studentName,
              signerUserId: requesterUid,
              signerName: context.signerName,
              signerEmail,
              signerRole: context.signerRole,
              acceptanceText: context.imageChoices === null ?
                acceptanceText : imageAcceptanceText,
              ...(context.imageChoices === null ? {} : {
                imageChoices: context.imageChoices,
                imageChoicesVersion: 1,
              }),
              accepted: true,
              signatureStoragePath,
              signatureSha256,
              signedPdfStoragePath,
              signedPdfSha256,
              signedAt,
              evidenceVersion: 1,
              ipAddress,
              userAgent,
              originalStoragePath:
                context.documentStoragePath,
            },
          );

          transaction.update(
            assignmentReference,
            {
              status: "signed",
              signedAt,
            },
          );

          return null;
        },
      );
    } catch (error) {
      await Promise.all([
        deleteQuietly(signatureStoragePath),
        deleteQuietly(signedPdfStoragePath),
      ]);

      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error(
        "Falha ao registrar assinatura.",
        {
          academyId,
          assignmentId,
          requesterUid,
          error: String(error),
        },
      );

      throw new HttpsError(
        "internal",
        "Não foi possível concluir a assinatura.",
      );
    }

    if (finalResult !== null) {
      await Promise.all([
        deleteQuietly(signatureStoragePath),
        deleteQuietly(signedPdfStoragePath),
      ]);

      return {
        success: true,
        ...finalResult,
      };
    }

    logger.info(
      "Documento assinado com sucesso.",
      {
        academyId,
        assignmentId,
        requesterUid,
        signedPdfSha256,
      },
    );

    return {
      success: true,
      alreadySigned: false,
      signatureStoragePath,
      signedPdfStoragePath,
      signedPdfSha256,
      signedAt: signedAt.toDate().toISOString(),
    };
  },
);
