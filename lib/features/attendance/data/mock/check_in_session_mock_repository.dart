import '../../models/attendance.dart';
import '../../models/check_in_session.dart';
import '../../repository/check_in_session_repository.dart';

class CheckInSessionMockRepository
    extends CheckInSessionRepository {
  final Map<String, CheckInSession> _sessions = {};
  final Map<String, List<Attendance>> _attendancesBySession = {};

  @override
  CheckInSession createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
    Duration validity = const Duration(minutes: 5),
  }) {
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
  CheckInSession? findSessionById(String sessionId) {
    return _sessions[sessionId];
  }

  @override
  bool closeSession(String sessionId) {
    final session = _sessions[sessionId];

    if (session == null || session.isClosed) {
      return false;
    }

    _sessions[sessionId] = session.copyWith(
      closedAt: DateTime.now(),
    );

    notifyListeners();

    return true;
  }

  @override
  List<Attendance> getAttendances(String sessionId) {
    return List.unmodifiable(
      _attendancesBySession[sessionId] ?? const [],
    );
  }

  @override
  bool isStudentCheckedIn({
    required String sessionId,
    required String studentId,
  }) {
    return getAttendances(sessionId).any(
      (attendance) =>
          attendance.studentId == studentId &&
          attendance.isValid,
    );
  }

  @override
  Attendance? registerAttendance({
    required String sessionId,
    required String studentId,
  }) {
    final session = findSessionById(sessionId);

    if (session == null || !session.isActive) {
      return null;
    }

    if (isStudentCheckedIn(
      sessionId: sessionId,
      studentId: studentId,
    )) {
      return null;
    }

    final now = DateTime.now();

    final attendance = Attendance(
      id: 'attendance_${now.microsecondsSinceEpoch}',
      academyId: session.academyId,
      studentId: studentId,
      classroomId: session.classroomId,
      teacherId: session.teacherId,
      checkInSessionId: session.id,
      dateTime: now,
      source: AttendanceSource.qrCode,
    );

    _attendancesBySession[sessionId]!.add(attendance);

    notifyListeners();

    return attendance;
  }
}