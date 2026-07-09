import '../models/student.dart';

abstract class StudentRepository {
  List<Student> getStudentsByAcademy(String academyId);

  Student? getStudentById(String studentId);
}