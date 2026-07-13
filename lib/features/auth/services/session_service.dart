import 'package:flutter/foundation.dart';

import '../../../core/enums/user_role.dart';
import '../models/tatame_user.dart';

class SessionService extends ChangeNotifier {
  TatameUser? _currentUser;
  UserRole? _activeRole;

  TatameUser? get currentUser => _currentUser;
  UserRole? get activeRole => _activeRole;

  bool get isAuthenticated => _currentUser != null;

  void startSession(TatameUser user) {
   _currentUser = user;

  // Usuários com apenas um perfil entram diretamente.
  // Usuários com vários perfis escolhem o contexto.
  _activeRole = user.roles.length == 1 ? user.roles.first : null;

   notifyListeners();
  }

  void changeActiveRole(UserRole role) {
    final user = _currentUser;

    if (user == null || !user.hasRole(role)) {
      return;
    }

    _activeRole = role;
    notifyListeners();
  }

  void clearActiveRole() {
    _activeRole = null;
    notifyListeners();
  }

  void endSession() {
    _currentUser = null;
    _activeRole = null;
    notifyListeners();
  }
}