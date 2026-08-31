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
    var snapshot = await _getMembersSnapshot(academyId: academyId);

    if (_containsLegacyMember(snapshot)) {
      await _syncMemberProfiles(academyId: academyId);

      snapshot = await _getMembersSnapshot(academyId: academyId);
    }

    final members = snapshot.docs.map(_memberFromDocument).toList();

    members.sort(
      (first, second) => first.displayName.toLowerCase().compareTo(
        second.displayName.toLowerCase(),
      ),
    );

    return members;
  }

  @override
  Future<List<AcademyMember>> getActiveTeachers({
    required String academyId,
  }) async {
    final members = await getAcademyMembers(academyId: academyId);

    return members
        .where(
          (member) =>
              member.status == 'active' &&
              member.isActive &&
              member.hasRole('teacher'),
        )
        .toList(growable: false);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getMembersSnapshot({
    required String academyId,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('members')
        .get();
  }

  AcademyMember _memberFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return AcademyMember(
      userId: data['userId'] as String? ?? document.id,
      displayName: data['displayName'] as String? ?? 'Usuário sem nome',
      email: data['email'] as String? ?? '',
      status: data['status'] as String? ?? 'inactive',
      roles: _parseRoles(data['roles']),
      isActive: data['isActive'] == true,
    );
  }

  bool _containsLegacyMember(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final document in snapshot.docs) {
      final data = document.data();

      final hasDisplayName =
          data['displayName'] is String &&
          (data['displayName'] as String).trim().isNotEmpty;

      final hasEmail = data['email'] is String;

      final hasIsActive = data['isActive'] is bool;

      if (!hasDisplayName || !hasEmail || !hasIsActive) {
        return true;
      }
    }

    return false;
  }

  Future<void> _syncMemberProfiles({required String academyId}) async {
    final callable = functions.httpsCallable('syncAcademyMemberProfiles');

    try {
      await callable.call<Map<String, dynamic>>({'academyId': academyId});
    } on FirebaseFunctionsException catch (error) {
      throw MemberSynchronizationException(
        code: error.code,
        message: _functionErrorMessage(error),
      );
    }
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

  @override
  Future<void> updateAcademyUser({
    required String academyId,
    required String userId,
    required String displayName,
    required List<String> roles,
    required bool isActive,
  }) async {
    final callable = functions.httpsCallable('updateAcademyUser');

    try {
      await callable.call<Map<String, dynamic>>({
        'academyId': academyId,
        'userId': userId,
        'displayName': displayName.trim(),
        'roles': roles,
        'isActive': isActive,
      });
    } on FirebaseFunctionsException catch (error) {
      throw UserUpdateException(
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
        return 'Você não possui permissão para executar esta operação.';

      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente no Tatame+.';

      case 'unavailable':
        return 'O serviço está temporariamente indisponível. Tente novamente.';

      case 'deadline-exceeded':
        return 'A operação demorou mais do que o esperado. Tente novamente.';

      default:
        return error.message ?? 'Não foi possível concluir a operação.';
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

class UserUpdateException implements Exception {
  final String code;
  final String message;

  const UserUpdateException({required this.code, required this.message});

  @override
  String toString() => message;
}

class MemberSynchronizationException implements Exception {
  final String code;
  final String message;

  const MemberSynchronizationException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => message;
}
