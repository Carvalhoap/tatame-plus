import '../models/tatame_user.dart';

abstract class AuthRepository {
  /// Login
  Future<TatameUser?> login({required String email, required String password});

  /// Recupera uma sessão já autenticada
  Future<TatameUser?> restoreSession();

  /// Solicita o cadastro de um novo usuário
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? phone,
  });

  /// Envia um e-mail para redefinição da senha.
  Future<void> sendPasswordResetEmail({required String email});

  /// Troca a senha do usuário autenticado.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Logout
  Future<void> logout();
}

class RegistrationException implements Exception {
  final String message;

  const RegistrationException(this.message);

  @override
  String toString() => message;
}

class PasswordManagementException implements Exception {
  final String message;

  const PasswordManagementException(this.message);

  @override
  String toString() => message;
}
