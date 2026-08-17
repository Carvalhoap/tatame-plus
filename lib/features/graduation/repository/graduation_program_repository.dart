import '../models/graduation_program.dart';
import '../models/graduation_stage.dart';

abstract class GraduationProgramRepository {
  Future<List<GraduationProgram>> getActivePrograms({
    required String academyId,
  });

  Future<List<GraduationProgram>> getPrograms({
    required String academyId,
    bool includeInactive = true,
  });

  Future<GraduationProgram?> getProgramById({
    required String academyId,
    required String programId,
  });

  Future<String> createProgram({
    required String academyId,
    required String name,
    required GraduationAudience audience,
    required List<GraduationStage> stages,
    required bool isActive,
    required String createdBy,
  });

  Future<void> updateProgram({
    required String academyId,
    required String programId,
    required String name,
    required GraduationAudience audience,
    required List<GraduationStage> stages,
    required bool isActive,
    required String updatedBy,
  });

  Future<void> setProgramActive({
    required String academyId,
    required String programId,
    required bool isActive,
    required String updatedBy,
  });
}
