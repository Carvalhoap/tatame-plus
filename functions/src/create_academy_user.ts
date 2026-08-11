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

const allowedRoles = [
  "admin",
  "partner",
  "teacher",
  "student",
  "guardian",
] as const;

type AllowedRole = (typeof allowedRoles)[number];

interface CreateAcademyUserData {
  academyId?: unknown;
  displayName?: unknown;
  email?: unknown;
  password?: unknown;
  phone?: unknown;
  roles?: unknown;
  isActive?: unknown;
}

interface SyncMemberProfilesData {
  academyId?: unknown;
}

function validateRequestData(
  value: unknown,
): CreateAcademyUserData {
  if (
    typeof value !== "object" ||
    value === null ||
    Array.isArray(value)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Os dados enviados são inválidos.",
    );
  }

  return value as CreateAcademyUserData;
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

function optionalString(
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

  const normalizedValue = value.trim();

  return normalizedValue.length === 0 ?
    null :
    normalizedValue;
}

function validateBoolean(
  value: unknown,
  fieldName: string,
): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      `O campo ${fieldName} é inválido.`,
    );
  }

  return value;
}

function validateEmail(
  value: unknown,
): string {
  const email = requiredString(
    value,
    "email",
  ).toLowerCase();

  const emailExpression =
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (!emailExpression.test(email)) {
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
      "A senha provisória precisa ter pelo menos 8 caracteres.",
    );
  }

  return password;
}

function validateRoles(
  value: unknown,
): Record<AllowedRole, boolean> {
  if (
    !Array.isArray(value) ||
    value.length === 0
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Informe pelo menos um perfil de acesso.",
    );
  }

  const requestedRoles = value.map((role) => {
    if (typeof role !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Um dos perfis informados é inválido.",
      );
    }

    return role;
  });

  const unknownRole = requestedRoles.find(
    (role) =>
      !allowedRoles.includes(
        role as AllowedRole,
      ),
  );

  if (unknownRole !== undefined) {
    throw new HttpsError(
      "invalid-argument",
      `O perfil ${unknownRole} não é permitido.`,
    );
  }

  const uniqueRoles =
    new Set(requestedRoles);

  return {
    admin: uniqueRoles.has("admin"),
    partner: uniqueRoles.has("partner"),
    teacher: uniqueRoles.has("teacher"),
    student: uniqueRoles.has("student"),
    guardian: uniqueRoles.has("guardian"),
  };
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

  const memberData =
    memberSnapshot.data();

  if (
    !memberSnapshot.exists ||
    memberData?.status !== "active" ||
    memberData?.roles?.admin !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Somente administradores ativos podem executar esta operação.",
    );
  }
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

    if (
      code === "auth/email-already-exists"
    ) {
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

    if (
      code === "auth/invalid-password"
    ) {
      return new HttpsError(
        "invalid-argument",
        "A senha provisória é inválida.",
      );
    }
  }

  return new HttpsError(
    "internal",
    "Não foi possível criar o usuário.",
  );
}

export const createAcademyUser = onCall(
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

    const data = validateRequestData(
      request.data,
    );

    const academyId = requiredString(
      data.academyId,
      "academyId",
    );

    const displayName = requiredString(
      data.displayName,
      "displayName",
    );

    const email = validateEmail(
      data.email,
    );

    const password = validatePassword(
      data.password,
    );

    const phone = optionalString(
      data.phone,
    );

    const roles = validateRoles(
      data.roles,
    );

    const isActive = validateBoolean(
      data.isActive,
      "isActive",
    );

    const status = isActive ?
      "active" :
      "inactive";

    const requesterUid =
      request.auth.uid;

    await assertAdministrator(
      academyId,
      requesterUid,
    );

    const auth = getAuth();
    const firestore = getFirestore();

    let createdUid: string | null = null;

    try {
      const userRecord =
        await auth.createUser({
          displayName,
          email,
          password,
          disabled: !isActive,
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

      batch.create(
        userReference,
        {
          displayName,
          email,
          phone,
          photoUrl: null,
          isActive,
          createdAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      batch.create(
        memberReference,
        {
          userId: createdUid,

          displayName,
          email,
          phone,
          photoUrl: null,

          roles,
          status,
          isActive,

          joinedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
          authorizedBy: requesterUid,
          rolesUpdatedAt:
            FieldValue.serverTimestamp(),
        },
      );

      batch.create(
        auditReference,
        {
          action:
            "academyUserCreated",
          entityType: "user",
          entityId: createdUid,
          performedBy: requesterUid,
          createdAt:
            FieldValue.serverTimestamp(),
          before: null,
          after: {
            displayName,
            email,
            phone,
            roles,
            isActive,
            status,
          },
          metadata: {
            academyId,
          },
        },
      );

      await batch.commit();

      logger.info(
        "Usuário da academia criado.",
        {
          academyId,
          createdUid,
          requesterUid,
          isActive,
        },
      );

      return {
        success: true,
        userId: createdUid,
      };
    } catch (error) {
      logger.error(
        "Falha ao criar usuário da academia.",
        {
          academyId,
          createdUid,
          requesterUid,
          error,
        },
      );

      if (createdUid !== null) {
        try {
          await auth.deleteUser(
            createdUid,
          );
        } catch (rollbackError) {
          logger.error(
            "Falha ao remover usuário durante rollback.",
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

export const syncAcademyMemberProfiles = onCall(
  {
    region: "southamerica-east1",
    enforceAppCheck: false,
    maxInstances: 2,
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
      request.data as SyncMemberProfilesData;

    const academyId = requiredString(
      data.academyId,
      "academyId",
    );

    const requesterUid =
      request.auth.uid;

    await assertAdministrator(
      academyId,
      requesterUid,
    );

    const firestore = getFirestore();

    const membersSnapshot =
      await firestore
        .collection("academies")
        .doc(academyId)
        .collection("members")
        .get();

    let updated = 0;
    let skipped = 0;

    for (
      const memberDocument
      of membersSnapshot.docs
    ) {
      const uid = memberDocument.id;

      const userSnapshot = await firestore
        .collection("users")
        .doc(uid)
        .get();

      if (!userSnapshot.exists) {
        skipped += 1;
        continue;
      }

      const userData =
        userSnapshot.data();

      if (userData === undefined) {
        skipped += 1;
        continue;
      }

      await memberDocument.ref.set(
        {
          userId: uid,
          displayName:
            userData.displayName ??
            "Usuário sem nome",
          email:
            userData.email ?? "",
          phone:
            userData.phone ?? null,
          photoUrl:
            userData.photoUrl ?? null,
          isActive:
            userData.isActive === true,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      updated += 1;
    }

    logger.info(
      "Perfis dos membros sincronizados.",
      {
        academyId,
        requesterUid,
        updated,
        skipped,
      },
    );

    return {
      success: true,
      updated,
      skipped,
    };
  },
);
