import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/academy_member.dart';
import '../../repository/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  @override
  Future<List<AcademyMember>> getAcademyMembers({
    required String academyId,
  }) async {
    final membersSnapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('members')
        .get();

    final members = await Future.wait(
      membersSnapshot.docs.map((memberDocument) async {
        final memberData = memberDocument.data();

        final userId = memberData['userId'] as String? ?? memberDocument.id;

        final userSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .get();

        final userData = userSnapshot.data();

        return AcademyMember(
          userId: userId,
          displayName:
              userData?['displayName'] as String? ?? 'Usuário sem nome',
          email: userData?['email'] as String? ?? '',
          status: memberData['status'] as String? ?? 'inactive',
          roles: _parseRoles(memberData['roles']),
          isActive: userData?['isActive'] == true,
        );
      }),
    );

    members.sort(
      (first, second) => first.displayName.toLowerCase().compareTo(
        second.displayName.toLowerCase(),
      ),
    );

    return members;
  }

  @override
  Future<String> createAcademyUser({
    required String academyId,
    required String displayName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
    required bool isActive,
  }) async {
    final callable = functions.httpsCallable('createAcademyUser');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'academyId': academyId,
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': phone?.trim(),
        'roles': roles,
        'isActive': isActive,
      });

      final data = result.data;
      final userId = data['userId'];

      if (userId is! String || userId.isEmpty) {
        throw StateError(
          'O servidor criou o usuário, mas não retornou um UID válido.',
        );
      }

      return userId;
    } on FirebaseFunctionsException catch (error) {
      throw UserCreationException(
        code: error.code,
        message: _functionErrorMessage(error),
      );
    }
  }

  Map<String, bool> _parseRoles(dynamic rawRoles) {
    if (rawRoles is! Map) {
      return const {};
    }

    return rawRoles.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );
  }

  String _functionErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'Já existe um usuário cadastrado com este e-mail.';

      case 'invalid-argument':
        return error.message ?? 'Os dados informados são inválidos.';

      case 'permission-denied':
        return 'Você não possui permissão para cadastrar usuários.';

      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente no Tatame+.';

      case 'unavailable':
        return 'O serviço está temporariamente indisponível. Tente novamente.';

      case 'deadline-exceeded':
        return 'A operação demorou mais do que o esperado. Tente novamente.';

      default:
        return error.message ?? 'Não foi possível cadastrar o usuário.';
    }
  }
}

class UserCreationException implements Exception {
  final String code;
  final String message;

  const UserCreationException({required this.code, required this.message});

  @override
  String toString() => message;
}
