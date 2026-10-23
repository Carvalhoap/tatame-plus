import 'document_enums.dart';

class DocumentAssignment {
  final String id;
  final String academyId;
  final String documentId;
  final String documentVersion;
  final String studentId;
  final String studentName;
  final DocumentSignerRole requiredSignerRole;
  final String? assignedSignerUserId;
  final DocumentAssignmentStatus status;
  final DateTime assignedAt;
  final DateTime? signedAt;
  final DateTime? expiresAt;
  final String assignedBy;

  const DocumentAssignment({
    required this.id,
    required this.academyId,
    required this.documentId,
    required this.documentVersion,
    required this.studentId,
    required this.studentName,
    required this.requiredSignerRole,
    required this.assignedSignerUserId,
    required this.status,
    required this.assignedAt,
    required this.signedAt,
    required this.expiresAt,
    required this.assignedBy,
  });

  bool get isPending {
    return status == DocumentAssignmentStatus.pending;
  }

  bool get isSigned {
    return status == DocumentAssignmentStatus.signed;
  }

  bool isExpiredAt(DateTime dateTime) {
    return status == DocumentAssignmentStatus.expired ||
        (expiresAt != null && !dateTime.isBefore(expiresAt!));
  }
}
