class StudentGraduationProgress {
  final String id;
  final String academyId;
  final String studentId;
  final String graduationProgramId;

  final String currentStageId;

  final DateTime stageStartedAt;

  final int validAttendances;

  final DateTime? estimatedCompletionDate;

  final bool approvedByTeacher;

  const StudentGraduationProgress({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.graduationProgramId,
    required this.currentStageId,
    required this.stageStartedAt,
    this.validAttendances = 0,
    this.estimatedCompletionDate,
    this.approvedByTeacher = false,
  });
}