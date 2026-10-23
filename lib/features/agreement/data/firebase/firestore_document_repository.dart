import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/document_assignment.dart';
import '../../models/document_enums.dart';
import '../../models/document_signature.dart';
import '../../models/legal_document.dart';
import '../../repository/document_repository.dart';

class FirestoreDocumentRepository implements DocumentRepository {
  final FirebaseFirestore firestore;

  FirestoreDocumentRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _documents(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('legalDocuments');
  }

  CollectionReference<Map<String, dynamic>> _assignments(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('documentAssignments');
  }

  CollectionReference<Map<String, dynamic>> _signatures(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('documentSignatures');
  }

  @override
  String createDocumentId({required String academyId}) {
    return _documents(academyId).doc().id;
  }

  @override
  String createAssignmentId({required String academyId}) {
    return _assignments(academyId).doc().id;
  }

  @override
  Future<List<LegalDocument>> getDocuments({required String academyId}) async {
    final snapshot = await _documents(academyId).get();

    final documents = snapshot.docs
        .map(
          (document) =>
              _documentFromSnapshot(academyId: academyId, snapshot: document),
        )
        .toList();

    documents.sort(
      (first, second) => second.updatedAt.compareTo(first.updatedAt),
    );

    return documents;
  }

  @override
  Future<List<LegalDocument>> getPublishedDocuments({
    required String academyId,
  }) async {
    final snapshot = await _documents(
      academyId,
    ).where('status', isEqualTo: LegalDocumentStatus.published.name).get();

    final documents = snapshot.docs
        .map(
          (document) =>
              _documentFromSnapshot(academyId: academyId, snapshot: document),
        )
        .toList();

    documents.sort(
      (first, second) => second.updatedAt.compareTo(first.updatedAt),
    );

    return documents;
  }

  @override
  Future<void> saveDraft({required LegalDocument document}) async {
    if (document.status != LegalDocumentStatus.draft) {
      throw ArgumentError('Somente documentos em rascunho podem ser salvos.');
    }

    await _documents(
      document.academyId,
    ).doc(document.id).set(_documentToMap(document));
  }

  @override
  Future<void> publishDocument({
    required String academyId,
    required String documentId,
  }) async {
    final reference = _documents(academyId).doc(documentId);

    await firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('O documento não foi encontrado.');
      }

      if (data['status'] != LegalDocumentStatus.draft.name) {
        throw StateError(
          'Somente documentos em rascunho podem ser publicados.',
        );
      }

