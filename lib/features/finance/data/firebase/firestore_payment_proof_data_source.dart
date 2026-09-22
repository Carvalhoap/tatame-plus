import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/finance_enums.dart';
import '../../models/finance_period.dart';
import '../../models/payment_proof.dart';
import 'finance_firestore_parser.dart';
import 'finance_storage_service.dart';

class FirestorePaymentProofDataSource {
  final FirebaseFirestore firestore;
  final FinanceStorageService storageService;

  FirestorePaymentProofDataSource({
    FirebaseFirestore? firestore,
    FinanceStorageService? storageService,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       storageService = storageService ?? FinanceStorageService();

  CollectionReference<Map<String, dynamic>> _proofs(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('paymentProofs');
  }

  CollectionReference<Map<String, dynamic>> _billingCycles(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('billingCycles');
  }

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
    String? checkInProviderId,
    String? previousStoragePath,
  }) async {
    final resolvedCheckInProviderId = type == PaymentProofType.gympassCheckIn
        ? _normalizeCheckInProviderId(checkInProviderId)
        : null;

    _validateSubmission(
      type: type,
      paymentMethod: paymentMethod,
      billingCycleId: billingCycleId,
      attendanceId: attendanceId,
      checkInProviderId: resolvedCheckInProviderId,
    );

    final proofId = type == PaymentProofType.gympassCheckIn
        ? '${resolvedCheckInProviderId!}_$attendanceId'
        : 'monthly_$billingCycleId';

    final reference = _proofs(academyId).doc(proofId);

    final storagePath = await storageService.uploadProof(
      academyId: academyId,
      studentId: studentId,
      proofId: proofId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    final period = FinancePeriod.containing(referenceDate);
    try {
      await reference.set({
        'studentId': studentId,
        'submittedBy': submittedBy,
        'type': type.name,
        'status': PaymentProofStatus.pending.name,
        'billingCycleId': billingCycleId,
        'attendanceId': attendanceId,
        'checkInProviderId': resolvedCheckInProviderId,
        'storagePath': storagePath,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': bytes.length,
        'paymentMethod': paymentMethod.name,
        'periodKey': period.key,
        'referenceDate': Timestamp.fromDate(referenceDate),
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (previousStoragePath != storagePath) {
        try {
          await storageService.deleteProof(storagePath);
        } catch (_) {
          // A limpeza poderá ser feita posteriormente.
        }
      }

      rethrow;
    }

    if (previousStoragePath != null && previousStoragePath != storagePath) {
      try {
        await storageService.deleteProof(previousStoragePath);
      } catch (_) {
        // O comprovante novo já foi salvo e não deve ser perdido.
      }
    }

    return PaymentProof(
      id: proofId,
      academyId: academyId,
      studentId: studentId,
      submittedBy: submittedBy,
      type: type,
      status: PaymentProofStatus.pending,
      billingCycleId: billingCycleId,
      attendanceId: attendanceId,
      storagePath: storagePath,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: bytes.length,
      paymentMethod: paymentMethod,
      referenceDate: referenceDate,
      submittedAt: null,
      reviewedAt: null,
      reviewedBy: null,
      rejectionReason: null,
    );
  }

  Future<List<PaymentProof>> getPaymentProofs({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
    PaymentProofStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _proofs(
      academyId,
    ).where('periodKey', isEqualTo: period.key);

    if (studentId != null && studentId.isNotEmpty) {
      query = query.where('studentId', isEqualTo: studentId);
    }

    final snapshot = await query.get();

    var proofs = snapshot.docs
        .map(
          (document) =>
              _proofFromDocument(academyId: academyId, document: document),
        )
        .toList();

    if (status != null) {
      proofs = proofs.where((proof) => proof.status == status).toList();
    }

    proofs.sort((a, b) => b.referenceDate.compareTo(a.referenceDate));

    return proofs;
  }

  Future<Uint8List> getPaymentProofBytes({required String storagePath}) {
    return storageService.getProofBytes(storagePath);
  }

  Future<void> reviewPaymentProof({
    required String academyId,
    required String proofId,
    required PaymentProofStatus status,
    required String reviewedBy,
    RevenueDestination? revenueDestination,
    String? rejectionReason,
  }) async {
    if (status == PaymentProofStatus.pending) {
      throw ArgumentError('A revisão deve aprovar ou rejeitar o comprovante.');
    }

    final normalizedReason = rejectionReason?.trim();

    if (status == PaymentProofStatus.rejected &&
        (normalizedReason == null || normalizedReason.isEmpty)) {
      throw ArgumentError('Informe o motivo da rejeição do comprovante.');
    }

    final proofReference = _proofs(academyId).doc(proofId);

    await firestore.runTransaction<void>((transaction) async {
      final proofDocument = await transaction.get(proofReference);
      final proofData = proofDocument.data();

      if (!proofDocument.exists || proofData == null) {
        throw StateError('O comprovante não foi encontrado.');
      }

      final currentStatus = FinanceFirestoreParser.enumValue(
        PaymentProofStatus.values,
        proofData['status'],
        PaymentProofStatus.pending,
      );

      if (currentStatus == PaymentProofStatus.approved &&
          status == PaymentProofStatus.rejected) {
        throw StateError(
          'Um comprovante aprovado não pode ser rejeitado diretamente.',
        );
      }

      final proofType = FinanceFirestoreParser.enumValue(
        PaymentProofType.values,
        proofData['type'],
        PaymentProofType.monthlyFee,
      );

      if (status == PaymentProofStatus.approved &&
          proofType == PaymentProofType.monthlyFee) {
        final billingCycleId = FinanceFirestoreParser.optionalString(
          proofData['billingCycleId'],
        );

        if (billingCycleId == null) {
          throw StateError('O comprovante não possui uma cobrança vinculada.');
        }

        final billingReference = _billingCycles(academyId).doc(billingCycleId);

        final billingDocument = await transaction.get(billingReference);

        final billingData = billingDocument.data();

        if (!billingDocument.exists || billingData == null) {
          throw StateError('A cobrança vinculada não foi encontrada.');
        }

        final existingProofId = FinanceFirestoreParser.optionalString(
          billingData['paymentProofId'],
        );

        if (billingData['status'] == BillingStatus.paid.name &&
            existingProofId != null &&
            existingProofId != proofId) {
          throw StateError('Esta cobrança já foi paga com outro comprovante.');
        }

        final expectedAmountCents = FinanceFirestoreParser.integer(
          billingData['expectedAmountCents'],
        );

        final paymentMethod =
            FinanceFirestoreParser.optionalEnumValue(
              PaymentMethod.values,
              proofData['paymentMethod'],
            ) ??
            PaymentMethod.other;

        transaction.update(billingReference, {
          'paidAmountCents': expectedAmountCents,
          'status': BillingStatus.paid.name,
          'paymentMethod': paymentMethod.name,
          'revenueDestination':
              (revenueDestination ?? RevenueDestination.movingFitness).name,
          'paymentProofId': proofId,
          'paidAt': FieldValue.serverTimestamp(),
          'paidBy': reviewedBy,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': reviewedBy,
        });
      }

      transaction.update(proofReference, {
        'status': status.name,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy,
        'rejectionReason': status == PaymentProofStatus.rejected
            ? normalizedReason
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  PaymentProof _proofFromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    return PaymentProof(
      id: document.id,
      academyId: academyId,
      studentId: FinanceFirestoreParser.string(data['studentId']),
      submittedBy: FinanceFirestoreParser.string(data['submittedBy']),
      type: FinanceFirestoreParser.enumValue(
        PaymentProofType.values,
        data['type'],
        PaymentProofType.monthlyFee,
      ),
      status: FinanceFirestoreParser.enumValue(
        PaymentProofStatus.values,
        data['status'],
        PaymentProofStatus.pending,
      ),
      billingCycleId: FinanceFirestoreParser.optionalString(
        data['billingCycleId'],
      ),
      attendanceId: FinanceFirestoreParser.optionalString(data['attendanceId']),
      checkInProviderId: FinanceFirestoreParser.optionalString(
        data['checkInProviderId'],
      ),
      storagePath: FinanceFirestoreParser.string(data['storagePath']),
      fileName: FinanceFirestoreParser.string(data['fileName']),
      contentType: FinanceFirestoreParser.string(data['contentType']),
      sizeBytes: FinanceFirestoreParser.integer(data['sizeBytes']),
      paymentMethod: FinanceFirestoreParser.optionalEnumValue(
        PaymentMethod.values,
        data['paymentMethod'],
      ),
      referenceDate: FinanceFirestoreParser.date(data['referenceDate']),
      submittedAt: FinanceFirestoreParser.optionalDate(data['submittedAt']),
      reviewedAt: FinanceFirestoreParser.optionalDate(data['reviewedAt']),
      reviewedBy: FinanceFirestoreParser.optionalString(data['reviewedBy']),
      rejectionReason: FinanceFirestoreParser.optionalString(
        data['rejectionReason'],
      ),
    );
  }

  String _normalizeCheckInProviderId(String? providerId) {
    final normalizedId = (providerId ?? 'gympass').trim();

    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(normalizedId)) {
      throw ArgumentError('O convênio de check-in é inválido.');
    }

    return normalizedId;
  }

  void _validateSubmission({
    required PaymentProofType type,
    required PaymentMethod paymentMethod,
    required String? billingCycleId,
    required String? attendanceId,
    required String? checkInProviderId,
  }) {
    if (type == PaymentProofType.gympassCheckIn) {
      if (checkInProviderId == null || checkInProviderId.isEmpty) {
        throw ArgumentError(
          'O comprovante de check-in precisa de um convênio válido.',
        );
      }

      if (attendanceId == null || attendanceId.trim().isEmpty) {
        throw ArgumentError(
          'O comprovante de check-in precisa de uma presença vinculada.',
        );
      }

      if (paymentMethod != PaymentMethod.gympass) {
        throw ArgumentError(
          'O comprovante deve usar a modalidade de convênio.',
        );
      }

      return;
    }

    if (billingCycleId == null || billingCycleId.trim().isEmpty) {
      throw ArgumentError('O comprovante precisa de uma cobrança vinculada.');
    }

    if (paymentMethod == PaymentMethod.gympass ||
        paymentMethod == PaymentMethod.cash) {
      throw ArgumentError('Selecione Pix, cartão ou transferência.');
    }
  }
}
