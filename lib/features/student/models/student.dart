enum StudentStatus { active, inactive }

class Student {
  final String id;
  final String academyId;

  /// UID do Firebase Authentication.
  ///
  /// Pode ser nulo para alunos que nÃ£o possuem login prÃ³prio,
  /// como crianÃ§as vinculadas a um responsÃ¡vel.
  final String? userId;

  final String fullName;
  final DateTime? birthDate;

  final String? phone;
  final String? email;
  final String? photoUrl;

  /// Programa oficial de graduaÃ§Ã£o utilizado por este aluno.
  ///
  /// Exemplo: adult_program_1.
  final String? graduationProgramId;

  /// Data em que comeÃ§ou a praticar Jiu-Jitsu.
  final DateTime? jiuJitsuStartDate;

  /// Data de entrada nesta academia.
  final DateTime? academyJoinDate;

  final List<String> classroomIds;
  final List<String> guardianIds;

  final StudentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// UID do usuÃ¡rio que realizou o cadastro.
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