      transaction.update(reference, {
        'status': LegalDocumentStatus.published.name,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> archiveDocument({
    required String academyId,
    required String documentId,
  }) async {
    await _documents(academyId).doc(documentId).update({
      'status': LegalDocumentStatus.archived.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> saveAssignment({required DocumentAssignment assignment}) async {
    if (assignment.status != DocumentAssignmentStatus.pending) {
      throw ArgumentError('Uma nova atribuição deve estar pendente.');
    }

    await _assignments(
      assignment.academyId,
    ).doc(assignment.id).set(_assignmentToMap(assignment));
  }

  @override
  Future<List<DocumentAssignment>> getAssignmentsForStudent({
    required String academyId,
    required String studentId,
  }) async {
    final snapshot = await _assignments(
      academyId,
    ).where('studentId', isEqualTo: studentId).get();

    final assignments = snapshot.docs
        .map(
          (document) =>
              _assignmentFromSnapshot(academyId: academyId, snapshot: document),
        )
        .toList();

    assignments.sort(
      (first, second) => second.assignedAt.compareTo(first.assignedAt),
    );

    return assignments;
  }

  @override
  Future<List<DocumentAssignment>> getAssignmentsForSigner({
    required String academyId,
    required String signerUserId,
  }) async {
    final snapshot = await _assignments(
      academyId,
    ).where('assignedSignerUserId', isEqualTo: signerUserId).get();

    final assignments = snapshot.docs
        .map(
          (document) =>
              _assignmentFromSnapshot(academyId: academyId, snapshot: document),
        )
        .toList();

    assignments.sort(
      (first, second) => second.assignedAt.compareTo(first.assignedAt),
    );

    return assignments;
  }

  @override
  Future<DocumentSignature?> getSignatureByAssignment({
    required String academyId,
    required String assignmentId,
  }) async {
    final snapshot = await _signatures(
      academyId,
    ).where('assignmentId', isEqualTo: assignmentId).limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return _signatureFromSnapshot(
      academyId: academyId,
      snapshot: snapshot.docs.first,
    );
  }

  LegalDocument _documentFromSnapshot({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();

    return LegalDocument(
      id: snapshot.id,
      academyId: academyId,
      type: _enumValue(
        LegalDocumentType.values,
        data['type'],
        fieldName: 'type',
      ),
      title: _requiredString(data, 'title'),
      description: data['description'] as String? ?? '',
      version: _requiredString(data, 'version'),
      fileName: _requiredString(data, 'fileName'),
      storagePath: _requiredString(data, 'storagePath'),
      documentSha256: _requiredString(data, 'documentSha256'),
      status: _enumValue(
        LegalDocumentStatus.values,
        data['status'],
        fieldName: 'status',
      ),
      guardianRequiredForMinor:
          data['guardianRequiredForMinor'] as bool? ?? true,
      effectiveAt: _optionalDate(data['effectiveAt']),
      expiresAt: _optionalDate(data['expiresAt']),
      publishedAt: _optionalDate(data['publishedAt']),
      createdAt: _requiredDate(data['createdAt'], 'createdAt'),
      updatedAt: _requiredDate(data['updatedAt'], 'updatedAt'),
      createdBy: _requiredString(data, 'createdBy'),
    );
  }

  DocumentAssignment _assignmentFromSnapshot({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();

    return DocumentAssignment(
      id: snapshot.id,
      academyId: academyId,
      documentId: _requiredString(data, 'documentId'),
      documentVersion: _requiredString(data, 'documentVersion'),
      studentId: _requiredString(data, 'studentId'),
      studentName: _requiredString(data, 'studentName'),
      requiredSignerRole: _enumValue(
        DocumentSignerRole.values,
        data['requiredSignerRole'],
        fieldName: 'requiredSignerRole',
      ),
      assignedSignerUserId: data['assignedSignerUserId'] as String?,
      status: _enumValue(
        DocumentAssignmentStatus.values,
        data['status'],
        fieldName: 'status',
      ),
      assignedAt: _requiredDate(data['assignedAt'], 'assignedAt'),
      signedAt: _optionalDate(data['signedAt']),
      expiresAt: _optionalDate(data['expiresAt']),
      assignedBy: _requiredString(data, 'assignedBy'),
    );
  }

  DocumentSignature _signatureFromSnapshot({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();

    return DocumentSignature(
      id: snapshot.id,
      academyId: academyId,
      assignmentId: _requiredString(data, 'assignmentId'),
      documentId: _requiredString(data, 'documentId'),
      documentVersion: _requiredString(data, 'documentVersion'),
      documentSha256: _requiredString(data, 'documentSha256'),
      studentId: _requiredString(data, 'studentId'),
      studentName: _requiredString(data, 'studentName'),
      signerUserId: _requiredString(data, 'signerUserId'),
      signerName: _requiredString(data, 'signerName'),
      signerRole: _enumValue(
        DocumentSignerRole.values,
        data['signerRole'],
        fieldName: 'signerRole',
      ),
      acceptanceText: _requiredString(data, 'acceptanceText'),
      signatureStoragePath: _requiredString(data, 'signatureStoragePath'),
      signedPdfStoragePath: _requiredString(data, 'signedPdfStoragePath'),
      signedPdfSha256: _requiredString(data, 'signedPdfSha256'),
      signedAt: _requiredDate(data['signedAt'], 'signedAt'),
    );
  }

  Map<String, dynamic> _documentToMap(LegalDocument document) {
    return {
      'type': document.type.name,
      'title': document.title.trim(),
      'description': document.description.trim(),
      'version': document.version.trim(),
      'fileName': document.fileName.trim(),
      'storagePath': document.storagePath.trim(),
      'documentSha256': document.documentSha256.trim(),
      'status': document.status.name,
      'guardianRequiredForMinor': document.guardianRequiredForMinor,
      'effectiveAt': _timestampOrNull(document.effectiveAt),
      'expiresAt': _timestampOrNull(document.expiresAt),
      'publishedAt': _timestampOrNull(document.publishedAt),
      'createdAt': Timestamp.fromDate(document.createdAt),
      'updatedAt': Timestamp.fromDate(document.updatedAt),
      'createdBy': document.createdBy,
    };
  }

  Map<String, dynamic> _assignmentToMap(DocumentAssignment assignment) {
    return {
      'documentId': assignment.documentId,
      'documentVersion': assignment.documentVersion,
      'studentId': assignment.studentId,
      'studentName': assignment.studentName,
      'requiredSignerRole': assignment.requiredSignerRole.name,
      'assignedSignerUserId': assignment.assignedSignerUserId,
      'status': assignment.status.name,
      'assignedAt': Timestamp.fromDate(assignment.assignedAt),
      'signedAt': _timestampOrNull(assignment.signedAt),
      'expiresAt': _timestampOrNull(assignment.expiresAt),
      'assignedBy': assignment.assignedBy,
    };
  }

  T _enumValue<T extends Enum>(
    List<T> values,
    Object? rawValue, {
    required String fieldName,
  }) {
    if (rawValue is! String) {
      throw FormatException('O campo $fieldName não contém um valor válido.');
    }

    for (final value in values) {
      if (value.name == rawValue) {
        return value;
      }
    }

    throw FormatException(
      'O campo $fieldName contém o valor desconhecido: $rawValue.',
    );
  }

  String _requiredString(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('O campo $fieldName não foi informado.');
  }

  DateTime _requiredDate(Object? value, String fieldName) {
    final date = _optionalDate(value);

    if (date == null) {
      throw FormatException('O campo $fieldName não contém uma data válida.');
    }

    return date;
  }

  DateTime? _optionalDate(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    throw const FormatException('O documento contém uma data inválida.');
  }

  Object? _timestampOrNull(DateTime? value) {
    if (value == null) {
      return null;
    }

    return Timestamp.fromDate(value);
  }
}
