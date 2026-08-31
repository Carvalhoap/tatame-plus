class StudentGraduationHistory {
  final String id;
  final String academyId;
  final String studentId;
  final String graduationProgramId;

  final String stageId;
  final String stageName;

  final DateTime startedAt;
  final DateTime endedAt;

  final int validAttendances;

  final String? approvedBy;
  final String? observation;

  const StudentGraduationHistory({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.graduationProgramId,
    required this.stageId,
    required this.stageName,
    required this.startedAt,
    required this.endedAt,
    required this.validAttendances,
    this.approvedBy,
    this.observation,
  });
}
