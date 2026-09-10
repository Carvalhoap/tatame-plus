import 'dart:typed_data';

import '../../models/billing_cycle.dart';
import '../../models/finance_enums.dart';
import '../../models/finance_period.dart';
import '../../models/finance_settings.dart';
import '../../models/financial_entry.dart';
import '../../models/financial_profile.dart';
import '../../models/payment_proof.dart';
import '../../repository/finance_repository.dart';
import 'firestore_billing_data_source.dart';
import 'firestore_finance_profile_data_source.dart';
import 'firestore_financial_entry_data_source.dart';
import 'firestore_payment_proof_data_source.dart';

class FirestoreFinanceRepository implements FinanceRepository {
  final FirestoreFinanceProfileDataSource profileDataSource;
  final FirestoreBillingDataSource billingDataSource;
  final FirestorePaymentProofDataSource proofDataSource;
  final FirestoreFinancialEntryDataSource entryDataSource;

  FirestoreFinanceRepository({
    FirestoreFinanceProfileDataSource? profileDataSource,
    FirestoreBillingDataSource? billingDataSource,
    FirestorePaymentProofDataSource? proofDataSource,
    FirestoreFinancialEntryDataSource? entryDataSource,
  }) : profileDataSource =
           profileDataSource ?? FirestoreFinanceProfileDataSource(),
       billingDataSource =
           billingDataSource ??
           FirestoreBillingDataSource(
             profileDataSource:
                 profileDataSource ?? FirestoreFinanceProfileDataSource(),
           ),
       proofDataSource = proofDataSource ?? FirestorePaymentProofDataSource(),
       entryDataSource = entryDataSource ?? FirestoreFinancialEntryDataSource();

  @override
  Future<FinanceSettings> getSettings({required String academyId}) {
    return profileDataSource.getSettings(academyId: academyId);
  }

  @override
  Future<void> saveSettings({
    required FinanceSettings settings,
    required String updatedBy,
  }) {
    return profileDataSource.saveSettings(
      settings: settings,
      updatedBy: updatedBy,
    );
  }

  @override
  Future<FinancialProfile?> getFinancialProfile({
    required String academyId,
    required String studentId,
  }) {
    return profileDataSource.getFinancialProfile(
      academyId: academyId,
      studentId: studentId,
    );
  }

  @override
  Future<List<FinancialProfile>> getFinancialProfiles({
    required String academyId,
  }) {
    return profileDataSource.getFinancialProfiles(academyId: academyId);
  }

  @override
  Future<void> saveFinancialProfile({required FinancialProfile profile}) {
    return profileDataSource.saveFinancialProfile(profile: profile);
  }

  @override
  Future<BillingCycle> getOrCreateBillingCycle({
    required String academyId,
    required String studentId,
    required FinancePeriod period,
    required String createdBy,
  }) {
    return billingDataSource.getOrCreateBillingCycle(
      academyId: academyId,
      studentId: studentId,
      period: period,
      createdBy: createdBy,
    );
  }

  @override
  Future<List<BillingCycle>> getBillingCycles({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  }) {
    return billingDataSource.getBillingCycles(
      academyId: academyId,
      period: period,
      studentId: studentId,
    );
  }

  @override
  Future<void> markBillingCyclePaid({
    required String academyId,
    required String billingCycleId,
    required int amountCents,
    required PaymentMethod paymentMethod,
    required String paidBy,
  }) {
    return billingDataSource.markBillingCyclePaid(
      academyId: academyId,
      billingCycleId: billingCycleId,
      amountCents: amountCents,
      paymentMethod: paymentMethod,
      paidBy: paidBy,
    );
  }

  @override
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
  }) {
    return proofDataSource.submitPaymentProof(
      academyId: academyId,
      studentId: studentId,
      submittedBy: submittedBy,
      type: type,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      paymentMethod: paymentMethod,
      referenceDate: referenceDate,
      billingCycleId: billingCycleId,
      attendanceId: attendanceId,
      previousStoragePath: previousStoragePath,
    );
  }

  @override
  Future<List<PaymentProof>> getPaymentProofs({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
    PaymentProofStatus? status,
  }) {
    return proofDataSource.getPaymentProofs(
      academyId: academyId,
      period: period,
      studentId: studentId,
      status: status,
    );
  }

  @override
  Future<String> getPaymentProofDownloadUrl({required String storagePath}) {
    return proofDataSource.getPaymentProofDownloadUrl(storagePath: storagePath);
  }

  @override
  Future<void> reviewPaymentProof({
    required String academyId,
    required String proofId,
    required PaymentProofStatus status,
    required String reviewedBy,
    String? rejectionReason,
  }) {
    return proofDataSource.reviewPaymentProof(
      academyId: academyId,
      proofId: proofId,
      status: status,
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );
  }

  @override
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
  }) {
    return entryDataSource.createFinancialEntry(
      academyId: academyId,
      type: type,
      category: category,
      description: description,
      amountCents: amountCents,
      occurredAt: occurredAt,
      createdBy: createdBy,
      studentId: studentId,
      paymentMethod: paymentMethod,
    );
  }

  @override
  Future<List<FinancialEntry>> getFinancialEntries({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  }) {
    return entryDataSource.getFinancialEntries(
      academyId: academyId,
      period: period,
      studentId: studentId,
    );
  }

  @override
  Future<void> cancelFinancialEntry({
    required String academyId,
    required String entryId,
    required String cancelledBy,
  }) {
    return entryDataSource.cancelFinancialEntry(
      academyId: academyId,
      entryId: entryId,
      cancelledBy: cancelledBy,
    );
  }
}
