enum AttendanceSource {
  qrCode,
  manual,
  import,
}

class Attendance {
  final String id;
  final String academyId;

  final String studentId;
  final String classroomId;
  final String teacherId;

  final String? checkInSessionId;

  final DateTime dateTime;

  final AttendanceSource source;

  final bool isValid;

  const Attendance({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.classroomId,
    required this.teacherId,
    this.checkInSessionId,
    required this.dateTime,
    required this.source,
    this.isValid = true,
  });
}