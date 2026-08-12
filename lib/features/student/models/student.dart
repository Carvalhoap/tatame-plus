enum StudentStatus { active, inactive }

class Student {
  final String id;
  final String academyId;

  /// UID do Firebase Authentication.
  ///
  /// Pode ser nulo para alunos que não possuem login próprio,
  /// como crianças vinculadas a um responsável.
  final String? userId;

  final String fullName;
  final DateTime? birthDate;

  final String? phone;
  final String? email;
  final String? photoUrl;

  /// Programa oficial de graduação utilizado por este aluno.
  ///
  /// Exemplo: adult_program_1.
  final String? graduationProgramId;

  /// Data em que começou a praticar Jiu-Jitsu.
  final DateTime? jiuJitsuStartDate;

  /// Data de entrada nesta academia.
  final DateTime? academyJoinDate;

  final List<String> classroomIds;
  final List<String> guardianIds;

  final StudentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// UID do usuário que realizou o cadastro.
  final String createdBy;

  const Student({
    required this.id,
    required this.academyId,
    required this.fullName,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.userId,
    this.birthDate,
    this.phone,
    this.email,
    this.photoUrl,
    this.graduationProgramId,
    this.jiuJitsuStartDate,
    this.academyJoinDate,
    this.classroomIds = const [],
    this.guardianIds = const [],
    this.status = StudentStatus.active,
  });

  bool get isActive => status == StudentStatus.active;

  bool get hasLogin => userId != null && userId!.isNotEmpty;
}
