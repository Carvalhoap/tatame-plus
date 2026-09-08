import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/billing_cycle.dart';
import '../../models/finance_enums.dart';
import '../../models/finance_period.dart';
import 'finance_firestore_parser.dart';
import 'firestore_finance_profile_data_source.dart';

class FirestoreBillingDataSource {
  final FirebaseFirestore firestore;
  final FirestoreFinanceProfileDataSource profileDataSource;

  FirestoreBillingDataSource({
    FirebaseFirestore? firestore,
    FirestoreFinanceProfileDataSource? profileDataSource,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       profileDataSource =
           profileDataSource ??
           FirestoreFinanceProfileDataSource(firestore: firestore);

  CollectionReference<Map<String, dynamic>> _billingCycles(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('billingCycles');
  }

  Future<BillingCycle> getOrCreateBillingCycle({
    required String academyId,
    required String studentId,
    required FinancePeriod period,
    required String createdBy,
  }) async {
    final reference = _billingCycles(academyId).doc('${period.key}_$studentId');

    final profile = await profileDataSource.getFinancialProfile(
      academyId: academyId,
      studentId: studentId,
    );

    if (profile == null || !profile.isActive) {
      throw StateError('O aluno não possui um perfil financeiro ativo.');
    }

    final expectedAmountCents = profile.billingMode == BillingMode.monthlyFee
        ? profile.monthlyFeeCents
        : 0;

    final dueDate = period.dueDateForDay(profile.dueDay);

    final initialStatus = profile.billingMode == BillingMode.exempt
        ? BillingStatus.waived
        : BillingStatus.pending;

    return firestore.runTransaction<BillingCycle>((transaction) async {
      final existingDocument = await transaction.get(reference);

      if (existingDocument.exists && existingDocument.data() != null) {
        return _cycleFromDocument(
          academyId: academyId,
          document: existingDocument,
        );
      }

      transaction.set(reference, {
        'studentId': studentId,
        'periodKey': period.key,
        'periodStart': Timestamp.fromDate(period.start),
        'periodEndExclusive': Timestamp.fromDate(period.endExclusive),
        'billingMode': profile.billingMode.name,
        'expectedAmountCents': expectedAmountCents,
        'paidAmountCents': 0,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': initialStatus.name,
        'paymentMethod': null,
        'paymentProofId': null,
        'paidAt': null,
        'paidBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': createdBy,
      });

      return BillingCycle(
        id: reference.id,
        academyId: academyId,
        studentId: studentId,
        period: period,
        billingMode: profile.billingMode,
        expectedAmountCents: expectedAmountCents,
        paidAmountCents: 0,
        dueDate: dueDate,
        status: initialStatus,
        paymentMethod: null,
        paymentProofId: null,
        paidAt: null,
        createdAt: null,
        updatedAt: null,
      );
    });
  }

  Future<List<BillingCycle>> getBillingCycles({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  }) async {
    if (studentId != null && studentId.isNotEmpty) {
      final document = await _billingCycles(
        academyId,
      ).doc('${period.key}_$studentId').get();

      if (!document.exists || document.data() == null) {
        return const [];
      }

      return [_cycleFromDocument(academyId: academyId, document: document)];
    }

    final snapshot = await _billingCycles(
      academyId,
    ).where('periodKey', isEqualTo: period.key).get();

    final cycles = snapshot.docs
        .map(
          (document) =>
              _cycleFromDocument(academyId: academyId, document: document),
        )
        .toList();

    cycles.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return cycles;
  }

  Future<void> markBillingCyclePaid({
    required String academyId,
    required String billingCycleId,
    required int amountCents,
    required PaymentMethod paymentMethod,
    required String paidBy,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('O valor pago deve ser maior que zero.');
    }

    final reference = _billingCycles(academyId).doc(billingCycleId);

    await firestore.runTransaction<void>((transaction) async {
      final document = await transaction.get(reference);
      final data = document.data();

      if (!document.exists || data == null) {
        throw StateError('A cobrança não foi encontrada.');
      }

      final billingMode = FinanceFirestoreParser.enumValue(
        BillingMode.values,
        data['billingMode'],
        BillingMode.monthlyFee,
      );

      if (billingMode != BillingMode.monthlyFee) {
        throw StateError(
          'Somente mensalidades podem ser baixadas manualmente.',
        );
      }

      transaction.update(reference, {
        'paidAmountCents': amountCents,
        'status': BillingStatus.paid.name,
        'paymentMethod': paymentMethod.name,
        'paidAt': FieldValue.serverTimestamp(),
        'paidBy': paidBy,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': paidBy,
      });
    });
  }

  BillingCycle _cycleFromDocument({
    required String academyId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data()!;
    final dueDate = FinanceFirestoreParser.date(data['dueDate']);

    var status = FinanceFirestoreParser.enumValue(
      BillingStatus.values,
      data['status'],
      BillingStatus.pending,
    );

    final dayAfterDueDate = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day + 1,
    );

    if (status == BillingStatus.pending &&
        DateTime.now().isAfter(dayAfterDueDate)) {
      status = BillingStatus.overdue;
    }

    return BillingCycle(
      id: document.id,
      academyId: academyId,
      studentId: FinanceFirestoreParser.string(data['studentId']),
      period: FinancePeriod(
        start: FinanceFirestoreParser.date(data['periodStart']),
        endExclusive: FinanceFirestoreParser.date(data['periodEndExclusive']),
      ),
      billingMode: FinanceFirestoreParser.enumValue(
        BillingMode.values,
        data['billingMode'],
        BillingMode.monthlyFee,
      ),
      expectedAmountCents: FinanceFirestoreParser.integer(
        data['expectedAmountCents'],
      ),
      paidAmountCents: FinanceFirestoreParser.integer(data['paidAmountCents']),
      dueDate: dueDate,
      status: status,
      paymentMethod: FinanceFirestoreParser.optionalEnumValue(
        PaymentMethod.values,
        data['paymentMethod'],
      ),
      paymentProofId: FinanceFirestoreParser.optionalString(
        data['paymentProofId'],
      ),
      paidAt: FinanceFirestoreParser.optionalDate(data['paidAt']),
      createdAt: FinanceFirestoreParser.optionalDate(data['createdAt']),
      updatedAt: FinanceFirestoreParser.optionalDate(data['updatedAt']),
    );
  }
}
