enum GraduationEvaluationStatus { monitoring, approved }

class StudentGraduationEvaluation {
  final String id;
  final String academyId;
  final String studentId;

  final String graduationProgramId;
  final String stageId;
  final String stageName;

  final GraduationEvaluationStatus status;

  final String? observation;

  final String evaluatedBy;
  final DateTime evaluatedAt;

  final int validAttendances;
  final int completedMonths;

  const StudentGraduationEvaluation({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.graduationProgramId,
    required this.stageId,
    required this.stageName,
    required this.status,
    required this.evaluatedBy,
    required this.evaluatedAt,
    required this.validAttendances,
    required this.completedMonths,
    this.observation,
  });
}
