import '../models/classroom.dart';

abstract class ClassroomRepository {
  Future<List<Classroom>> getActiveClassrooms({required String academyId});
}
