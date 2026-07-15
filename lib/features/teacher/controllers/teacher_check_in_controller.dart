import 'package:flutter/foundation.dart';

import '../../attendance/models/attendance.dart';
import '../../attendance/models/check_in_session.dart';
import '../../attendance/repository/check_in_session_repository.dart';

class TeacherCheckInController extends ChangeNotifier {
  final CheckInSessionRepository repository;

  TeacherCheckInController({
    required this.repository,
  });

  CheckInSession? _currentSession;

  CheckInSession? get currentSession => _currentSession;

  bool get hasActiveSession =>
      _currentSession != null && _currentSession!.isActive;

  List<Attendance> get attendances {
    final session = _currentSession;

    if (session == null) {
      return const [];
    }

    return repository.getAttendances(session.id);
  }

  CheckInSession createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
  }) {
    _currentSession = repository.createSession(
      academyId: academyId,
      classroomId: classroomId,
      teacherId: teacherId,
    );

    notifyListeners();

    return _currentSession!;
  }

  bool closeCurrentSession() {
    final session = _currentSession;

    if (session == null) {
      return false;
    }

    final closed = repository.closeSession(session.id);

    if (!closed) {
      return false;
    }

    _currentSession = repository.findSessionById(session.id);
    notifyListeners();

    return true;
  }

  void clearSession() {
    _currentSession = null;
    notifyListeners();
  }
}