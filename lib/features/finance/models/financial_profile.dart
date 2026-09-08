import 'finance_enums.dart';

class FinancialProfile {
  final String academyId;
  final String studentId;
  final BillingMode billingMode;
  final int monthlyFeeCents;
  final int dueDay;
  final bool isActive;
  final DateTime? updatedAt;
  final String updatedBy;

  const FinancialProfile({
    required this.academyId,
    required this.studentId,
    required this.billingMode,
    required this.monthlyFeeCents,
    required this.dueDay,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  double get monthlyFee => monthlyFeeCents / 100;

  FinancialProfile copyWith({
    BillingMode? billingMode,
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
      monthlyFeeCents: monthlyFeeCents ?? this.monthlyFeeCents,
      dueDay: dueDay ?? this.dueDay,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
