import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/class_occurrence.dart';
import '../../repository/class_occurrence_repository.dart';

class FirestoreClassOccurrenceRepository implements ClassOccurrenceRepository {
  final FirebaseFirestore firestore;

  FirestoreClassOccurrenceRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ClassOccurrence>> getOccurrencesByPeriod({
    required String academyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay(startDate)),
        )
        .where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)),
        )
        .get();

    final occurrences = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    _sortOccurrences(occurrences);

    return occurrences;
  }

  @override
  Future<List<ClassOccurrence>> getOccurrencesByClassroom({
    required String academyId,
    required String classroomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .where('classroomId', isEqualTo: classroomId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay(startDate)),
        )
        .where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)),
        )
        .get();

    final occurrences = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    _sortOccurrences(occurrences);

    return occurrences;
  }

  @override
  Future<ClassOccurrence?> getOccurrenceById({
    required String academyId,
    required String occurrenceId,
  }) async {
    final document = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .doc(occurrenceId)
        .get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return _fromData(academyId: academyId, documentId: document.id, data: data);
  }

  @override
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
  }) async {
    final reference = firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .doc();

    final now = FieldValue.serverTimestamp();

    await reference.set({
      'classroomId': _normalizeOptionalId(classroomId),
      'scheduleId': _normalizeOptionalId(scheduleId),
      'name': name.trim(),
      'date': Timestamp.fromDate(_startOfDay(date)),
      'startTime': startTime,
      'endTime': _normalizeOptionalId(endTime),
      'trainingTypeIds': trainingTypeIds,
      'teacherId': _normalizeOptionalId(teacherId),
      'status': _statusToString(status),
      'note': note.trim(),
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    return reference.id;
  }

  @override
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
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .doc(occurrenceId)
        .update({
          'classroomId': _normalizeOptionalId(classroomId),
          'scheduleId': _normalizeOptionalId(scheduleId),
          'name': name.trim(),
          'date': Timestamp.fromDate(_startOfDay(date)),
          'startTime': startTime,
          'endTime': _normalizeOptionalId(endTime),
          'trainingTypeIds': trainingTypeIds,
          'teacherId': _normalizeOptionalId(teacherId),
          'status': _statusToString(status),
          'note': note.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  @override
  Future<void> deleteOccurrence({
    required String academyId,
    required String occurrenceId,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('classOccurrences')
        .doc(occurrenceId)
        .delete();
  }

  ClassOccurrence _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    return _fromData(
      academyId: academyId,
      documentId: document.id,
      data: document.data(),
    );
  }

  ClassOccurrence _fromData({
    required String academyId,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return ClassOccurrence(
      id: documentId,
      academyId: academyId,
      classroomId: data['classroomId'] as String?,
      scheduleId: data['scheduleId'] as String?,
      name: data['name'] as String? ?? 'Treino sem nome',
      date: _parseDate(data['date']),
      startTime: data['startTime'] as String? ?? '00:00',
      endTime: data['endTime'] as String?,
      trainingTypeIds: _parseStringList(data['trainingTypeIds']),
      teacherId: data['teacherId'] as String?,
      status: _parseStatus(data['status']),
      note: data['note'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  ClassOccurrenceStatus _parseStatus(dynamic value) {
    switch (value) {
      case 'substituted':
        return ClassOccurrenceStatus.substituted;

      case 'cancelled':
        return ClassOccurrenceStatus.cancelled;

      case 'extra':
        return ClassOccurrenceStatus.extra;

      case 'scheduled':
      default:
        return ClassOccurrenceStatus.scheduled;
    }
  }

  String _statusToString(ClassOccurrenceStatus status) {
    switch (status) {
      case ClassOccurrenceStatus.scheduled:
        return 'scheduled';

      case ClassOccurrenceStatus.substituted:
        return 'substituted';

      case ClassOccurrenceStatus.cancelled:
        return 'cancelled';

      case ClassOccurrenceStatus.extra:
        return 'extra';
    }
  }

  void _sortOccurrences(List<ClassOccurrence> occurrences) {
    occurrences.sort((a, b) {
      final dateComparison = a.date.compareTo(b.date);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return a.startTime.compareTo(b.startTime);
    });
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  String? _normalizeOptionalId(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
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
