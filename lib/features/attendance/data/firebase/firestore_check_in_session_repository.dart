import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/attendance.dart';
import '../../models/check_in_session.dart';
import '../../repository/check_in_session_repository.dart';

class FirestoreCheckInSessionRepository extends CheckInSessionRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  FirestoreCheckInSessionRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  CollectionReference<Map<String, dynamic>> _sessions(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('checkInSessions');
  }

  CollectionReference<Map<String, dynamic>> _attendances(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('attendances');
  }

  @override
  Future<CheckInSession> createSession({
    required String academyId,
    required String classroomId,
    required String teacherId,
    Duration validity = const Duration(minutes: 5),
  }) async {
    final now = DateTime.now();
    final qrToken = _generateQrToken();

    final reference = _sessions(academyId).doc();

    final session = CheckInSession(
      id: reference.id,
      academyId: academyId,
      classroomId: classroomId,
      teacherId: teacherId,
      qrToken: qrToken,
      createdAt: now,
      expiresAt: now.add(validity),
    );

    await reference.set({
      'academyId': academyId,
      'classroomId': classroomId,
      'teacherId': teacherId,
      'qrToken': qrToken,
      'createdAt': Timestamp.fromDate(session.createdAt),
      'expiresAt': Timestamp.fromDate(session.expiresAt),
      'closedAt': null,
    });

    notifyListeners();

    return session;
  }

  @override
  Future<List<CheckInSession>> getSessionsByPeriod({
    required String academyId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _sessions(academyId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();

    final result = snapshot.docs
        .map(
          (document) =>
              _sessionFromDocument(academyId: academyId, document: document),
        )
        .toList();

    result.sort((first, second) => second.createdAt.compareTo(first.createdAt));

    return result;
  }

  @override
  Future<CheckInSession?> reopenSession({
    required String academyId,
    required String sessionId,
    Duration validity = const Duration(minutes: 5),
  }) async {
    final currentSession = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (currentSession == null) {
      return null;
    }

    final now = DateTime.now();
    final newExpiresAt = now.add(validity);
    final qrToken = _generateQrToken();

    await _sessions(academyId).doc(sessionId).update({
      'expiresAt': Timestamp.fromDate(newExpiresAt),
      'closedAt': null,
      'reopenedAt': Timestamp.fromDate(now),
      'qrToken': qrToken,
    });

    final reopenedSession = CheckInSession(
      id: currentSession.id,
      academyId: currentSession.academyId,
      classroomId: currentSession.classroomId,
      teacherId: currentSession.teacherId,
      qrToken: qrToken,
      createdAt: currentSession.createdAt,
      expiresAt: newExpiresAt,
    );

    notifyListeners();

    return reopenedSession;
  }

  @override
  Future<CheckInSession?> findSessionById({
    required String academyId,
    required String sessionId,
  }) async {
    final document = await _sessions(academyId).doc(sessionId).get();

    if (!document.exists) {
      return null;
    }

    return _sessionFromDocument(academyId: academyId, document: document);
  }

  @override
  Future<bool> closeSession({
    required String academyId,
    required String sessionId,
  }) async {
    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null || session.isClosed) {
      return false;
    }

    await _sessions(
      academyId,
    ).doc(sessionId).update({'closedAt': Timestamp.fromDate(DateTime.now())});

    notifyListeners();

    return true;
  }

  @override
  Future<List<Attendance>> getAttendances({
    required String academyId,
    required String sessionId,
  }) async {
    final snapshot = await _attendances(
      academyId,
    ).where('checkInSessionId', isEqualTo: sessionId).get();

    final result = snapshot.docs
        .map(
          (document) =>
              _attendanceFromDocument(academyId: academyId, document: document),
        )
        .where((attendance) => attendance.isValid)
        .toList();

    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return result;
  }

  @override
  Future<bool> isStudentCheckedIn({
    required String academyId,
    required String sessionId,
    required String studentId,
  }) async {
    final snapshot = await _attendances(academyId)
        .where('checkInSessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .where('isValid', isEqualTo: true)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<Attendance?> registerQrAttendance({
    required String academyId,
    required String qrPayload,
    required String studentId,
  }) async {
    Map<String, dynamic> payload;

    try {
      final decoded = jsonDecode(qrPayload);

      if (decoded is! Map) {
        throw const FormatException();
      }

      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const FormatException('QR Code inválido.');
    }

    final version = payload['version'];
    final payloadAcademyId = payload['academyId'];
    final sessionId = payload['sessionId'];
    final qrToken = payload['qrToken'];

    if (version != 1 ||
        payloadAcademyId is! String ||
        payloadAcademyId != academyId ||
        sessionId is! String ||
        sessionId.isEmpty ||
        qrToken is! String ||
        qrToken.isEmpty) {
      throw const FormatException('QR Code inválido.');
    }

    final callable = functions.httpsCallable('registerQrAttendance');

    try {
      final result = await callable.call<Map<String, dynamic>>({
        'academyId': academyId,
        'sessionId': sessionId,
        'studentId': studentId,
        'qrToken': qrToken,
      });

      final data = result.data;
      final attendanceId = data['attendanceId'];
      final classroomId = data['classroomId'];
      final teacherId = data['teacherId'];
      final returnedSessionId = data['checkInSessionId'];

      if (attendanceId is! String ||
          classroomId is! String ||
          teacherId is! String ||
          returnedSessionId is! String) {
        throw StateError('O servidor não retornou uma presença válida.');
      }

      return Attendance(
        id: attendanceId,
        academyId: academyId,
        studentId: studentId,
        classroomId: classroomId,
        teacherId: teacherId,
        checkInSessionId: returnedSessionId,
        dateTime: DateTime.now(),
        source: AttendanceSource.qrCode,
        isValid: true,
      );
    } on FirebaseFunctionsException catch (error) {
      final message =
          error.message ?? 'Não foi possível registrar sua presença.';

      switch (error.code) {
        case 'invalid-argument':
          throw FormatException(message);

        case 'already-exists':
        case 'failed-precondition':
        case 'permission-denied':
        case 'unauthenticated':
          throw StateError(message);

        default:
          throw StateError(
            'O serviço de check-in está indisponível. Tente novamente.',
          );
      }
    }
  }

  @override
  Future<Attendance?> registerAttendance({
    required String academyId,
    required String sessionId,
    required String studentId,
    AttendanceSource source = AttendanceSource.qrCode,
  }) async {
    final session = await findSessionById(
      academyId: academyId,
      sessionId: sessionId,
    );

    if (session == null || !session.isActive) {
      return null;
    }

    final now = DateTime.now();

    // Um aluno possui apenas um documento de presença por sessão.
    final reference = _attendances(academyId).doc('${sessionId}_$studentId');

    final attendance = Attendance(
      id: reference.id,
      academyId: academyId,
      studentId: studentId,
      classroomId: session.classroomId,
      teacherId: session.teacherId,
      checkInSessionId: session.id,
      dateTime: now,
      source: source,
      isValid: true,
    );

    final registered = await firestore.runTransaction<bool>((
      transaction,
    ) async {
      final existingDocument = await transaction.get(reference);

      if (existingDocument.exists) {
        return false;
      }

      transaction.set(reference, {
        'studentId': attendance.studentId,
        'classroomId': attendance.classroomId,
        'teacherId': attendance.teacherId,
        'checkInSessionId': attendance.checkInSessionId,
        'dateTime': FieldValue.serverTimestamp(),
        'source': attendance.source.name,
        'isValid': attendance.isValid,
      });

      return true;
    });

    if (!registered) {
      return null;
    }

    notifyListeners();

    return attendance;
  }

  String _generateQrToken() {
    final random = Random.secure();

    final bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
      growable: false,
    );

    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  CheckInSession _sessionFromDocument({
    required String academyId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data()!;

    return CheckInSession(
      id: document.id,
      academyId: academyId,
      classroomId: data['classroomId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      qrToken: data['qrToken'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
      expiresAt: _parseDate(data['expiresAt']),
      closedAt: _parseOptionalDate(data['closedAt']),
    );
  }

  Attendance _attendanceFromDocument({
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

  DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return _parseDate(value);
  }
}
