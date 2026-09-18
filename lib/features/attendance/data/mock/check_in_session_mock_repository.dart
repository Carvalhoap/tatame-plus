import 'dart:convert';

import '../../models/attendance.dart';
import '../../models/check_in_session.dart';
import '../../repository/check_in_session_repository.dart';

class CheckInSessionMockRepository extends CheckInSessionRepository {
  final Map<String, CheckInSession> _sessions = {};
  final Map<String, List<Attendance>> _attendancesBySession = {};

  @override
  Future<CheckInSession> createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
    Duration validity = const Duration(minutes: 5),
  }) async {
    final now = DateTime.now();
    final sessionId = 'session_${now.microsecondsSinceEpoch}';
    final qrToken = 'mock_qr_${now.microsecondsSinceEpoch}_secure';

    final session = CheckInSession(
      id: sessionId,
      academyId: academyId,
      classroomId: classroomId,
      teacherId: teacherId,
      qrToken: qrToken,
      createdAt: now,
      expiresAt: now.add(validity),
    );

    _sessions[sessionId] = session;
    _attendancesBySession[sessionId] = [];

    notifyListeners();

    return session;
  }

  @override
  Future<List<CheckInSession>> getSessionsByPeriod({
    required String academyId,
    required DateTime start,
    required DateTime end,
  }) async {
    final result = _sessions.values
        .where(
          (session) =>
              session.academyId == academyId &&
              !session.createdAt.isBefore(start) &&
              session.createdAt.isBefore(end),
        )
        .toList();

    result.sort((first, second) => second.createdAt.compareTo(first.createdAt));

    return List.unmodifiable(result);
  }

  @override
  Future<CheckInSession?> reopenSession({
    required String academyId,
    required String sessionId,
    Duration validity = const Duration(minutes: 5),
  }) async {
    final currentSession = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (currentSession == null) {
      return null;
    }

    final now = DateTime.now();
    final qrToken = 'mock_qr_${now.microsecondsSinceEpoch}_reopened';

    final reopenedSession = CheckInSession(
      id: currentSession.id,
      academyId: currentSession.academyId,
      classroomId: currentSession.classroomId,
      teacherId: currentSession.teacherId,
      qrToken: qrToken,
      createdAt: currentSession.createdAt,
      expiresAt: now.add(validity),
    );

    _sessions[sessionId] = reopenedSession;

    notifyListeners();

    return reopenedSession;
  }

  @override
  Future<CheckInSession?> findSessionById({
    required String academyId,
    required String sessionId,
  }) async {
    final session = _sessions[sessionId];

    if (session == null || session.academyId != academyId) {
      return null;
    }

    return session;
  }

  @override
  Future<bool> closeSession({
    required String academyId,
    required String sessionId,
  }) async {
    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null || session.isClosed) {
      return false;
    }

    _sessions[sessionId] = session.copyWith(closedAt: DateTime.now());

    notifyListeners();

    return true;
  }

  @override
  Future<List<Attendance>> getAttendances({
    required String academyId,
    required String sessionId,
  }) async {
    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null) {
      return const [];
    }

    return List.unmodifiable(_attendancesBySession[sessionId] ?? const []);
  }

  @override
  Future<bool> isStudentCheckedIn({
    required String academyId,
    required String sessionId,
    required String studentId,
  }) async {
    final attendances = await getAttendances(
      academyId: academyId,
      sessionId: sessionId,
    );

    return attendances.any(
      (attendance) => attendance.studentId == studentId && attendance.isValid,
    );
  }

  @override
  Future<Attendance?> registerQrAttendance({
    required String academyId,
    required String qrPayload,
    required String studentId,
  }) async {
    dynamic decoded;

    try {
      decoded = jsonDecode(qrPayload);
    } catch (_) {
      throw const FormatException('QR Code inválido.');
    }

    if (decoded is! Map) {
      throw const FormatException('QR Code inválido.');
    }

    final payload = Map<String, dynamic>.from(decoded);
    final sessionId = payload['sessionId'];
    final qrToken = payload['qrToken'];

    if (payload['version'] != 1 ||
        payload['academyId'] != academyId ||
        sessionId is! String ||
        qrToken is! String) {
      throw const FormatException('QR Code inválido.');
    }

    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null || !session.isActive || session.qrToken != qrToken) {
      throw StateError('O QR Code é inválido ou expirou.');
    }

    return registerAttendance(
      academyId: academyId,
      sessionId: sessionId,
      studentId: studentId,
    );
  }

  @override
  Future<Attendance?> registerAttendance({
    required String academyId,
    required String sessionId,
    required String studentId,
    AttendanceSource source = AttendanceSource.qrCode,
  }) async {
    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null || !session.isActive) {
      return null;
    }

    final alreadyCheckedIn = await isStudentCheckedIn(
      academyId: academyId,
      sessionId: sessionId,
      studentId: studentId,
    );

    if (alreadyCheckedIn) {
      return null;
    }

    final now = DateTime.now();

    final attendance = Attendance(
      id: 'attendance_${now.microsecondsSinceEpoch}',
      academyId: academyId,
      studentId: studentId,
      classroomId: session.classroomId,
      teacherId: session.teacherId,
      checkInSessionId: session.id,
      dateTime: now,
      source: source,
    );

    _attendancesBySession.putIfAbsent(sessionId, () => []).add(attendance);

    notifyListeners();

    return attendance;
  }
}
