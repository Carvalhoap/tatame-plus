import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

const academyId = "gracie-barra-neves";

interface SelfRegisterUserData {
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

function validateEmail(
  value: unknown,
): string {
  const email = requiredString(
    value,
    "email",
  ).toLowerCase();

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
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

  if (password.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "A senha precisa ter pelo menos 8 caracteres.",
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

  return phone.length === 0 ? null : phone;
}

function convertAuthError(
  error: unknown,
): HttpsError {
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error
  ) {
    const code = String(error.code);

    if (code === "auth/email-already-exists") {
      return new HttpsError(
        "already-exists",
        "Já existe uma conta cadastrada com este e-mail.",
      );
    }

    if (code === "auth/invalid-email") {
      return new HttpsError(
        "invalid-argument",
        "O e-mail informado é inválido.",
      );
    }
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

    const displayName = requiredString(
      data.displayName,
      "nome",
    );

    if (displayName.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Informe seu nome completo.",
      );
    }

    const email = validateEmail(data.email);
    const password = validatePassword(
      data.password,
    );
    const phone = optionalPhone(data.phone);

    const auth = getAuth();
    const firestore = getFirestore();

    let createdUid: string | null = null;

    try {
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

      const batch = firestore.batch();

      batch.create(userReference, {
        displayName,
        email,
        phone,
        photoUrl: null,
        isActive: false,
        registrationStatus: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      batch.create(memberReference, {
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

      batch.create(auditReference, {
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
        },
      });

      await batch.commit();

      logger.info(
        "Solicitação de cadastro criada.",
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
        "Falha no cadastro público.",
        {
          academyId,
          createdUid,
          error,
        },
      );

      if (createdUid !== null) {
        try {
          await auth.deleteUser(createdUid);
        } catch (rollbackError) {
          logger.error(
            "Falha no rollback do cadastro público.",
            {
              createdUid,
              rollbackError,
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
