import 'package:flutter/foundation.dart';

import '../../attendance/models/attendance.dart';
import '../../attendance/models/check_in_session.dart';
import '../../attendance/repository/check_in_session_repository.dart';

class TeacherCheckInController extends ChangeNotifier {
  final CheckInSessionRepository repository;

  TeacherCheckInController({required this.repository}) {
    repository.addListener(_onRepositoryChanged);
  }

  CheckInSession? _currentSession;
  List<Attendance> _attendances = const [];

  // Guarda todos os QRs que fazem parte da chamada atual.
  final List<String> _sessionIds = [];

  bool _isLoading = false;

  CheckInSession? get currentSession => _currentSession;

  List<Attendance> get attendances => _attendances;

  bool get isLoading => _isLoading;

  bool get hasActiveSession =>
      _currentSession != null && _currentSession!.isActive;

  Future<CheckInSession> createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final nextDay = dayStart.add(const Duration(days: 1));

      CheckInSession? sessionToReopen;

      final previousSession = _currentSession;

      if (previousSession != null &&
          previousSession.classroomId == classroomId &&
          !previousSession.createdAt.isBefore(dayStart) &&
          previousSession.createdAt.isBefore(nextDay)) {
        sessionToReopen = previousSession;
      } else {
        final todaySessions = await repository.getSessionsByPeriod(
          academyId: academyId,
          start: dayStart,
          end: nextDay,
        );

        for (final session in todaySessions) {
          if (session.classroomId == classroomId) {
            sessionToReopen = session;
            break;
          }
        }
      }

      final reopenedSession = sessionToReopen == null
          ? null
          : await repository.reopenSession(
              academyId: academyId,
              sessionId: sessionToReopen.id,
            );

      final session =
          reopenedSession ??
          await repository.createSession(
            academyId: academyId,
            classroomId: classroomId,
            teacherId: teacherId,
          );

      _sessionIds
        ..clear()
        ..add(session.id);

      _currentSession = session;

      await _loadAttendancesForCurrentCall();

      notifyListeners();

      return session;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> closeCurrentSession() async {
    final session = _currentSession;

    if (session == null) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final closed = await repository.closeSession(
        academyId: session.academyId,
        sessionId: session.id,
      );

      if (!closed) {
        return false;
      }

      _currentSession = await repository.findSessionById(
        academyId: session.academyId,
        sessionId: session.id,
      );

      await _loadAttendancesForCurrentCall();

      notifyListeners();

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentSession() async {
    final session = _currentSession;

    if (session == null) {
      _attendances = const [];
      notifyListeners();
      return;
    }

    _currentSession = await repository.findSessionById(
      academyId: session.academyId,
      sessionId: session.id,
    );

    await _loadAttendancesForCurrentCall();

    notifyListeners();
  }

  Future<void> _loadAttendancesForCurrentCall() async {
    final session = _currentSession;

    if (session == null) {
      _attendances = const [];
      return;
    }

    if (!_sessionIds.contains(session.id)) {
      _sessionIds.add(session.id);
    }

    final attendanceLists = await Future.wait(
      _sessionIds.map(
        (sessionId) => repository.getAttendances(
          academyId: session.academyId,
          sessionId: sessionId,
        ),
      ),
    );

    // Evita duplicidade caso o repositório devolva o mesmo registro novamente.
    final attendancesById = <String, Attendance>{};

    for (final attendanceList in attendanceLists) {
      for (final attendance in attendanceList) {
        attendancesById[attendance.id] = attendance;
      }
    }

    _attendances = attendancesById.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void clearSession() {
    _currentSession = null;
    _attendances = const [];
    _sessionIds.clear();

    notifyListeners();
  }

  void _onRepositoryChanged() {
    if (_isLoading) {
      return;
    }

    refreshCurrentSession();
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryChanged);

    super.dispose();
  }
}
