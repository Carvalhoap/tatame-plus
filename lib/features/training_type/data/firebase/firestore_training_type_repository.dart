import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/training_type.dart';
import '../../repository/training_type_repository.dart';

class FirestoreTrainingTypeRepository implements TrainingTypeRepository {
  final FirebaseFirestore firestore;

  FirestoreTrainingTypeRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<TrainingType>> getTrainingTypes({
    required String academyId,
    bool includeInactive = true,
  }) async {
    Query<Map<String, dynamic>> query = firestore
        .collection('academies')
        .doc(academyId)
        .collection('trainingTypes');

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    final snapshot = await query.get();

    final types = snapshot.docs
        .map(
          (document) => _fromDocument(academyId: academyId, document: document),
        )
        .toList();

    types.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return types;
  }

  @override
  Future<TrainingType?> getTrainingTypeById({
    required String academyId,
    required String trainingTypeId,
  }) async {
    final document = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('trainingTypes')
        .doc(trainingTypeId)
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
  Future<String> createTrainingType({
    required String academyId,
    required String name,
    required String description,
    required bool isActive,
    required String createdBy,
  }) async {
    final reference = firestore
        .collection('academies')
        .doc(academyId)
        .collection('trainingTypes')
        .doc();

    final now = FieldValue.serverTimestamp();

    await reference.set({
      'name': name.trim(),
      'description': description.trim(),
      'isActive': isActive,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    return reference.id;
  }

  @override
  Future<void> updateTrainingType({
    required String academyId,
    required String trainingTypeId,
    required String name,
    required String description,
    required bool isActive,
    required String updatedBy,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('trainingTypes')
        .doc(trainingTypeId)
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  @override
  Future<void> setTrainingTypeActive({
    required String academyId,
    required String trainingTypeId,
    required bool isActive,
    required String updatedBy,
  }) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('trainingTypes')
        .doc(trainingTypeId)
        .update({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': updatedBy,
        });
  }

  TrainingType _fromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    return _fromData(
      academyId: academyId,
      documentId: document.id,
      data: document.data(),
    );
  }

  TrainingType _fromData({
    required String academyId,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return TrainingType(
      id: documentId,
      academyId: academyId,
      name: data['name'] as String? ?? 'Tipo sem nome',
      description: data['description'] as String? ?? '',
      isActive: data['isActive'] == true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
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
