import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance.dart';
import '../../repository/attendance_repository.dart';

class FirestoreAttendanceRepository implements AttendanceRepository {
  final FirebaseFirestore firestore;

  FirestoreAttendanceRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _attendances(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('attendances');
  }

  @override
  Future<List<Attendance>> getAttendanceBySession({
    required String academyId,
    required String checkInSessionId,
  }) async {
    final snapshot = await _attendances(
      academyId,
    ).where('checkInSessionId', isEqualTo: checkInSessionId).get();

    final result = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return result;
  }

  @override
  Future<List<Attendance>> getAttendancesByStudent({
    required String academyId,
    required String studentId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _attendances(academyId)
        .where('studentId', isEqualTo: studentId)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThan: Timestamp.fromDate(end))
        .get();

    final result = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .where((attendance) => attendance.isValid)
        .toList();

    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return result;
  }

  @override
  Future<void> invalidateAttendance({
    required String academyId,
    required String attendanceId,
    required String invalidatedBy,
  }) async {
    await _attendances(academyId).doc(attendanceId).update({
      'isValid': false,
      'invalidatedAt': FieldValue.serverTimestamp(),
      'invalidatedBy': invalidatedBy,
    });
  }

  Attendance _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    return Attendance(
      id: document.id,
      academyId: academyId,
      studentId: data['studentId'] as String? ?? '',
      classroomId: data['classroomId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      checkInSessionId: data['checkInSessionId'] as String?,
      dateTime: _parseDate(data['dateTime']),
      source: _parseAttendanceSource(data['source']),
      isValid: data['isValid'] != false,
    );
  }

  AttendanceSource _parseAttendanceSource(dynamic value) {
    switch (value) {
      case 'manual':
        return AttendanceSource.manual;
      case 'import':
        return AttendanceSource.import;
      default:
        return AttendanceSource.qrCode;
    }
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
