import '../models/graduation_program.dart';

abstract class GraduationProgramRepository {
  Future<List<GraduationProgram>> getActivePrograms({
    required String academyId,
  });
}
