import {getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

interface DeletePaymentProofFileData {
  storagePath?: unknown;
}

interface ParsedStoragePath {
  storagePath: string;
  academyId: string;
  studentId: string;
}

const storagePathPattern = new RegExp(
  "^academies/([A-Za-z0-9_-]{1,100})/" +
  "financeProofs/([A-Za-z0-9_-]{1,150})/" +
  "[^/]{1,255}$",
);

function parseStoragePath(
  value: unknown,
): ParsedStoragePath {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "O caminho do comprovante é inválido.",
    );
  }

  const storagePath = value.trim();
  const match = storagePathPattern.exec(storagePath);

  if (match === null) {
    throw new HttpsError(
      "invalid-argument",
      "O caminho do comprovante é inválido.",
    );
  }

  return {
    storagePath,
    academyId: match[1],
    studentId: match[2],
  };
}

export const deletePaymentProofFile = onCall(
  {
    region: "southamerica-east1",
    enforceAppCheck: false,
    maxInstances: 10,
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
      request.data as DeletePaymentProofFileData;

    const {
      storagePath,
      academyId,
      studentId,
    } = parseStoragePath(data.storagePath);

    const requesterUid = request.auth.uid;
    const firestore = getFirestore();

    const academyReference = firestore
      .collection("academies")
      .doc(academyId);

    const memberReference = academyReference
      .collection("members")
      .doc(requesterUid);

    const studentReference = academyReference
      .collection("students")
      .doc(studentId);

    const referencesQuery = academyReference
      .collection("paymentProofs")
      .where("storagePath", "==", storagePath)
      .limit(1);

    const [
      memberSnapshot,
      studentSnapshot,
      referencesSnapshot,
    ] = await Promise.all([
      memberReference.get(),
      studentReference.get(),
      referencesQuery.get(),
    ]);

    const memberData = memberSnapshot.data();
    const studentData = studentSnapshot.data();

    if (
      !memberSnapshot.exists ||
      memberData?.status !== "active"
    ) {
      throw new HttpsError(
        "permission-denied",
        "O usuário não está ativo nesta academia.",
      );
    }

    if (!studentSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "O aluno não foi encontrado.",
      );
    }

    const ownsStudent =
      studentData?.userId === requesterUid;

    const guardianIds = studentData?.guardianIds;

    const guardsStudent =
      memberData?.roles?.guardian === true &&
      Array.isArray(guardianIds) &&
      guardianIds.includes(requesterUid);

    if (!ownsStudent && !guardsStudent) {
      throw new HttpsError(
        "permission-denied",
        "Você não pode excluir este arquivo.",
      );
    }

    if (!referencesSnapshot.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Um comprovante vinculado não pode ser excluído.",
      );
    }

    await getStorage()
      .bucket()
      .file(storagePath)
      .delete({ignoreNotFound: true});

    logger.info(
      "Arquivo de comprovante sem vínculo excluído.",
      {
        academyId,
        studentId,
        requesterUid,
      },
    );

    return {
      success: true,
    };
  },
);
