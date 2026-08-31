import '../models/academy_member.dart';

abstract class UserRepository {
  Future<List<AcademyMember>> getAcademyMembers({required String academyId});

  Future<List<AcademyMember>> getActiveTeachers({required String academyId});

  Future<String> createAcademyUser({
    required String academyId,
    required String displayName,
    required String email,
    required String password,
    String? phone,
    required List<String> roles,
    required bool isActive,
  });

  Future<void> updateAcademyUser({
    required String academyId,
    required String userId,
    required String displayName,
    required List<String> roles,
    required bool isActive,
  });
}
