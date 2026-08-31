import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/check_in_session.dart';

abstract class CheckInSessionRepository extends ChangeNotifier {
  Future<CheckInSession> createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
    Duration validity = const Duration(minutes: 5),
  });

  Future<CheckInSession?> findSessionById({
    required String academyId,
    required String sessionId,
  });

  Future<bool> closeSession({
    required String academyId,
    required String sessionId,
  });

  Future<List<Attendance>> getAttendances({
    required String academyId,
    required String sessionId,
  });

  Future<Attendance?> registerAttendance({
    required String academyId,
    required String sessionId,
    required String studentId,
    AttendanceSource source = AttendanceSource.qrCode,
  });

  Future<bool> isStudentCheckedIn({
    required String academyId,
    required String sessionId,
    required String studentId,
  });
}
