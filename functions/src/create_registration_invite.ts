import {createHash, randomBytes} from "crypto";
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

const invitationLifetimeMilliseconds =
  7 * 24 * 60 * 60 * 1000;

interface CreateRegistrationInviteData {
  academyId?: unknown;
}

function validateAcademyId(
  value: unknown,
): string {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9_-]{1,100}$/.test(value.trim())
  ) {
    throw new HttpsError(
      "invalid-argument",
      "O identificador da academia é inválido.",
    );
  }

  return value.trim();
}

async function assertAdministrator(
  academyId: string,
  requesterUid: string,
): Promise<void> {
  const memberSnapshot = await getFirestore()
    .collection("academies")
    .doc(academyId)
    .collection("members")
    .doc(requesterUid)
    .get();

  const memberData = memberSnapshot.data();

  if (
    !memberSnapshot.exists ||
    memberData?.status !== "active" ||
    memberData?.roles?.admin !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Somente administradores ativos podem gerar convites.",
    );
  }
}

function generateInvitationCode(): string {
  const rawCode = randomBytes(12)
    .toString("hex")
    .toUpperCase();

  return rawCode.match(/.{4}/g)?.join("-") ?? rawCode;
}

function hashInvitationCode(
  invitationCode: string,
): string {
  const normalizedCode =
    invitationCode.replace(/-/g, "");

  return createHash("sha256")
    .update(normalizedCode)
    .digest("hex");
}

export const createRegistrationInvite = onCall(
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
      request.data as CreateRegistrationInviteData;

    const academyId = validateAcademyId(
      data.academyId,
    );

    const requesterUid = request.auth.uid;

    await assertAdministrator(
      academyId,
      requesterUid,
    );

    const invitationCode =
      generateInvitationCode();

    const invitationHash =
      hashInvitationCode(invitationCode);

    const firestore = getFirestore();

    const inviteReference = firestore
      .collection("academies")
      .doc(academyId)
      .collection("registrationInvites")
      .doc(invitationHash);

    const auditReference = firestore
      .collection("academies")
      .doc(academyId)
      .collection("auditLogs")
      .doc();

    const expiresAt = Timestamp.fromMillis(
      Date.now() + invitationLifetimeMilliseconds,
    );

    const batch = firestore.batch();

    batch.create(inviteReference, {
      academyId,
      status: "available",
      createdBy: requesterUid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      usedAt: null,
      usedBy: null,
    });

    batch.create(auditReference, {
      action: "registrationInvitationCreated",
      entityType: "registrationInvite",
      entityId: invitationHash,
      performedBy: requesterUid,
      createdAt: FieldValue.serverTimestamp(),
      before: null,
      after: {
        status: "available",
        expiresAt,
      },
      metadata: {
        academyId,
      },
    });

    await batch.commit();

    logger.info(
      "Convite de cadastro criado.",
      {
        academyId,
        requesterUid,
      },
    );

    return {
      success: true,
      code: invitationCode,
      expiresAtMillis: expiresAt.toMillis(),
    };
  },
);
