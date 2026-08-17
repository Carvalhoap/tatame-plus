import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/graduation_program.dart';
import '../../models/graduation_stage.dart';
import '../../models/progression_criterion.dart';
import '../../repository/graduation_program_repository.dart';

class FirestoreGraduationProgramRepository
    implements GraduationProgramRepository {
  final FirebaseFirestore firestore;

  FirestoreGraduationProgramRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('graduationPrograms');
  }

  @override
  Future<List<GraduationProgram>> getActivePrograms({
    required String academyId,
  }) async {
    final snapshot = await _collection(
      academyId,
    ).where('isActive', isEqualTo: true).get();

    return _programsFromSnapshot(academyId: academyId, snapshot: snapshot);
  }

  @override
  Future<List<GraduationProgram>> getPrograms({
    required String academyId,
    bool includeInactive = true,
  }) async {
    Query<Map<String, dynamic>> query = _collection(academyId);

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    final snapshot = await query.get();

    return _programsFromSnapshot(academyId: academyId, snapshot: snapshot);
  }

  @override
  Future<GraduationProgram?> getProgramById({
    required String academyId,
    required String programId,
  }) async {
    final document = await _collection(academyId).doc(programId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    return _programFromData(
      academyId: academyId,
      programId: document.id,
      data: data,
    );
  }

  @override
  Future<String> createProgram({
    required String academyId,
    required String name,
    required GraduationAudience audience,
    required List<GraduationStage> stages,
    required bool isActive,
    required String createdBy,
  }) async {
    final document = _collection(academyId).doc();

    await document.set({
      'name': name.trim(),
      'audience': audience.name,
      'stages': stages.map(_stageToMap).toList(),
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    return document.id;
  }

  @override
  Future<void> updateProgram({
    required String academyId,
    required String programId,
    required String name,
    required GraduationAudience audience,
    required List<GraduationStage> stages,
    required bool isActive,
    required String updatedBy,
  }) {
    return _collection(academyId).doc(programId).update({
      'name': name.trim(),
      'audience': audience.name,
      'stages': stages.map(_stageToMap).toList(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  @override
  Future<void> setProgramActive({
    required String academyId,
    required String programId,
    required bool isActive,
    required String updatedBy,
  }) {
    return _collection(academyId).doc(programId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  List<GraduationProgram> _programsFromSnapshot({
    required String academyId,
    required QuerySnapshot<Map<String, dynamic>> snapshot,
  }) {
    final programs = snapshot.docs
        .map(
          (document) => _programFromData(
            academyId: academyId,
            programId: document.id,
            data: document.data(),
          ),
        )
        .toList();

    programs.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return programs;
  }

  GraduationProgram _programFromData({
    required String academyId,
    required String programId,
    required Map<String, dynamic> data,
  }) {
    return GraduationProgram(
      id: programId,
      academyId: academyId,
      name: data['name'] as String? ?? 'Programa sem nome',
      audience: _parseAudience(data['audience']),
      stages: _parseStages(data['stages']),
      isActive: data['isActive'] == true,
    );
  }

  Map<String, dynamic> _stageToMap(GraduationStage stage) {
    return {
      'id': stage.id,
      'name': stage.name,
      'beltName': stage.beltName,
      'degreeName': stage.degreeName,
      'stripeColor': stage.stripeColor,
      'order': stage.order,
      'criterion': stage.criterion.name,
      'requiredAttendances': stage.requiredAttendances,
      'minimumDurationMonths': stage.minimumDurationMonths,
      'nextStageId': stage.nextStageId,
    };
  }

  GraduationAudience _parseAudience(dynamic value) {
    switch (value) {
      case 'kids':
        return GraduationAudience.kids;

      case 'adult':
        return GraduationAudience.adult;

      default:
        return GraduationAudience.custom;
    }
  }

  List<GraduationStage> _parseStages(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final stages = value
        .whereType<Map>()
        .map(
          (stage) => GraduationStage(
            id: stage['id'] as String? ?? '',
            name: stage['name'] as String? ?? '',
            beltName: stage['beltName'] as String? ?? '',
            degreeName: stage['degreeName'] as String?,
            stripeColor: stage['stripeColor'] as String?,
            order: stage['order'] as int? ?? 0,
            criterion: _parseCriterion(stage['criterion']),
            requiredAttendances: stage['requiredAttendances'] as int?,
            minimumDurationMonths: stage['minimumDurationMonths'] as int?,
            nextStageId: stage['nextStageId'] as String?,
          ),
        )
        .where((stage) => stage.id.isNotEmpty)
        .toList();

    stages.sort((a, b) => a.order.compareTo(b.order));

    return stages;
  }

  ProgressionCriterion _parseCriterion(dynamic value) {
    switch (value) {
      case 'attendance':
        return ProgressionCriterion.attendance;

      case 'time':
        return ProgressionCriterion.time;

      case 'attendanceAndTime':
        return ProgressionCriterion.attendanceAndTime;

      default:
        return ProgressionCriterion.manual;
    }
  }
}
