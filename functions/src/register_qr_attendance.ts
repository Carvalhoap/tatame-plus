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

interface RegisterQrAttendanceData {
  academyId?: unknown;
  sessionId?: unknown;
  studentId?: unknown;
  qrToken?: unknown;
}

function requiredIdentifier(
  value: unknown,
  fieldName: string,
): string {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9_-]{1,150}$/.test(value.trim())
  ) {
    throw new HttpsError(
      "invalid-argument",
      `O campo ${fieldName} é inválido.`,
    );
  }

  return value.trim();
}

function requiredQrToken(
  value: unknown,
): string {
  if (
    typeof value !== "string" ||
    !/^[A-Za-z0-9_-]{32,200}$/.test(value.trim())
  ) {
    throw new HttpsError(
      "failed-precondition",
      "O QR Code é inválido ou expirou.",
    );
  }

  return value.trim();
}

function invalidQrCode(): HttpsError {
  return new HttpsError(
    "failed-precondition",
    "O QR Code é inválido ou expirou.",
  );
}

export const registerQrAttendance = onCall(
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
      request.data as RegisterQrAttendanceData;

    const academyId = requiredIdentifier(
      data.academyId,
      "academyId",
    );

    const sessionId = requiredIdentifier(
      data.sessionId,
      "sessionId",
    );

    const studentId = requiredIdentifier(
      data.studentId,
      "studentId",
    );

    const qrToken = requiredQrToken(
      data.qrToken,
    );

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

    const sessionReference = academyReference
      .collection("checkInSessions")
      .doc(sessionId);

    const attendanceId =
      `${sessionId}_${studentId}`;

    const attendanceReference = academyReference
      .collection("attendances")
      .doc(attendanceId);

    const result = await firestore.runTransaction(
      async (transaction) => {
        const [
          memberSnapshot,
          studentSnapshot,
          sessionSnapshot,
          attendanceSnapshot,
        ] = await Promise.all([
          transaction.get(memberReference),
          transaction.get(studentReference),
          transaction.get(sessionReference),
          transaction.get(attendanceReference),
        ]);

        const memberData = memberSnapshot.data();
        const studentData = studentSnapshot.data();
        const sessionData = sessionSnapshot.data();

        if (
          !memberSnapshot.exists ||
          memberData?.status !== "active"
        ) {
          throw new HttpsError(
            "permission-denied",
            "Seu vínculo com a academia não está ativo.",
          );
        }

        if (
          !studentSnapshot.exists ||
          studentData?.status !== "active"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "O aluno não está ativo nesta academia.",
          );
        }

        const guardianIds =
          studentData.guardianIds;

        const ownsStudent =
          studentData.userId === requesterUid;

        const guardsStudent =
          Array.isArray(guardianIds) &&
          guardianIds.includes(requesterUid);

        if (!ownsStudent && !guardsStudent) {
          throw new HttpsError(
            "permission-denied",
            "Este aluno não está vinculado à sua conta.",
          );
        }

        if (
          !sessionSnapshot.exists ||
          sessionData === undefined ||
          sessionData.academyId !== academyId ||
          sessionData.qrToken !== qrToken ||
          sessionData.closedAt !== null ||
          !(sessionData.expiresAt instanceof Timestamp) ||
          sessionData.expiresAt.toMillis() <= Date.now()
        ) {
          throw invalidQrCode();
        }

        const classroomIds =
          studentData.classroomIds;

        if (
          typeof sessionData.classroomId !== "string" ||
          !Array.isArray(classroomIds) ||
          !classroomIds.includes(
            sessionData.classroomId,
          )
        ) {
          throw new HttpsError(
            "failed-precondition",
            "O aluno não pertence à turma desta chamada.",
          );
        }

        if (attendanceSnapshot.exists) {
          throw new HttpsError(
            "already-exists",
            "A presença já foi registrada nesta aula.",
          );
        }

        transaction.create(attendanceReference, {
          studentId,
          classroomId: sessionData.classroomId,
          teacherId: sessionData.teacherId,
          checkInSessionId: sessionId,
          dateTime: FieldValue.serverTimestamp(),
          source: "qrCode",
          isValid: true,
        });

        return {
          attendanceId,
          classroomId: sessionData.classroomId,
          teacherId: sessionData.teacherId,
        };
      },
    );

    if (request.app === undefined) {
      logger.warn(
        "Check-in realizado sem App Check.",
        {
          academyId,
          sessionId,
          studentId,
          requesterUid,
        },
      );
    }

    logger.info(
      "Presença por QR Code registrada.",
      {
        academyId,
        sessionId,
        studentId,
        requesterUid,
      },
    );

    return {
      success: true,
      attendanceId: result.attendanceId,
      classroomId: result.classroomId,
      teacherId: result.teacherId,
      checkInSessionId: sessionId,
    };
  },
);
