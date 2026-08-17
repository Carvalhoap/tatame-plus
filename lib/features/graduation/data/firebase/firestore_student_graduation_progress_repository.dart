import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/stripe_progress.dart';
import '../../models/student_graduation_progress.dart';
import '../../repository/student_graduation_progress_repository.dart';

class FirestoreStudentGraduationProgressRepository
    implements StudentGraduationProgressRepository {
  final FirebaseFirestore firestore;

  FirestoreStudentGraduationProgressRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _document({
    required String academyId,
    required String studentId,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('studentGraduationProgress')
        .doc(studentId);
  }

  @override
  Future<StudentGraduationProgress?> getByStudent({
    required String academyId,
    required String studentId,
  }) async {
    final document = await _document(
      academyId: academyId,
      studentId: studentId,
    ).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return _fromData(academyId: academyId, studentId: studentId, data: data);
  }

  @override
  Future<void> saveProgress({required StudentGraduationProgress progress}) {
    return _document(
      academyId: progress.academyId,
      studentId: progress.studentId,
    ).set({
      'studentId': progress.studentId,
      'graduationProgramId': progress.graduationProgramId,
      'currentStageId': progress.currentStageId,
      'stageStartedAt': Timestamp.fromDate(progress.stageStartedAt),
      'validAttendances': progress.validAttendances,
      'stripes': progress.stripes
          .map(
            (stripe) => {
              'color': stripe.color.name,
              'earned': stripe.earned,
              'total': stripe.total,
            },
          )
          .toList(),
      'estimatedCompletionDate': progress.estimatedCompletionDate == null
          ? null
          : Timestamp.fromDate(progress.estimatedCompletionDate!),
      'approvedByTeacher': progress.approvedByTeacher,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStage({
    required String academyId,
    required String studentId,
    required String graduationProgramId,
    required String currentStageId,
    required DateTime stageStartedAt,
    required int validAttendances,
    required DateTime? estimatedCompletionDate,
    required bool approvedByTeacher,
  }) {
    return _document(academyId: academyId, studentId: studentId).set({
      'studentId': studentId,
      'graduationProgramId': graduationProgramId,
      'currentStageId': currentStageId,
      'stageStartedAt': Timestamp.fromDate(stageStartedAt),
      'validAttendances': validAttendances,
      'estimatedCompletionDate': estimatedCompletionDate == null
          ? null
          : Timestamp.fromDate(estimatedCompletionDate),
      'approvedByTeacher': approvedByTeacher,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  StudentGraduationProgress _fromData({
    required String academyId,
    required String studentId,
    required Map<String, dynamic> data,
  }) {
    return StudentGraduationProgress(
      id: studentId,
      academyId: academyId,
      studentId: studentId,
      graduationProgramId: data['graduationProgramId'] as String? ?? '',
      currentStageId: data['currentStageId'] as String? ?? '',
      stageStartedAt: _parseDate(data['stageStartedAt']),
      validAttendances: data['validAttendances'] as int? ?? 0,
      stripes: _parseStripes(data['stripes']),
      estimatedCompletionDate: _parseOptionalDate(
        data['estimatedCompletionDate'],
      ),
      approvedByTeacher: data['approvedByTeacher'] == true,
    );
  }

  List<StripeProgress> _parseStripes(dynamic rawStripes) {
    if (rawStripes is! List) {
      return const [];
    }

    final result = <StripeProgress>[];

    for (final item in rawStripes) {
      if (item is! Map) {
        continue;
      }

      final colorName = item['color'];
      final earned = item['earned'];
      final total = item['total'];

      if (colorName is! String || earned is! int || total is! int) {
        continue;
      }

      final color = StripeColor.values.firstWhere(
        (value) => value.name == colorName,
        orElse: () => StripeColor.white,
      );

      result.add(StripeProgress(color: color, earned: earned, total: total));
    }

    return result;
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

  DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
