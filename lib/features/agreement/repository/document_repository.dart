import '../models/document_assignment.dart';
import '../models/document_signature.dart';
import '../models/legal_document.dart';

abstract class DocumentRepository {
  String createDocumentId({required String academyId});

  String createAssignmentId({required String academyId});

  Future<List<LegalDocument>> getDocuments({required String academyId});

  Future<List<LegalDocument>> getPublishedDocuments({
    required String academyId,
  });

  Future<void> saveDraft({required LegalDocument document});

  Future<void> publishDocument({
    required String academyId,
    required String documentId,
  });

  Future<void> archiveDocument({
    required String academyId,
    required String documentId,
  });

  Future<void> saveAssignment({required DocumentAssignment assignment});

  Future<List<DocumentAssignment>> getAssignmentsForStudent({
    required String academyId,
    required String studentId,
  });

  Future<List<DocumentAssignment>> getAssignmentsForSigner({
    required String academyId,
    required String signerUserId,
  });

  Future<DocumentSignature?> getSignatureByAssignment({
    required String academyId,
    required String assignmentId,
  });
}
