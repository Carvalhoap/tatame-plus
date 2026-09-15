import {createHash} from "crypto";
import {getAuth} from "firebase-admin/auth";
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

const academyId = "gracie-barra-neves";

interface SelfRegisterUserData {
  invitationCode?: unknown;
  displayName?: unknown;
  email?: unknown;
  password?: unknown;
  phone?: unknown;
}

function requiredString(
  value: unknown,
  fieldName: string,
): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0
  ) {
    throw new HttpsError(
      "invalid-argument",
      `O campo ${fieldName} é obrigatório.`,
    );
  }

  return value.trim();
}

function invalidInvitationError(): HttpsError {
  return new HttpsError(
    "failed-precondition",
    "O convite é inválido, expirou ou já foi utilizado.",
  );
}

function validateInvitationCode(
  value: unknown,
): string {
  const normalizedCode = requiredString(
    value,
    "código do convite",
  )
    .replace(/[\s-]/g, "")
    .toUpperCase();

  if (!/^[A-F0-9]{24}$/.test(normalizedCode)) {
    throw invalidInvitationError();
  }

  return normalizedCode;
}

function invitationHash(
  normalizedCode: string,
): string {
  return createHash("sha256")
    .update(normalizedCode)
    .digest("hex");
}

function assertInvitationAvailable(
  exists: boolean,
  data: Record<string, unknown> | undefined,
): void {
  const expiresAt = data?.expiresAt;

  if (
    !exists ||
    data?.academyId !== academyId ||
    data?.status !== "available" ||
    !(expiresAt instanceof Timestamp) ||
    expiresAt.toMillis() <= Date.now()
  ) {
    throw invalidInvitationError();
  }
}

function validateEmail(
  value: unknown,
): string {
  const email = requiredString(
    value,
    "email",
  ).toLowerCase();

  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "O e-mail informado é inválido.",
    );
  }

  return email;
}

function validatePassword(
  value: unknown,
): string {
  const password = requiredString(
    value,
    "password",
  );

  if (
    password.length < 8 ||
    password.length > 128
  ) {
    throw new HttpsError(
      "invalid-argument",
      "A senha deve ter entre 8 e 128 caracteres.",
    );
  }

  return password;
}

function optionalPhone(
  value: unknown,
): string | null {
  if (
    value === null ||
    value === undefined
  ) {
    return null;
  }

  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "O telefone informado é inválido.",
    );
  }

  const phone = value.trim();

  if (phone.length > 30) {
    throw new HttpsError(
      "invalid-argument",
      "O telefone informado é inválido.",
    );
  }

  return phone.length === 0 ? null : phone;
}

function errorCode(
  error: unknown,
): string {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error
  ) {
    return String(error.code);
  }

  return "unknown";
}

function convertAuthError(
  error: unknown,
): HttpsError {
  const code = errorCode(error);

  if (code === "auth/invalid-email") {
    return new HttpsError(
      "invalid-argument",
      "O e-mail informado é inválido.",
    );
  }

  if (
    code === "auth/email-already-exists" ||
    code === "auth/invalid-password"
  ) {
    return new HttpsError(
      "failed-precondition",
      "Não foi possível concluir o cadastro com os dados informados.",
    );
  }

  return new HttpsError(
    "internal",
    "Não foi possível solicitar o cadastro.",
  );
}

export const selfRegisterUser = onCall(
  {
    region: "southamerica-east1",
    enforceAppCheck: false,
    maxInstances: 10,
  },
  async (request) => {
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
      request.data as SelfRegisterUserData;

    const normalizedInvitationCode =
      validateInvitationCode(data.invitationCode);

    const displayName = requiredString(
      data.displayName,
      "nome",
    );

    if (
      displayName.length < 3 ||
      displayName.length > 100
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Informe um nome entre 3 e 100 caracteres.",
      );
    }

    const email = validateEmail(data.email);
    const password = validatePassword(
      data.password,
    );
    const phone = optionalPhone(data.phone);

    const codeHash = invitationHash(
      normalizedInvitationCode,
    );

    const auth = getAuth();
    const firestore = getFirestore();

    const inviteReference = firestore
      .collection("academies")
      .doc(academyId)
      .collection("registrationInvites")
      .doc(codeHash);

    let createdUid: string | null = null;

    try {
      const initialInviteSnapshot =
        await inviteReference.get();

      assertInvitationAvailable(
        initialInviteSnapshot.exists,
        initialInviteSnapshot.data(),
      );

      const userRecord = await auth.createUser({
        displayName,
        email,
        password,
        disabled: false,
        emailVerified: false,
      });

      createdUid = userRecord.uid;

      const userReference = firestore
        .collection("users")
        .doc(createdUid);

      const memberReference = firestore
        .collection("academies")
        .doc(academyId)
        .collection("members")
        .doc(createdUid);

      const auditReference = firestore
        .collection("academies")
        .doc(academyId)
        .collection("auditLogs")
        .doc();

      await firestore.runTransaction(
        async (transaction) => {
          const inviteSnapshot =
            await transaction.get(inviteReference);

          assertInvitationAvailable(
            inviteSnapshot.exists,
            inviteSnapshot.data(),
          );

          transaction.create(userReference, {
            displayName,
            email,
            phone,
            photoUrl: null,
            isActive: false,
            registrationStatus: "pending",
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });

          transaction.create(memberReference, {
            userId: createdUid,
            displayName,
            email,
            phone,
            photoUrl: null,
            roles: {
              admin: false,
              partner: false,
              teacher: false,
              student: false,
              guardian: false,
            },
            status: "pending",
            isActive: false,
            joinedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            authorizedBy: null,
            rolesUpdatedAt: null,
          });

          transaction.update(inviteReference, {
            status: "used",
            usedAt: FieldValue.serverTimestamp(),
            usedBy: createdUid,
          });

          transaction.create(auditReference, {
            action: "userSelfRegistrationRequested",
            entityType: "user",
            entityId: createdUid,
            performedBy: createdUid,
            createdAt: FieldValue.serverTimestamp(),
            before: null,
            after: {
              displayName,
              email,
              phone,
              status: "pending",
            },
            metadata: {
              academyId,
              registrationInvitationId: codeHash,
            },
          });
        },
      );

      logger.info(
        "Solicitação de cadastro por convite criada.",
        {
          academyId,
          createdUid,
        },
      );

      return {
        success: true,
        userId: createdUid,
      };
    } catch (error) {
      logger.error(
        "Falha no cadastro por convite.",
        {
          academyId,
          createdUid,
          errorCode: errorCode(error),
        },
      );

      if (createdUid !== null) {
        try {
          await auth.deleteUser(createdUid);
        } catch (rollbackError) {
          logger.error(
            "Falha no rollback do cadastro por convite.",
            {
              createdUid,
              errorCode: errorCode(rollbackError),
            },
          );
        }
      }

      if (error instanceof HttpsError) {
        throw error;
      }

      throw convertAuthError(error);
    }
  },
);
