import 'package:flutter_test/flutter_test.dart';
import 'package:tatame_plus/features/finance/models/billing_cycle.dart';
import 'package:tatame_plus/features/finance/models/finance_enums.dart';
import 'package:tatame_plus/features/finance/models/finance_period.dart';
import 'package:tatame_plus/features/finance/models/finance_settings.dart';
import 'package:tatame_plus/features/finance/models/financial_entry.dart';
import 'package:tatame_plus/features/finance/models/payment_proof.dart';
import 'package:tatame_plus/features/finance/services/finance_calculator.dart';

void main() {
  group('FinancePeriod', () {
    test('usa o período do dia 15 ao dia 14', () {
      final period = FinancePeriod.containing(DateTime(2026, 10, 10));

      expect(period.start, DateTime(2026, 9, 15));
      expect(period.endExclusive, DateTime(2026, 10, 15));
      expect(period.displayEnd, DateTime(2026, 10, 14));
      expect(period.key, '2026-09');
      expect(period.contains(DateTime(2026, 10, 14, 23, 59)), isTrue);
      expect(period.contains(DateTime(2026, 10, 15)), isFalse);
    });

    test('posiciona o vencimento dentro da competência', () {
      final period = FinancePeriod.fromReference(year: 2026, month: 9);

      expect(period.dueDateForDay(20), DateTime(2026, 9, 20));
      expect(period.dueDateForDay(10), DateTime(2026, 10, 10));
    });
  });

  group('FinanceCalculator', () {
    final period = FinancePeriod.fromReference(year: 2026, month: 9);
    final settings = FinanceSettings.defaults(academyId: 'academy');

    test('calcula o fechamento na ordem definida pela academia', () {
      final billingCycle = _monthlyCycle(
        id: 'cycle',
        period: period,
        amountCents: 1000000,
        revenueDestination: RevenueDestination.movingFitness,
      );

      final expense = FinancialEntry(
        id: 'expense',
        academyId: 'academy',
        studentId: null,
        type: FinancialEntryType.expense,
        category: 'Despesa operacional',
        description: 'Despesa de teste',
        amountCents: 100000,
        paymentMethod: PaymentMethod.pix,
        occurredAt: DateTime(2026, 9, 21),
        createdBy: 'admin',
        createdAt: null,
        isCancelled: false,
        cancelledBy: null,
        cancelledAt: null,
      );

      final summary = FinanceCalculator.calculate(
        period: period,
        settings: settings,
        billingCycles: [billingCycle],
        paymentProofs: const [],
        entries: [expense],
      );

      expect(summary.grossRevenueCents, 1000000);
      expect(summary.movingSharedRevenueBaseCents, 1000000);
      expect(summary.movingFitnessShareCents, 500000);
      expect(summary.academyShareCents, 500000);
      expect(summary.instructorCostCents, 80000);
      expect(summary.otherExpensesCents, 100000);
      expect(summary.availableAfterDeductionsCents, 320000);
      expect(summary.gracieBarraReserveCents, 128000);
      expect(summary.partnersTotalCents, 192000);
      expect(summary.amountPerPartnerCents, 96000);
      expect(summary.deficitCents, 0);
    });

    test(
      'não divide mensalidades diretas nem outras receitas com a Moving',
      () {
        final sharedMonthlyFee = _monthlyCycle(
          id: 'shared',
          period: period,
          amountCents: 400000,
          revenueDestination: RevenueDestination.movingFitness,
        );

        final directMonthlyFee = _monthlyCycle(
          id: 'direct',
          period: period,
          amountCents: 100000,
          revenueDestination: RevenueDestination.team,
        );

        final otherIncome = FinancialEntry(
          id: 'graduation',
          academyId: 'academy',
          studentId: 'student',
          type: FinancialEntryType.income,
          category: 'Graduação',
          description: 'Faixa e certificado',
          amountCents: 50000,
          paymentMethod: PaymentMethod.pix,
          occurredAt: DateTime(2026, 9, 25),
          createdBy: 'admin',
          createdAt: null,
          isCancelled: false,
          cancelledBy: null,
          cancelledAt: null,
        );

        final summary = FinanceCalculator.calculate(
          period: period,
          settings: settings,
          billingCycles: [sharedMonthlyFee, directMonthlyFee],
          paymentProofs: const [],
          entries: [otherIncome],
        );

        expect(summary.sharedMonthlyFeeRevenueCents, 400000);
        expect(summary.directMonthlyFeeRevenueCents, 100000);
        expect(summary.otherIncomeCents, 50000);
        expect(summary.movingSharedRevenueBaseCents, 400000);
        expect(summary.grossRevenueCents, 550000);
        expect(summary.movingFitnessShareCents, 200000);
        expect(summary.academyShareCents, 350000);
        expect(summary.availableAfterDeductionsCents, 270000);
        expect(summary.gracieBarraReserveCents, 108000);
        expect(summary.partnersTotalCents, 162000);
        expect(summary.amountPerPartnerCents, 81000);
      },
    );

    test('limita o Gympass a 12 aprovações por aluno', () {
      final approvedProofs = List.generate(
        13,
        (index) => _gympassProof(
          id: 'proof_$index',
          attendanceId: 'attendance_$index',
          status: PaymentProofStatus.approved,
        ),
      );

      final pendingProof = _gympassProof(
        id: 'pending',
        attendanceId: 'attendance_pending',
        status: PaymentProofStatus.pending,
      );

      final summary = FinanceCalculator.calculate(
        period: period,
        settings: settings,
        billingCycles: const [],
        paymentProofs: [...approvedProofs, pendingProof],
        entries: const [],
      );

      expect(summary.gympassRevenueCents, 12 * 1349);
      expect(summary.movingSharedRevenueBaseCents, 12 * 1349);
      expect(summary.movingFitnessShareCents, 8094);
      expect(summary.pendingProofsCount, 1);
    });
  });
}

BillingCycle _monthlyCycle({
  required String id,
  required FinancePeriod period,
  required int amountCents,
  required RevenueDestination revenueDestination,
}) {
  return BillingCycle(
    id: id,
    academyId: 'academy',
    studentId: 'student_$id',
    period: period,
    billingMode: BillingMode.monthlyFee,
    expectedAmountCents: amountCents,
    paidAmountCents: amountCents,
    dueDate: DateTime(2026, 9, 20),
    status: BillingStatus.paid,
    paymentMethod: PaymentMethod.pix,
    revenueDestination: revenueDestination,
    paymentProofId: null,
    paidAt: DateTime(2026, 9, 20),
    createdAt: null,
    updatedAt: null,
  );
}

PaymentProof _gympassProof({
  required String id,
  required String attendanceId,
  required PaymentProofStatus status,
}) {
  return PaymentProof(
    id: id,
    academyId: 'academy',
    studentId: 'student',
    submittedBy: 'user',
    type: PaymentProofType.gympassCheckIn,
    status: status,
    billingCycleId: null,
    attendanceId: attendanceId,
    storagePath: 'proofs/$id.jpg',
    fileName: '$id.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 1000,
    referenceDate: DateTime(2026, 9, 20),
    submittedAt: null,
    reviewedAt: null,
    reviewedBy: null,
    rejectionReason: null,
  );
}
