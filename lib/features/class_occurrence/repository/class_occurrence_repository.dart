import '../models/class_occurrence.dart';

abstract class ClassOccurrenceRepository {
  Future<List<ClassOccurrence>> getOccurrencesByPeriod({
    required String academyId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<ClassOccurrence>> getOccurrencesByClassroom({
    required String academyId,
    required String classroomId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<ClassOccurrence?> getOccurrenceById({
    required String academyId,
    required String occurrenceId,
  });

  Future<String> createOccurrence({
    required String academyId,
    required String? classroomId,
    required String? scheduleId,
    required String name,
    required DateTime date,
    required String startTime,
    required String? endTime,
    required List<String> trainingTypeIds,
    required String? teacherId,
    required ClassOccurrenceStatus status,
    required String note,
    required String createdBy,
  });

  Future<void> updateOccurrence({
    required String academyId,
    required String occurrenceId,
    required String? classroomId,
    required String? scheduleId,
    required String name,
    required DateTime date,
    required String startTime,
    required String? endTime,
    required List<String> trainingTypeIds,
    required String? teacherId,
    required ClassOccurrenceStatus status,
    required String note,
    required String updatedBy,
  });

  Future<void> deleteOccurrence({
    required String academyId,
    required String occurrenceId,
  });
}
