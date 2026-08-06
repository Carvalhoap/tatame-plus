import '../models/attendance.dart';

abstract class AttendanceRepository {
  List<Attendance> getAttendanceBySession(String checkInSessionId);
}
