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

  @override
  Future<String> createStudent({
    required String academyId,
    required String? userId,
    required String fullName,
    required DateTime? birthDate,
    required String? phone,
    required String? email,
    required String? photoUrl,
    required String? graduationProgramId,
    required DateTime? jiuJitsuStartDate,
    required DateTime? academyJoinDate,
    required List<String> classroomIds,
    required List<String> guardianIds,
    required StudentStatus status,
    required String createdBy,
  }) async {
    final id = 'student_${DateTime.now().microsecondsSinceEpoch}';

    final now = DateTime.now();

    _students.add(
      Student(
        id: id,
        academyId: academyId,
        userId: userId,
        fullName: fullName,
        birthDate: birthDate,
        phone: phone,
        email: email,
        photoUrl: photoUrl,
        graduationProgramId: graduationProgramId,
        jiuJitsuStartDate: jiuJitsuStartDate,
        academyJoinDate: academyJoinDate,
        classroomIds: List.unmodifiable(classroomIds),
        guardianIds: List.unmodifiable(guardianIds),
        status: status,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
      ),
    );

    return id;
  }

  @override
  Future<void> updateStudent({
    required String academyId,
    required String studentId,
    required String? userId,
    required String fullName,
    required DateTime? birthDate,
    required String? phone,
    required String? email,
    required String? photoUrl,
    required String? graduationProgramId,
    required DateTime? jiuJitsuStartDate,
    required DateTime? academyJoinDate,
    required List<String> classroomIds,
    required List<String> guardianIds,
    required StudentStatus status,
    required String updatedBy,
  }) async {
    final index = _students.indexWhere(
      (student) => student.id == studentId && student.academyId == academyId,
    );

    if (index < 0) {
      throw StateError('Aluno não encontrado.');
    }

    final current = _students[index];

    _students[index] = Student(
      id: current.id,
      academyId: current.academyId,
      userId: userId,
      fullName: fullName,
      birthDate: birthDate,
      phone: phone,
      email: email,
      photoUrl: photoUrl,
      graduationProgramId: graduationProgramId,
      jiuJitsuStartDate: jiuJitsuStartDate,
      academyJoinDate: academyJoinDate,
      classroomIds: List.unmodifiable(classroomIds),
      guardianIds: List.unmodifiable(guardianIds),
      status: status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      createdBy: current.createdBy,
    );
  }

  @override
  Future<void> setStudentStatus({
    required String academyId,
    required String studentId,
    required StudentStatus status,
    required String updatedBy,
  }) async {
    final index = _students.indexWhere(
      (student) => student.id == studentId && student.academyId == academyId,
    );

    if (index < 0) {
      throw StateError('Aluno não encontrado.');
    }

    final current = _students[index];

    _students[index] = Student(
      id: current.id,
      academyId: current.academyId,
      userId: current.userId,
      fullName: current.fullName,
      birthDate: current.birthDate,
      phone: current.phone,
      email: current.email,
      photoUrl: current.photoUrl,
      graduationProgramId: current.graduationProgramId,
      jiuJitsuStartDate: current.jiuJitsuStartDate,
      academyJoinDate: current.academyJoinDate,
      classroomIds: current.classroomIds,
      guardianIds: current.guardianIds,
      status: status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      createdBy: current.createdBy,
    );
  }
}
