import '../models/tatame_user.dart';

abstract class AuthRepository {
  /// Login
  Future<TatameUser?> login({required String email, required String password});

  /// Recupera uma sessão já autenticada
  Future<TatameUser?> restoreSession();

  /// Logout
  Future<void> logout();
}
