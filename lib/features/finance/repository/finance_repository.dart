import 'dart:typed_data';

import '../models/billing_cycle.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/finance_settings.dart';
import '../models/financial_entry.dart';
import '../models/financial_profile.dart';
import '../models/payment_proof.dart';

abstract class FinanceRepository {
  Future<FinanceSettings> getSettings({required String academyId});

  Future<void> saveSettings({
    required FinanceSettings settings,
    required String updatedBy,
  });

  Future<FinancialProfile?> getFinancialProfile({
    required String academyId,
    required String studentId,
  });

  Future<List<FinancialProfile>> getFinancialProfiles({
    required String academyId,
  });

  Future<void> saveFinancialProfile({required FinancialProfile profile});

  Future<BillingCycle> getOrCreateBillingCycle({
    required String academyId,
    required String studentId,
    required FinancePeriod period,
    required String createdBy,
  });

  Future<List<BillingCycle>> getBillingCycles({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  });

  Future<void> markBillingCyclePaid({
    required String academyId,
    required String billingCycleId,
    required int amountCents,
    required PaymentMethod paymentMethod,
    RevenueDestination revenueDestination = RevenueDestination.movingFitness,
    required String paidBy,
  });

  Future<PaymentProof> submitPaymentProof({
    required String academyId,
    required String studentId,
    required String submittedBy,
    required PaymentProofType type,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required PaymentMethod paymentMethod,
    required DateTime referenceDate,
    String? billingCycleId,
    String? attendanceId,
    String? previousStoragePath,
  });

  Future<List<PaymentProof>> getPaymentProofs({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
    PaymentProofStatus? status,
  });

  Future<String> getPaymentProofDownloadUrl({required String storagePath});

  Future<void> reviewPaymentProof({
    required String academyId,
    required String proofId,
    required PaymentProofStatus status,
    required String reviewedBy,
    RevenueDestination? revenueDestination,
    String? rejectionReason,
  });

  Future<String> createFinancialEntry({
    required String academyId,
    required FinancialEntryType type,
    required String category,
    required String description,
    required int amountCents,
    required DateTime occurredAt,
    required String createdBy,
    String? studentId,
    PaymentMethod? paymentMethod,
  });

  Future<List<FinancialEntry>> getFinancialEntries({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  });

  Future<void> cancelFinancialEntry({
    required String academyId,
    required String entryId,
    required String cancelledBy,
  });
}
