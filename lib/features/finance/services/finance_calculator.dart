import 'dart:math' as math;

import '../models/billing_cycle.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_summary.dart';
import '../models/payment_proof.dart';

class FinanceCalculator {
  const FinanceCalculator._();

  static FinancialSummary calculate({
    required FinancePeriod period,
    required FinanceSettings settings,
    required Iterable<BillingCycle> billingCycles,
    required Iterable<PaymentProof> paymentProofs,
    required Iterable<FinancialEntry> entries,
  }) {
    if (settings.remainingPartnersCount < 1) {
      throw StateError('A quantidade de sócios deve ser maior que zero.');
    }

    final monthlyFeeCycles = billingCycles.where(
      (cycle) =>
          cycle.referenceKey == period.key &&
          cycle.billingMode == BillingMode.monthlyFee,
    );

    final sharedMonthlyFeeRevenueCents = monthlyFeeCycles
        .where((cycle) => cycle.isSharedWithMoving)
        .fold<int>(0, (total, cycle) => total + cycle.paidAmountCents);

    final directMonthlyFeeRevenueCents = monthlyFeeCycles
        .where((cycle) => !cycle.isSharedWithMoving)
        .fold<int>(0, (total, cycle) => total + cycle.paidAmountCents);

    final monthlyFeeRevenueCents =
        sharedMonthlyFeeRevenueCents + directMonthlyFeeRevenueCents;

    final gympassAttendancesByStudent = <String, Set<String>>{};

    for (final proof in paymentProofs) {
      final attendanceId = proof.attendanceId;

      if (!proof.isApproved ||
          !proof.isGympassCheckIn ||
          !period.contains(proof.referenceDate) ||
          attendanceId == null ||
          attendanceId.isEmpty) {
        continue;
      }

      gympassAttendancesByStudent
          .putIfAbsent(proof.studentId, () => <String>{})
          .add(attendanceId);
    }

    final payableGympassCheckIns = gympassAttendancesByStudent.values.fold<int>(
      0,
      (total, attendanceIds) =>
          total + math.min(attendanceIds.length, settings.gympassMonthlyLimit),
    );

    final gympassRevenueCents =
        payableGympassCheckIns * settings.gympassCheckInValueCents;

    final periodEntries = entries.where(
      (entry) => entry.isActive && period.contains(entry.occurredAt),
    );

    final otherIncomeCents = periodEntries
        .where((entry) => entry.isIncome)
        .fold<int>(0, (total, entry) => total + entry.amountCents);

    final otherExpensesCents = periodEntries
        .where((entry) => entry.isExpense)
        .fold<int>(0, (total, entry) => total + entry.amountCents);

    final movingSharedRevenueBaseCents =
        sharedMonthlyFeeRevenueCents + gympassRevenueCents;

    final grossRevenueCents =
        monthlyFeeRevenueCents + gympassRevenueCents + otherIncomeCents;

    final movingFitnessShareCents = _percentage(
      movingSharedRevenueBaseCents,
      settings.movingFitnessPercentage,
    );

    final academyShareCents = grossRevenueCents - movingFitnessShareCents;

    final rawAvailableCents =
        academyShareCents -
        settings.instructorFixedAmountCents -
        otherExpensesCents;

    final availableAfterDeductionsCents = math.max(0, rawAvailableCents);
    final deficitCents = math.max(0, -rawAvailableCents);

    final gracieBarraReserveCents = _percentage(
      availableAfterDeductionsCents,
      settings.gracieBarraReservePercentage,
    );

    final partnersTotalCents =
        availableAfterDeductionsCents - gracieBarraReserveCents;

    final amountPerPartnerCents =
        partnersTotalCents ~/ settings.remainingPartnersCount;

    final pendingProofsCount = paymentProofs
        .where(
          (proof) => proof.isPending && period.contains(proof.referenceDate),
        )
        .length;

    return FinancialSummary(
      period: period,
      monthlyFeeRevenueCents: monthlyFeeRevenueCents,
      sharedMonthlyFeeRevenueCents: sharedMonthlyFeeRevenueCents,
      directMonthlyFeeRevenueCents: directMonthlyFeeRevenueCents,
      gympassRevenueCents: gympassRevenueCents,
      otherIncomeCents: otherIncomeCents,
      movingSharedRevenueBaseCents: movingSharedRevenueBaseCents,
      grossRevenueCents: grossRevenueCents,
      movingFitnessShareCents: movingFitnessShareCents,
      academyShareCents: academyShareCents,
      instructorCostCents: settings.instructorFixedAmountCents,
      otherExpensesCents: otherExpensesCents,
      availableAfterDeductionsCents: availableAfterDeductionsCents,
      deficitCents: deficitCents,
      gracieBarraReserveCents: gracieBarraReserveCents,
      partnersTotalCents: partnersTotalCents,
      amountPerPartnerCents: amountPerPartnerCents,
      pendingProofsCount: pendingProofsCount,
    );
  }

  static int _percentage(int valueCents, int percentage) {
    if (percentage < 0 || percentage > 100) {
      throw ArgumentError.value(
        percentage,
        'percentage',
        'O percentual deve estar entre 0 e 100.',
      );
    }

    return ((valueCents * percentage) + 50) ~/ 100;
  }
}
