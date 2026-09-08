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
      final billingCycle = BillingCycle(
        id: 'cycle',
        academyId: 'academy',
        studentId: 'student',
        period: period,
        billingMode: BillingMode.monthlyFee,
        expectedAmountCents: 1000000,
        paidAmountCents: 1000000,
        dueDate: DateTime(2026, 9, 20),
        status: BillingStatus.paid,
        paymentMethod: PaymentMethod.pix,
        paymentProofId: null,
        paidAt: DateTime(2026, 9, 20),
        createdAt: null,
        updatedAt: null,
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
      expect(summary.pendingProofsCount, 1);
    });
  });
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
