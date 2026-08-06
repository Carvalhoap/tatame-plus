import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/check_in_session.dart';

abstract class CheckInSessionRepository extends ChangeNotifier {
  CheckInSession createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
    Duration validity = const Duration(minutes: 5),
  });

  CheckInSession? findSessionById(String sessionId);

  bool closeSession(String sessionId);

  List<Attendance> getAttendances(String sessionId);

  Attendance? registerAttendance({
    required String sessionId,
    required String studentId,
  });

  bool isStudentCheckedIn({
    required String sessionId,
    required String studentId,
  });
}
