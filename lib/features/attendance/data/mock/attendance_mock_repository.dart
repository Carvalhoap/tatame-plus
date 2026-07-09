import '../../models/attendance.dart';
import '../../repository/attendance_repository.dart';

class AttendanceMockRepository implements AttendanceRepository {

  @override
  List<Attendance> getAttendanceBySession(String checkInSessionId) {

    return [
      Attendance(
        id: '1',
        academyId: 'academy_1',
        studentId: 'student_1',
        classroomId: 'class_1',
        teacherId: 'teacher_1',
        checkInSessionId: checkInSessionId,
        dateTime: DateTime.now(),
        source: AttendanceSource.qrCode,
      ),

      Attendance(
        id: '2',
        academyId: 'academy_1',
        studentId: 'student_2',
        classroomId: 'class_1',
        teacherId: 'teacher_1',
        checkInSessionId: checkInSessionId,
        dateTime: DateTime.now(),
        source: AttendanceSource.qrCode,
      ),

      Attendance(
        id: '3',
        academyId: 'academy_1',
        studentId: 'student_3',
        classroomId: 'class_1',
        teacherId: 'teacher_1',
        checkInSessionId: checkInSessionId,
        dateTime: DateTime.now(),
        source: AttendanceSource.manual,
      ),
    ];
  }
}