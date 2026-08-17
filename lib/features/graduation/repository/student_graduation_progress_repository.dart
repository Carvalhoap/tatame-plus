import '../models/student_graduation_progress.dart';

abstract class StudentGraduationProgressRepository {
  Future<StudentGraduationProgress?> getByStudent({
    required String academyId,
    required String studentId,
  });

  Future<void> saveProgress({required StudentGraduationProgress progress});

  Future<void> updateStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String currentStageId,
    required DateTime stageStartedAt,
    required int validAttendances,
    required DateTime? estimatedCompletionDate,
    required bool approvedByTeacher,
  });
}
