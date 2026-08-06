import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/academy_member.dart';
import '../../repository/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

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

  Map<String, bool> _parseRoles(dynamic rawRoles) {
    if (rawRoles is! Map) {
      return const {};
    }

    return rawRoles.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );
  }
}
