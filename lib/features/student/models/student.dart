class Student {
  final String id;
  final String academyId;

  final String name;
  final DateTime birthDate;
  final String phone;
  final String email;
  final String? photoUrl;

  final List<String> classroomIds;
  final List<String> teacherIds;

  final String planId;
  final String agreementId;

  final List<String> guardianIds;

  final bool active;

  const Student({
    required this.id,
    required this.academyId,
    required this.name,
    required this.birthDate,
    required this.phone,
    required this.email,
    this.photoUrl,
    required this.classroomIds,
    required this.teacherIds,
    required this.planId,
    required this.agreementId,
    this.guardianIds = const [],
    this.active = true,
  });
}