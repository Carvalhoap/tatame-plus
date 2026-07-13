import '../models/tatame_user.dart';

abstract class AuthRepository {
  TatameUser? login({
    required String email,
    required String password,
  });

  void logout();
}