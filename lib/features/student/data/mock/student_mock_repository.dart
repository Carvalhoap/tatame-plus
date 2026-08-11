import '../../models/student.dart';
import '../../repository/student_repository.dart';

class StudentMockRepository implements StudentRepository {
  final List<Student> _students = [
    Student(
      id: '1',
      academyId: 'academy_1',
      userId: 'mock-admin',
      fullName: 'Alexandre Carvalho',
      birthDate: DateTime(1990, 1, 1),
      phone: '21999999999',
      email: 'alexandre@email.com',
      graduationProgramId: 'adult_program_1',
      jiuJitsuStartDate: DateTime(2024, 1, 1),
      academyJoinDate: DateTime(2024, 1, 1),
      classroomIds: const ['class_1'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2026, 8, 11),
      createdBy: 'mock-admin',
    ),
  ];

  @override
  Future<List<Student>> getStudentsByAcademy(String academyId) async {
    return _students
        .where((student) => student.academyId == academyId)
        .toList(growable: false);
  }

  @override
  Future<Student?> getStudentById(String studentId) async {
    for (final student in _students) {
      if (student.id == studentId) {
        return student;
      }
    }

    return null;
  }
}
