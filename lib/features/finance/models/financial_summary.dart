import 'finance_period.dart';

class FinancialSummary {
  final FinancePeriod period;
  final int monthlyFeeRevenueCents;
  final int sharedMonthlyFeeRevenueCents;
  final int directMonthlyFeeRevenueCents;
  final int gympassRevenueCents;
  final int checkInRevenueCents;
  final Map<String, int> checkInRevenueByProviderId;
  final int otherIncomeCents;
  final int movingSharedRevenueBaseCents;
  final int grossRevenueCents;
  final int movingFitnessShareCents;
  final int academyShareCents;
  final int instructorCostCents;
  final int otherExpensesCents;
  final int availableAfterDeductionsCents;
  final int deficitCents;
  final int gracieBarraReserveCents;
  final int partnersTotalCents;
  final int amountPerPartnerCents;
  final int pendingProofsCount;

  const FinancialSummary({
    required this.period,
    required this.monthlyFeeRevenueCents,
    required this.sharedMonthlyFeeRevenueCents,
    required this.directMonthlyFeeRevenueCents,
    required this.gympassRevenueCents,
    required this.checkInRevenueCents,
    required this.checkInRevenueByProviderId,
    required this.otherIncomeCents,
    required this.movingSharedRevenueBaseCents,
    required this.grossRevenueCents,
    required this.movingFitnessShareCents,
    required this.academyShareCents,
    required this.instructorCostCents,
    required this.otherExpensesCents,
    required this.availableAfterDeductionsCents,
    required this.deficitCents,
    required this.gracieBarraReserveCents,
    required this.partnersTotalCents,
    required this.amountPerPartnerCents,
    required this.pendingProofsCount,
  });

  double reais(int cents) => cents / 100;

  bool get hasDeficit => deficitCents > 0;
}
