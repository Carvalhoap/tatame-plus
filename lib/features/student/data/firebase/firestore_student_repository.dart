import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../repository/student_repository.dart';

class FirestoreStudentRepository implements StudentRepository {
  final FirebaseFirestore firestore;

  FirestoreStudentRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _students(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('students');
  }

  @override
  Future<List<Student>> getStudentsByAcademy(String academyId) async {
    final snapshot = await _students(academyId).get();

    final students = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    students.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );

    return students;
  }

  @override
  Future<Student?> getStudentById(String studentId) async {
    final academiesSnapshot = await firestore.collection('academies').get();

    for (final academy in academiesSnapshot.docs) {
      final document = await academy.reference
          .collection('students')
          .doc(studentId)
          .get();

      if (document.exists) {
        return _fromSnapshot(academyId: academy.id, document: document);
      }
    }

    return null;
  }

  @override
  Future<Student?> getStudentByUserId({
    required String academyId,
    required String userId,
  }) async {
    final snapshot = await _students(
      academyId,
    ).where('userId', isEqualTo: userId).limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final document = snapshot.docs.first;

    return _fromDocument(academyId: academyId, document: document);
  }

  @override
  Future<String> createStudent({
    required String academyId,
    required String? userId,
    required String fullName,
    required DateTime? birthDate,
    required String? phone,
    required String? email,
    required String? photoUrl,
    required String? graduationProgramId,
    required DateTime? jiuJitsuStartDate,
    required DateTime? academyJoinDate,
    required List<String> classroomIds,
    required List<String> guardianIds,
    required StudentStatus status,
    required String createdBy,
  }) async {
    final reference = _students(academyId).doc();
    final now = FieldValue.serverTimestamp();

    await reference.set({
      'userId': _normalizeOptionalString(userId),
      'fullName': fullName.trim(),
      'birthDate': _dateToTimestamp(birthDate),
      'phone': _normalizeOptionalString(phone),
      'email': _normalizeOptionalString(email),
      'photoUrl': _normalizeOptionalString(photoUrl),
      'graduationProgramId': _normalizeOptionalString(graduationProgramId),
      'jiuJitsuStartDate': _dateToTimestamp(jiuJitsuStartDate),
      'academyJoinDate': _dateToTimestamp(academyJoinDate),
      'classroomIds': classroomIds,
      'guardianIds': guardianIds,
      'status': status.name,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    return reference.id;
  }

  @override
  Future<void> updateStudent({
    required String academyId,
    required String studentId,
    required String? userId,
    required String fullName,
    required DateTime? birthDate,
    required String? phone,
    required String? email,
    required String? photoUrl,
    required String? graduationProgramId,
    required DateTime? jiuJitsuStartDate,
    required DateTime? academyJoinDate,
    required List<String> classroomIds,
    required List<String> guardianIds,
    required StudentStatus status,
    required String updatedBy,
  }) {
    return _students(academyId).doc(studentId).update({
      'userId': _normalizeOptionalString(userId),
      'fullName': fullName.trim(),
      'birthDate': _dateToTimestamp(birthDate),
      'phone': _normalizeOptionalString(phone),
      'email': _normalizeOptionalString(email),
      'photoUrl': _normalizeOptionalString(photoUrl),
      'graduationProgramId': _normalizeOptionalString(graduationProgramId),
      'jiuJitsuStartDate': _dateToTimestamp(jiuJitsuStartDate),
      'academyJoinDate': _dateToTimestamp(academyJoinDate),
      'classroomIds': classroomIds,
      'guardianIds': guardianIds,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  @override
  Future<void> setStudentStatus({
    required String academyId,
    required String studentId,
    required StudentStatus status,
    required String updatedBy,
  }) {
    return _students(academyId).doc(studentId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Student _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    return _fromData(
      academyId: academyId,
      documentId: document.id,
      data: document.data(),
    );
  }

  Student _fromSnapshot({
    required String academyId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    if (data == null) {
      throw StateError('O aluno não possui dados válidos.');
    }

    return _fromData(academyId: academyId, documentId: document.id, data: data);
  }

  Student _fromData({
    required String academyId,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return Student(
      id: documentId,
      academyId: academyId,
      userId: data['userId'] as String?,
      fullName: data['fullName'] as String? ?? 'Aluno sem nome',
      birthDate: _parseOptionalDate(data['birthDate']),
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      graduationProgramId: data['graduationProgramId'] as String?,
      jiuJitsuStartDate: _parseOptionalDate(data['jiuJitsuStartDate']),
      academyJoinDate: _parseOptionalDate(data['academyJoinDate']),
      classroomIds: _parseStringList(data['classroomIds']),
      guardianIds: _parseStringList(data['guardianIds']),
      status: _parseStatus(data['status']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
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

  StudentStatus _parseStatus(dynamic value) {
    if (value == StudentStatus.inactive.name) {
      return StudentStatus.inactive;
    }

    return StudentStatus.active;
  }

  String? _normalizeOptionalString(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Timestamp? _dateToTimestamp(DateTime? value) {
    if (value == null) {
      return null;
    }

    return Timestamp.fromDate(value);
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
