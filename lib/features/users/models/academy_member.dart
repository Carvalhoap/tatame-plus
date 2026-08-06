class AcademyMember {
  final String userId;
  final String displayName;
  final String email;
  final String status;
  final Map<String, bool> roles;
  final bool isActive;

  const AcademyMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.status,
    required this.roles,
    required this.isActive,
  });

  bool hasRole(String role) {
    return roles[role] == true;
  }

  List<String> get activeRoles {
    return roles.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}
