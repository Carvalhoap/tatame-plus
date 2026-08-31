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

  /// Logout
  Future<void> logout();
}

class RegistrationException implements Exception {
  final String message;

  const RegistrationException(this.message);

  @override
  String toString() => message;
}
