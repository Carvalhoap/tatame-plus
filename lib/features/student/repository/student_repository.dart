import '../models/student.dart';

abstract class StudentRepository {
  Future<List<Student>> getStudentsByAcademy(String academyId);

  Future<Student?> getStudentById(String studentId);
}
