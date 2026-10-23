import 'document_enums.dart';

class DocumentSignature {
  final String id;
  final String academyId;
  final String assignmentId;
  final String documentId;
  final String documentVersion;
  final String documentSha256;
  final String studentId;
  final String studentName;
  final String signerUserId;
  final String signerName;
  final DocumentSignerRole signerRole;
  final String acceptanceText;
  final String signatureStoragePath;
  final String signedPdfStoragePath;
  final String signedPdfSha256;
  final DateTime signedAt;

  const DocumentSignature({
    required this.id,
    required this.academyId,
    required this.assignmentId,
    required this.documentId,
    required this.documentVersion,
    required this.documentSha256,
    required this.studentId,
    required this.studentName,
    required this.signerUserId,
    required this.signerName,
    required this.signerRole,
    required this.acceptanceText,
    required this.signatureStoragePath,
    required this.signedPdfStoragePath,
    required this.signedPdfSha256,
    required this.signedAt,
  });
}
