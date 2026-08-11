import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/classroom.dart';
import '../../repository/classroom_repository.dart';

class FirestoreClassroomRepository implements ClassroomRepository {
  final FirebaseFirestore firestore;

  FirestoreClassroomRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Classroom>> getActiveClassrooms({
    required String academyId,
  }) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .where('isActive', isEqualTo: true)
        .get();

    final classrooms = snapshot.docs.map((document) {
      final data = document.data();

      return Classroom(
        id: document.id,
        academyId: academyId,
        name: data['name'] as String? ?? 'Turma sem nome',
        description: data['description'] as String? ?? '',
        teacherIds: _parseStringList(data['teacherIds']),
        isActive: data['isActive'] == true,
      );
    }).toList();

    classrooms.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return classrooms;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList(growable: false);
  }
}
