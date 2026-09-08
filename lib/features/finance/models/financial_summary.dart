import 'finance_period.dart';

class FinancialSummary {
  final FinancePeriod period;
  final int monthlyFeeRevenueCents;
  final int gympassRevenueCents;
  final int otherIncomeCents;
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
    required this.gympassRevenueCents,
    required this.otherIncomeCents,
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
