class Teacher {
  final String id;
  final String academyId;
  final String name;
  final String email;
  final String phone;
  final bool isActive;

  const Teacher({
    required this.id,
    required this.academyId,
    required this.name,
    required this.email,
    required this.phone,
    this.isActive = true,
  });
}