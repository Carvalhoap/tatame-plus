import '../models/student.dart';

abstract class StudentRepository {
  Future<List<Student>> getStudentsByAcademy(String academyId);

  Future<Student?> getStudentById(String studentId);

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
  });

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
  });

  Future<void> setStudentStatus({
    required String academyId,
    required String studentId,
    required StudentStatus status,
    required String updatedBy,
  });
}
