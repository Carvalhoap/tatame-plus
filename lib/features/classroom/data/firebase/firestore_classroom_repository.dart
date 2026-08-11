import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/classroom.dart';
import '../../repository/classroom_repository.dart';

class FirestoreClassroomRepository implements ClassroomRepository {
  final FirebaseFirestore firestore;

  FirestoreClassroomRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Classroom>> getClassrooms({
    required String academyId,
    bool includeInactive = true,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms');

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    final snapshot = await query.get();

    final classrooms = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    classrooms.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return classrooms;
  }

  @override
  Future<Classroom?> getClassroomById({
    required String academyId,
    required String classroomId,
  }) async {
    final document = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .doc(classroomId)
        .get();

    if (!document.exists) {
      return null;
    }

    return _fromSnapshot(academyId: academyId, document: document);
  }

  @override
  Future<String> createClassroom({
    required String academyId,
    required String name,
    required String description,
    required String? defaultTeacherId,
    required List<ClassSchedule> schedules,
    required bool isActive,
    required String createdBy,
  }) async {
    final reference = firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .doc();

    final now = FieldValue.serverTimestamp();

    await reference.set({
      'name': name.trim(),
      'description': description.trim(),
      'defaultTeacherId': _normalizeOptionalId(defaultTeacherId),
      'schedules': schedules.map(_scheduleToMap).toList(),
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    return reference.id;
  }

  @override
  Future<void> updateClassroom({
    required String academyId,
    required String classroomId,
    required String name,
    required String description,
    required String? defaultTeacherId,
    required List<ClassSchedule> schedules,
    required bool isActive,
    required String updatedBy,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .doc(classroomId)
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'defaultTeacherId': _normalizeOptionalId(defaultTeacherId),
          'schedules': schedules.map(_scheduleToMap).toList(),
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  @override
  Future<void> setClassroomActive({
    required String academyId,
    required String classroomId,
    required bool isActive,
    required String updatedBy,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .doc(classroomId)
        .update({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  Classroom _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    return _fromData(
      academyId: academyId,
      documentId: document.id,
      data: document.data(),
    );
  }

  Classroom _fromSnapshot({
    required String academyId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    if (data == null) {
      throw StateError('A turma não possui dados válidos.');
    }

    return _fromData(academyId: academyId, documentId: document.id, data: data);
  }

  Classroom _fromData({
    required String academyId,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return Classroom(
      id: documentId,
      academyId: academyId,
      name: data['name'] as String? ?? 'Turma sem nome',
      description: data['description'] as String? ?? '',
      defaultTeacherId: data['defaultTeacherId'] as String?,
      schedules: _parseSchedules(data['schedules']),
      isActive: data['isActive'] == true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }

  List<ClassSchedule> _parseSchedules(dynamic rawSchedules) {
    if (rawSchedules is! List) {
      return const [];
    }

    final schedules = <ClassSchedule>[];

    for (final item in rawSchedules) {
      if (item is! Map) {
        continue;
      }

      final id = item['id'];
      final name = item['name'];
      final dayOfWeek = item['dayOfWeek'];
      final startTime = item['startTime'];

      if (id is! String ||
          name is! String ||
          dayOfWeek is! int ||
          startTime is! String) {
        continue;
      }

      schedules.add(
        ClassSchedule(
          id: id,
          name: name,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: item['endTime'] as String?,
          trainingTypeIds: _parseTrainingTypeIds(item),
          teacherId: item['teacherId'] as String?,
          isActive: item['isActive'] != false,
        ),
      );
    }

    schedules.sort((a, b) {
      final dayComparison = a.dayOfWeek.compareTo(b.dayOfWeek);

      if (dayComparison != 0) {
        return dayComparison;
      }

      return a.startTime.compareTo(b.startTime);
    });

    return schedules;
  }

  List<String> _parseTrainingTypeIds(Map<dynamic, dynamic> item) {
    final newFormat = item['trainingTypeIds'];

    if (newFormat is List) {
      return newFormat
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toList(growable: false);
    }

    final legacyId = item['trainingTypeId'];

    if (legacyId is String && legacyId.trim().isNotEmpty) {
      return [legacyId.trim()];
    }

    return const [];
  }

  Map<String, dynamic> _scheduleToMap(ClassSchedule schedule) {
    return {
      'id': schedule.id,
      'name': schedule.name.trim(),
      'dayOfWeek': schedule.dayOfWeek,
      'startTime': schedule.startTime,
      'endTime': _normalizeOptionalId(schedule.endTime),
      'trainingTypeIds': schedule.trainingTypeIds,
      'teacherId': _normalizeOptionalId(schedule.teacherId),
      'isActive': schedule.isActive,
    };
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
