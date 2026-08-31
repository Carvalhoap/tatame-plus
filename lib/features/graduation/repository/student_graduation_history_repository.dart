import '../models/student_graduation_history.dart';

abstract class StudentGraduationHistoryRepository {
  Future<List<StudentGraduationHistory>> getByStudent({
    required String academyId,
    required String studentId,
  });

  Future<String> addHistory({required StudentGraduationHistory history});
}
