import '../models/attendance.dart';

abstract class AttendanceRepository {
  Future<List<Attendance>> getAttendanceBySession({
    required String academyId,
    required String checkInSessionId,
  });

  Future<List<Attendance>> getAttendancesByStudent({
    required String academyId,
    required String studentId,
    required DateTime start,
    required DateTime end,
  });

  Future<void> invalidateAttendance({
    required String academyId,
    required String attendanceId,
    required String invalidatedBy,
  });
}
