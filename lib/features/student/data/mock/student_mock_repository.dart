import 'package:tatame_plus/features/student/models/student.dart';
import 'package:tatame_plus/features/student/repository/student_repository.dart';

class StudentMockRepository implements StudentRepository {
  final List<Student> _students = [
    Student(
      id: '1',
      academyId: 'academy_1',
      name: 'Alexandre Carvalho',
      birthDate: DateTime(1990, 1, 1),
      phone: '21999999999',
      email: 'alexandre@email.com',
      classroomIds: ['class_1'],
      teacherIds: ['teacher_1'],
      planId: 'plan_1',
      agreementId: 'agreement_1',
    ),
  ];

  @override
  List<Student> getStudentsByAcademy(String academyId) {
    return _students
        .where((student) => student.academyId == academyId)
        .toList();
  }

  @override
  Student? getStudentById(String studentId) {
    try {
      return _students.firstWhere((student) => student.id == studentId);
    } catch (_) {
      return null;
    }
  }
}