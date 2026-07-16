import '../models/tatame_user.dart';

abstract class AuthRepository {
  Future<TatameUser?> login({
    required String email,
    required String password,
  });

  Future<void> logout();
}