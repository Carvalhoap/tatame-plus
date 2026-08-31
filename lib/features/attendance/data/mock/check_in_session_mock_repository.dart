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

    final session = CheckInSession(
      id: sessionId,
      academyId: academyId,
      classroomId: classroomId,
      teacherId: teacherId,
      createdAt: now,
      expiresAt: now.add(validity),
    );

    _sessions[sessionId] = session;
    _attendancesBySession[sessionId] = [];

    notifyListeners();

    return session;
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
