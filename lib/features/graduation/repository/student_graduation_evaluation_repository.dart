import '../models/student_graduation_evaluation.dart';

abstract class StudentGraduationEvaluationRepository {
  Future<List<StudentGraduationEvaluation>> getByStudent({
    required String academyId,
    required String studentId,
  });

  Future<List<StudentGraduationEvaluation>> getByStudentAndStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String stageId,
  });

  Future<StudentGraduationEvaluation?> getLatestByStudentAndStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String stageId,
  });

  Future<String> addEvaluation({
    required StudentGraduationEvaluation evaluation,
  });
}
