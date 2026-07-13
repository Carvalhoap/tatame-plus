import '../../../../core/enums/user_role.dart';
import '../../models/tatame_user.dart';
import '../../repository/auth_repository.dart';

class AuthMockRepository implements AuthRepository {
  final List<TatameUser> _users = const [
    TatameUser(
      id: 'user_1',
      academyId: 'academy_1',
      name: 'Alexandre Carvalho',
      email: 'alexandre@tatameplus.app',
      roles: [
        UserRole.admin,
        UserRole.teacher,
        UserRole.student,
      ],
    ),
    TatameUser(
      id: 'user_2',
      academyId: 'academy_1',
      name: 'Sócio Tatame+',
      email: 'socio@tatameplus.app',
      roles: [
        UserRole.partner,
        UserRole.teacher,
        UserRole.student,
      ],
    ),
    TatameUser(
      id: 'user_3',
      academyId: 'academy_1',
      name: 'Aluno Demonstração',
      email: 'aluno@tatameplus.app',
      roles: [
        UserRole.student,
      ],
    ),
  ];

  TatameUser? _currentUser;

  @override
  TatameUser? login({
    required String email,
    required String password,
  }) {
    if (password != '123456') {
      return null;
    }

    try {
      _currentUser = _users.firstWhere(
        (user) => user.email.toLowerCase() == email.toLowerCase(),
      );

      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void logout() {
    _currentUser = null;
  }
}