import 'dart:math' as math;

import '../models/billing_cycle.dart';
import '../models/check_in_provider.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_summary.dart';
import '../models/payment_proof.dart';
import '../models/recurring_expense.dart';

class FinanceCalculator {
  const FinanceCalculator._();

  static FinancialSummary calculate({
    required FinancePeriod period,
    required FinanceSettings settings,
    required Iterable<BillingCycle> billingCycles,
    required Iterable<PaymentProof> paymentProofs,
    required Iterable<FinancialEntry> entries,
    Iterable<CheckInProvider> checkInProviders = const <CheckInProvider>[],
    Iterable<RecurringExpense> recurringExpenses = const <RecurringExpense>[],
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

    final providersById = <String, CheckInProvider>{};

    for (final provider in checkInProviders) {
      final providerId = provider.id.trim();

      if (providerId.isNotEmpty) {
        providersById[providerId] = provider;
      }
    }

    providersById.putIfAbsent(
      'gympass',
      () => CheckInProvider(
        id: 'gympass',
        academyId: settings.academyId,
        name: 'Gympass',
        checkInValueCents: settings.gympassCheckInValueCents,
        monthlyLimit: settings.gympassMonthlyLimit,
        sharesWithMoving: true,
        isActive: true,
        updatedAt: settings.updatedAt,
        updatedBy: settings.updatedBy,
      ),
    );

    final checkInAttendancesByProviderAndStudent =
        <String, Map<String, Set<String>>>{};

    for (final proof in paymentProofs) {
      final attendanceId = proof.attendanceId;
      final providerId = proof.effectiveCheckInProviderId;
      final provider = providerId == null ? null : providersById[providerId];

      if (!proof.isApproved ||
          !proof.isCheckInProof ||
          !period.contains(proof.referenceDate) ||
          attendanceId == null ||
          attendanceId.isEmpty ||
          providerId == null ||
          provider == null) {
        continue;
      }

      checkInAttendancesByProviderAndStudent
          .putIfAbsent(providerId, () => <String, Set<String>>{})
          .putIfAbsent(proof.studentId, () => <String>{})
          .add(attendanceId);
    }

    final checkInRevenueByProviderId = <String, int>{};
    var checkInRevenueCents = 0;
    var sharedCheckInRevenueCents = 0;

    for (final providerEntry
        in checkInAttendancesByProviderAndStudent.entries) {
      final provider = providersById[providerEntry.key]!;

      final payableCheckIns = providerEntry.value.values.fold<int>(
        0,
        (total, attendanceIds) =>
            total + math.min(attendanceIds.length, provider.monthlyLimit),
      );

      final providerRevenueCents = payableCheckIns * provider.checkInValueCents;

      checkInRevenueByProviderId[provider.id] = providerRevenueCents;
      checkInRevenueCents += providerRevenueCents;

      if (provider.sharesWithMoving) {
        sharedCheckInRevenueCents += providerRevenueCents;
      }
    }

    final gympassRevenueCents = checkInRevenueByProviderId['gympass'] ?? 0;

    final periodEntries = entries.where(
      (entry) => entry.isActive && period.contains(entry.occurredAt),
    );

    final otherIncomeCents = periodEntries
        .where((entry) => entry.isIncome)
        .fold<int>(0, (total, entry) => total + entry.amountCents);

    final otherExpensesCents = periodEntries
        .where((entry) => entry.isExpense)
        .fold<int>(0, (total, entry) => total + entry.amountCents);

    final configuredRecurringExpenses = recurringExpenses.toList(
      growable: false,
    );

    final recurringExpensesCents = configuredRecurringExpenses.isEmpty
        ? settings.instructorFixedAmountCents
        : configuredRecurringExpenses
              .where((expense) => expense.isActive)
              .fold<int>(0, (total, expense) => total + expense.amountCents);

    final movingSharedRevenueBaseCents =
        sharedMonthlyFeeRevenueCents + sharedCheckInRevenueCents;

    final grossRevenueCents =
        monthlyFeeRevenueCents + checkInRevenueCents + otherIncomeCents;

    final movingFitnessShareCents = _percentage(
      movingSharedRevenueBaseCents,
      settings.movingFitnessPercentage,
    );

    final academyShareCents = grossRevenueCents - movingFitnessShareCents;

    final rawAvailableCents =
        academyShareCents - recurringExpensesCents - otherExpensesCents;

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
      checkInRevenueCents: checkInRevenueCents,
      checkInRevenueByProviderId: Map.unmodifiable(checkInRevenueByProviderId),
      otherIncomeCents: otherIncomeCents,
      movingSharedRevenueBaseCents: movingSharedRevenueBaseCents,
      grossRevenueCents: grossRevenueCents,
      movingFitnessShareCents: movingFitnessShareCents,
      academyShareCents: academyShareCents,
      instructorCostCents: recurringExpensesCents,
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
