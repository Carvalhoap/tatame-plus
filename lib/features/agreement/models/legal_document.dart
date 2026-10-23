import 'document_enums.dart';

class LegalDocument {
  final String id;
  final String academyId;
  final LegalDocumentType type;
  final String title;
  final String description;
  final String version;
  final String fileName;
  final String storagePath;
  final String documentSha256;
  final LegalDocumentStatus status;
  final bool guardianRequiredForMinor;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  const LegalDocument({
    required this.id,
    required this.academyId,
    required this.type,
    required this.title,
    required this.description,
    required this.version,
    required this.fileName,
    required this.storagePath,
    required this.documentSha256,
    required this.status,
    required this.guardianRequiredForMinor,
    required this.effectiveAt,
    required this.expiresAt,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  bool get isPublished {
    return status == LegalDocumentStatus.published;
  }

  bool isEffectiveAt(DateTime dateTime) {
    if (!isPublished) {
      return false;
    }

    if (effectiveAt != null && dateTime.isBefore(effectiveAt!)) {
      return false;
    }

    if (expiresAt != null && !dateTime.isBefore(expiresAt!)) {
      return false;
    }

    return true;
  }
}
