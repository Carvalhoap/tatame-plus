class Teacher {
  final String id;
  final String academyId;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isActive;

  const Teacher({
    required this.id,
    required this.academyId,
    required this.userId,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.photoUrl,
    this.isActive = true,
  });
}
