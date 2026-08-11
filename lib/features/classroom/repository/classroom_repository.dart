import '../models/classroom.dart';

abstract class ClassroomRepository {
  Future<List<Classroom>> getClassrooms({
    required String academyId,
    bool includeInactive = true,
  });

  Future<Classroom?> getClassroomById({
    required String academyId,
    required String classroomId,
  });

  Future<String> createClassroom({
    required String academyId,
    required String name,
    required String description,
    required String? defaultTeacherId,
    required List<ClassSchedule> schedules,
    required bool isActive,
    required String createdBy,
  });

  Future<void> updateClassroom({
    required String academyId,
    required String classroomId,
    required String name,
    required String description,
    required String? defaultTeacherId,
    required List<ClassSchedule> schedules,
    required bool isActive,
    required String updatedBy,
  });

  Future<void> setClassroomActive({
    required String academyId,
    required String classroomId,
    required bool isActive,
    required String updatedBy,
  });
}
