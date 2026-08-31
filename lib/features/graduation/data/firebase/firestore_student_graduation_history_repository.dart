import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student_graduation_history.dart';
import '../../repository/student_graduation_history_repository.dart';

class FirestoreStudentGraduationHistoryRepository
    implements StudentGraduationHistoryRepository {
  final FirebaseFirestore firestore;

  FirestoreStudentGraduationHistoryRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _history(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('studentGraduationHistory');
  }

  @override
  Future<List<StudentGraduationHistory>> getByStudent({
    required String academyId,
    required String studentId,
  }) async {
    final snapshot = await _history(
      academyId,
    ).where('studentId', isEqualTo: studentId).get();

    final result = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    result.sort((a, b) => b.endedAt.compareTo(a.endedAt));

    return result;
  }

  @override
  Future<String> addHistory({required StudentGraduationHistory history}) async {
    final reference = _history(history.academyId).doc();

    await reference.set({
      'studentId': history.studentId,
      'graduationProgramId': history.graduationProgramId,
      'stageId': history.stageId,
      'stageName': history.stageName,
      'startedAt': Timestamp.fromDate(history.startedAt),
      'endedAt': Timestamp.fromDate(history.endedAt),
      'validAttendances': history.validAttendances,
      'approvedBy': history.approvedBy,
      'observation': history.observation,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return reference.id;
  }

  StudentGraduationHistory _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    return StudentGraduationHistory(
      id: document.id,
      academyId: academyId,
      studentId: data['studentId'] as String? ?? '',
      graduationProgramId: data['graduationProgramId'] as String? ?? '',
      stageId: data['stageId'] as String? ?? '',
      stageName: data['stageName'] as String? ?? '',
      startedAt: _parseDate(data['startedAt']),
      endedAt: _parseDate(data['endedAt']),
      validAttendances: data['validAttendances'] as int? ?? 0,
      approvedBy: data['approvedBy'] as String?,
      observation: data['observation'] as String?,
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
