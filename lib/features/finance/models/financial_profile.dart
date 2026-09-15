import 'finance_enums.dart';

class FinancialProfile {
  final String academyId;
  final String studentId;
  final BillingMode billingMode;
  final String? checkInProviderId;
  final int monthlyFeeCents;
  final int dueDay;
  final bool isActive;
  final DateTime? updatedAt;
  final String updatedBy;

  const FinancialProfile({
    required this.academyId,
    required this.studentId,
    required this.billingMode,
    this.checkInProviderId,
    required this.monthlyFeeCents,
    required this.dueDay,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  double get monthlyFee => monthlyFeeCents / 100;

  String? get effectiveCheckInProviderId {
    if (billingMode != BillingMode.gympass) {
      return null;
    }

    final normalizedId = checkInProviderId?.trim() ?? '';

    return normalizedId.isEmpty ? 'gympass' : normalizedId;
  }

  FinancialProfile copyWith({
    BillingMode? billingMode,
    String? checkInProviderId,
    bool clearCheckInProviderId = false,
    int? monthlyFeeCents,
    int? dueDay,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return FinancialProfile(
      academyId: academyId,
      studentId: studentId,
      billingMode: billingMode ?? this.billingMode,
      checkInProviderId: clearCheckInProviderId
          ? null
          : checkInProviderId ?? this.checkInProviderId,
      monthlyFeeCents: monthlyFeeCents ?? this.monthlyFeeCents,
      dueDay: dueDay ?? this.dueDay,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
