import '../../models/attendance.dart';
import '../../repository/attendance_repository.dart';

class AttendanceMockRepository implements AttendanceRepository {
  @override
  Future<List<Attendance>> getAttendanceBySession({
    required String academyId,
    required String checkInSessionId,
  }) async {
    return [
      Attendance(
        id: '1',
        academyId: academyId,
        studentId: 'student_1',
        classroomId: 'class_1',
        teacherId: 'teacher_1',
        checkInSessionId: checkInSessionId,
        dateTime: DateTime.now(),
        source: AttendanceSource.qrCode,
      ),
    ];
  }

  @override
  Future<List<Attendance>> getAttendancesByStudent({
    required String academyId,
    required String studentId,
    required DateTime start,
    required DateTime end,
  }) async {
    return const [];
  }

  @override
  Future<List<Attendance>> getAttendancesByPeriod({
    required String academyId,
    required DateTime start,
    required DateTime end,
    bool includeInvalid = false,
  }) async {
    return const [];
  }

  @override
  Future<void> invalidateAttendance({
    required String academyId,
    required String attendanceId,
    required String invalidatedBy,
  }) async {
    // Mock sem persistência real.
  }
}
