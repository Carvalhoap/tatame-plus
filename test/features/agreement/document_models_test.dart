import 'package:flutter_test/flutter_test.dart';
import 'package:tatame_plus/features/agreement/models/document_assignment.dart';
import 'package:tatame_plus/features/agreement/models/document_enums.dart';
import 'package:tatame_plus/features/agreement/models/document_signature.dart';
import 'package:tatame_plus/features/agreement/models/legal_document.dart';

void main() {
  group('LegalDocument', () {
    test('disponibiliza os sete tipos aprovados', () {
      expect(LegalDocumentType.values, hasLength(7));
      expect(LegalDocumentType.riskAcknowledgement.label, 'Ciência de riscos');
      expect(LegalDocumentType.privacyAndLgpd.label, 'Privacidade e LGPD');
    });

    test('considera vigência e publicação', () {
      final document = LegalDocument(
        id: 'document-1',
        academyId: 'academy-1',
        type: LegalDocumentType.riskAcknowledgement,
        title: 'Ciência de riscos',
        description: 'Documento de teste.',
        version: '1',
        fileName: 'ciencia-de-riscos.pdf',
        storagePath: 'academies/academy-1/documents/document-1/v1.pdf',
        documentSha256: 'hash-documento',
        status: LegalDocumentStatus.published,
        guardianRequiredForMinor: true,
        effectiveAt: DateTime.utc(2026, 10, 1),
        expiresAt: DateTime.utc(2027, 10, 1),
        publishedAt: DateTime.utc(2026, 10, 1),
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 10, 1),
        createdBy: 'admin-1',
      );

      expect(document.isEffectiveAt(DateTime.utc(2026, 10, 22)), isTrue);

      expect(document.isEffectiveAt(DateTime.utc(2027, 10, 1)), isFalse);
    });
  });

  group('DocumentAssignment', () {
    test('mantém o aluno e o responsável vinculados', () {
      final assignment = DocumentAssignment(
        id: 'assignment-1',
        academyId: 'academy-1',
        documentId: 'document-1',
        documentVersion: '1',
        studentId: 'student-1',
        studentName: 'Aluno Teste',
        requiredSignerRole: DocumentSignerRole.guardian,
        assignedSignerUserId: 'guardian-1',
        status: DocumentAssignmentStatus.pending,
        assignedAt: DateTime.utc(2026, 10, 22),
        signedAt: null,
        expiresAt: null,
        assignedBy: 'admin-1',
      );

      expect(assignment.isPending, isTrue);
      expect(assignment.isSigned, isFalse);
      expect(assignment.assignedSignerUserId, 'guardian-1');
    });
  });

  group('DocumentSignature', () {
    test('preserva evidências da assinatura', () {
      final signature = DocumentSignature(
        id: 'signature-1',
        academyId: 'academy-1',
        assignmentId: 'assignment-1',
        documentId: 'document-1',
        documentVersion: '1',
        documentSha256: 'hash-documento',
        studentId: 'student-1',
        studentName: 'Aluno Teste',
        signerUserId: 'guardian-1',
        signerName: 'Responsável Teste',
        signerRole: DocumentSignerRole.guardian,
        acceptanceText: 'Li e concordo com o documento.',
        signatureStoragePath: 'signatures/signature-1.png',
        signedPdfStoragePath: 'signed/signature-1.pdf',
        signedPdfSha256: 'hash-pdf-assinado',
        signedAt: DateTime.utc(2026, 10, 22, 15),
      );

      expect(signature.documentVersion, '1');
      expect(signature.signerRole, DocumentSignerRole.guardian);
      expect(signature.signedPdfSha256, isNotEmpty);
    });
  });
}
