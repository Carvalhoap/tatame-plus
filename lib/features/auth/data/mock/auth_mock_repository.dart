import '../../../../core/enums/user_role.dart';
import '../../models/tatame_user.dart';
import '../../repository/auth_repository.dart';

class AuthMockRepository implements AuthRepository {
  TatameUser? _currentUser;

  @override
  Future<TatameUser?> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (email.isEmpty || password.isEmpty) {
      return null;
    }

    _currentUser = TatameUser(
      id: 'mock-admin',
      academyId: 'gracie-barra-neves',
      name: 'Administrador',
      email: email,
      isActive: true,
      roles: const [UserRole.admin, UserRole.teacher, UserRole.student],
    );

    return _currentUser;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (displayName.trim().isEmpty ||
        email.trim().isEmpty ||
        password.length < 8) {
      throw const RegistrationException('Os dados informados são inválidos.');
    }
  }

  @override
  Future<TatameUser?> restoreSession() async {
    return _currentUser;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (email.trim().isEmpty) {
      throw const PasswordManagementException(
        'Informe o e-mail usado no cadastro.',
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (currentPassword.isEmpty || newPassword.length < 8) {
      throw const PasswordManagementException(
        'Os dados informados são inválidos.',
      );
    }
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }
}
