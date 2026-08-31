import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student_graduation_evaluation.dart';
import '../../repository/student_graduation_evaluation_repository.dart';

class FirestoreStudentGraduationEvaluationRepository
    implements StudentGraduationEvaluationRepository {
  final FirebaseFirestore firestore;

  FirestoreStudentGraduationEvaluationRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('studentGraduationEvaluations');
  }

  @override
  Future<List<StudentGraduationEvaluation>> getByStudent({
    required String academyId,
    required String studentId,
  }) async {
    final snapshot = await _collection(
      academyId,
    ).where('studentId', isEqualTo: studentId).get();

    final result = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    result.sort((a, b) => b.evaluatedAt.compareTo(a.evaluatedAt));

    return result;
  }

  @override
  Future<List<StudentGraduationEvaluation>> getByStudentAndStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String stageId,
  }) async {
    final evaluations = await getByStudent(
      academyId: academyId,
      studentId: studentId,
    );

    return evaluations
        .where(
          (evaluation) =>
              evaluation.graduationProgramId == graduationProgramId &&
              evaluation.stageId == stageId,
        )
        .toList();
  }

  @override
  Future<StudentGraduationEvaluation?> getLatestByStudentAndStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String stageId,
  }) async {
    final evaluations = await getByStudentAndStage(
      academyId: academyId,
      studentId: studentId,
      graduationProgramId: graduationProgramId,
      stageId: stageId,
    );

    if (evaluations.isEmpty) {
      return null;
    }

    return evaluations.first;
  }

  @override
  Future<String> addEvaluation({
    required StudentGraduationEvaluation evaluation,
  }) async {
    final document = _collection(evaluation.academyId).doc();

    await document.set({
      'studentId': evaluation.studentId,
      'graduationProgramId': evaluation.graduationProgramId,
      'stageId': evaluation.stageId,
      'stageName': evaluation.stageName,
      'status': evaluation.status.name,
      'observation': evaluation.observation,
      'evaluatedBy': evaluation.evaluatedBy,
      'evaluatedAt': Timestamp.fromDate(evaluation.evaluatedAt),
      'validAttendances': evaluation.validAttendances,
      'completedMonths': evaluation.completedMonths,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  StudentGraduationEvaluation _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    return StudentGraduationEvaluation(
      id: document.id,
      academyId: academyId,
      studentId: data['studentId'] as String? ?? '',
      graduationProgramId: data['graduationProgramId'] as String? ?? '',
      stageId: data['stageId'] as String? ?? '',
      stageName: data['stageName'] as String? ?? '',
      status: _parseStatus(data['status']),
      observation: data['observation'] as String?,
      evaluatedBy: data['evaluatedBy'] as String? ?? '',
      evaluatedAt: _dateFromValue(data['evaluatedAt']),
      validAttendances: data['validAttendances'] as int? ?? 0,
      completedMonths: data['completedMonths'] as int? ?? 0,
    );
  }

  GraduationEvaluationStatus _parseStatus(dynamic value) {
    switch (value) {
      case 'approved':
        return GraduationEvaluationStatus.approved;

      case 'monitoring':
      default:
        return GraduationEvaluationStatus.monitoring;
    }
  }

  DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
