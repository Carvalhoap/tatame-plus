import '../../../core/enums/user_role.dart';

class TatameUser {
  final String id;
  final String academyId;
  final String name;
  final String email;
  final List<UserRole> roles;
  final bool isActive;

  const TatameUser({
    required this.id,
    required this.academyId,
    required this.name,
    required this.email,
    required this.roles,
    this.isActive = true,
  });

  bool hasRole(UserRole role) {
    return roles.contains(role);
  }
}