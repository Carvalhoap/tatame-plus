import '../models/academy_member.dart';

abstract class UserRepository {
  Future<List<AcademyMember>> getAcademyMembers({required String academyId});
}
