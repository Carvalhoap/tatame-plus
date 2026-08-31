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

interface UpdateAcademyUserData {
  academyId?: unknown;
  userId?: unknown;
  displayName?: unknown;
  roles?: unknown;
  isActive?: unknown;
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
    if (
      typeof role !== "string" ||
      !allowedRoles.includes(role as AllowedRole)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Um dos perfis informados é inválido.",
      );
    }

    return role;
  });

  const uniqueRoles = new Set(requestedRoles);

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
  const snapshot = await getFirestore()
    .collection("academies")
    .doc(academyId)
    .collection("members")
    .doc(requesterUid)
    .get();

  const data = snapshot.data();

  if (
    !snapshot.exists ||
    data?.status !== "active" ||
    data?.roles?.admin !== true
  ) {
    throw new HttpsError(
      "permission-denied",
      "Somente administradores ativos podem executar esta operação.",
    );
  }
}

export const updateAcademyUser = onCall(
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

    const data = request.data as UpdateAcademyUserData;

    const academyId = requiredString(
      data.academyId,
      "academyId",
    );

    const userId = requiredString(
      data.userId,
      "userId",
    );

    const displayName = requiredString(
      data.displayName,
      "displayName",
    );

    const roles = validateRoles(data.roles);

    if (typeof data.isActive !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "A situação do usuário é inválida.",
      );
    }

    const isActive = data.isActive;
    const status = isActive ? "active" : "inactive";
    const requesterUid = request.auth.uid;

    await assertAdministrator(
      academyId,
      requesterUid,
    );

    if (
      requesterUid === userId &&
      (!isActive || roles.admin !== true)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Você não pode remover o próprio acesso administrativo.",
      );
    }

    const auth = getAuth();
    const firestore = getFirestore();

    const memberReference = firestore
      .collection("academies")
      .doc(academyId)
      .collection("members")
      .doc(userId);

    const memberSnapshot = await memberReference.get();

    if (!memberSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Usuário não encontrado nesta academia.",
      );
    }

    const before = memberSnapshot.data() ?? {};

    try {
      await auth.updateUser(
        userId,
        {
          displayName,
          disabled: !isActive,
        },
      );

      const userReference = firestore
        .collection("users")
        .doc(userId);

      const auditReference = firestore
        .collection("academies")
        .doc(academyId)
        .collection("auditLogs")
        .doc();

      const batch = firestore.batch();

      batch.set(
        userReference,
        {
          displayName,
          isActive,
          registrationStatus: "approved",
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      batch.set(
        memberReference,
        {
          displayName,
          roles,
          status,
          isActive,
          updatedAt: FieldValue.serverTimestamp(),
          authorizedBy: requesterUid,
          rolesUpdatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      batch.create(
        auditReference,
        {
          action: "academyUserUpdated",
          entityType: "user",
          entityId: userId,
          performedBy: requesterUid,
          createdAt: FieldValue.serverTimestamp(),
          before: {
            displayName: before.displayName ?? null,
            roles: before.roles ?? null,
            status: before.status ?? null,
            isActive: before.isActive ?? null,
          },
          after: {
            displayName,
            roles,
            status,
            isActive,
          },
          metadata: {
            academyId,
          },
        },
      );

      await batch.commit();

      logger.info(
        "Usuário da academia atualizado.",
        {
          academyId,
          userId,
          requesterUid,
        },
      );

      return {
        success: true,
        userId,
      };
    } catch (error) {
      logger.error(
        "Falha ao atualizar usuário da academia.",
        {
          academyId,
          userId,
          requesterUid,
          error,
        },
      );

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        "Não foi possível atualizar o usuário.",
      );
    }
  },
);
