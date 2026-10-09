import '../models/academy.dart';

abstract class AcademyRepository {
  Future<Academy?> getAcademyById({required String academyId});
}
