import 'finance_enums.dart';

class PaymentProof {
  final String id;
  final String academyId;
  final String studentId;
  final String submittedBy;
  final PaymentProofType type;
  final PaymentProofStatus status;
  final String? billingCycleId;
  final String? attendanceId;
  final String? checkInProviderId;
  final String storagePath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final PaymentMethod? paymentMethod;
  final DateTime referenceDate;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  const PaymentProof({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.submittedBy,
    required this.type,
    required this.status,
    required this.billingCycleId,
    required this.attendanceId,
    this.checkInProviderId,
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.paymentMethod,
    required this.referenceDate,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.rejectionReason,
  });

  bool get isPending => status == PaymentProofStatus.pending;

  bool get isApproved => status == PaymentProofStatus.approved;

  bool get isRejected => status == PaymentProofStatus.rejected;

  bool get isGympassCheckIn => type == PaymentProofType.gympassCheckIn;

  bool get isCheckInProof => isGympassCheckIn;

  String? get effectiveCheckInProviderId {
    if (!isCheckInProof) {
      return null;
    }

    final normalizedId = checkInProviderId?.trim() ?? '';

    return normalizedId.isEmpty ? 'gympass' : normalizedId;
  }
}
