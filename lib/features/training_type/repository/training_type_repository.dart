import '../models/training_type.dart';

abstract class TrainingTypeRepository {
  Future<List<TrainingType>> getTrainingTypes({
    required String academyId,
    bool includeInactive = true,
  });

  Future<TrainingType?> getTrainingTypeById({
    required String academyId,
    required String trainingTypeId,
  });

  Future<String> createTrainingType({
    required String academyId,
    required String name,
    required String description,
    required bool isActive,
    required String createdBy,
  });

  Future<void> updateTrainingType({
    required String academyId,
    required String trainingTypeId,
    required String name,
    required String description,
    required bool isActive,
    required String updatedBy,
  });

  Future<void> setTrainingTypeActive({
    required String academyId,
    required String trainingTypeId,
    required bool isActive,
    required String updatedBy,
  });
}
