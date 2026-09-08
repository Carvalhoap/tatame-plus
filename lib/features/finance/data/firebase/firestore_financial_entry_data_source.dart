import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/finance_enums.dart';
import '../../models/finance_period.dart';
import '../../models/financial_entry.dart';
import 'finance_firestore_parser.dart';

class FirestoreFinancialEntryDataSource {
  final FirebaseFirestore firestore;

  FirestoreFinancialEntryDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _entries(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('financialEntries');
  }

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
  }) async {
    final normalizedCategory = category.trim();
    final normalizedDescription = description.trim();
    final normalizedStudentId = studentId?.trim();

    if (normalizedCategory.isEmpty) {
      throw ArgumentError('Informe a categoria do lançamento.');
    }

    if (normalizedDescription.isEmpty) {
      throw ArgumentError('Informe a descrição do lançamento.');
    }

    if (amountCents <= 0) {
      throw ArgumentError('O valor deve ser maior que zero.');
    }

    final reference = _entries(academyId).doc();
    final period = FinancePeriod.containing(occurredAt);

    await reference.set({
      'studentId': normalizedStudentId == null || normalizedStudentId.isEmpty
          ? null
          : normalizedStudentId,
      'type': type.name,
      'category': normalizedCategory,
      'description': normalizedDescription,
      'amountCents': amountCents,
      'paymentMethod': paymentMethod?.name,
      'periodKey': period.key,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isCancelled': false,
      'cancelledBy': null,
      'cancelledAt': null,
    });

    return reference.id;
  }

  Future<List<FinancialEntry>> getFinancialEntries({
    required String academyId,
    required FinancePeriod period,
    String? studentId,
  }) async {
    Query<Map<String, dynamic>> query = _entries(
      academyId,
    ).where('periodKey', isEqualTo: period.key);

    if (studentId != null && studentId.isNotEmpty) {
      query = query.where('studentId', isEqualTo: studentId);
    }

    final snapshot = await query.get();

    final entries = snapshot.docs
        .map(
          (document) =>
              _entryFromDocument(academyId: academyId, document: document),
        )
        .toList();

    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return entries;
  }

  Future<void> cancelFinancialEntry({
    required String academyId,
    required String entryId,
    required String cancelledBy,
  }) async {
    final reference = _entries(academyId).doc(entryId);

    await firestore.runTransaction<void>((transaction) async {
      final document = await transaction.get(reference);
      final data = document.data();

      if (!document.exists || data == null) {
        throw StateError('O lançamento financeiro não foi encontrado.');
      }

      if (data['isCancelled'] == true) {
        throw StateError('Este lançamento já foi cancelado.');
      }

      transaction.update(reference, {
        'isCancelled': true,
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  FinancialEntry _entryFromDocument({
    required String academyId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();

    return FinancialEntry(
      id: document.id,
      academyId: academyId,
      studentId: FinanceFirestoreParser.optionalString(data['studentId']),
      type: FinanceFirestoreParser.enumValue(
        FinancialEntryType.values,
        data['type'],
        FinancialEntryType.income,
      ),
      category: FinanceFirestoreParser.string(data['category']),
      description: FinanceFirestoreParser.string(data['description']),
      amountCents: FinanceFirestoreParser.integer(data['amountCents']),
      paymentMethod: FinanceFirestoreParser.optionalEnumValue(
        PaymentMethod.values,
        data['paymentMethod'],
      ),
      occurredAt: FinanceFirestoreParser.date(data['occurredAt']),
      createdBy: FinanceFirestoreParser.string(data['createdBy']),
      createdAt: FinanceFirestoreParser.optionalDate(data['createdAt']),
      isCancelled: FinanceFirestoreParser.boolean(data['isCancelled']),
      cancelledBy: FinanceFirestoreParser.optionalString(data['cancelledBy']),
      cancelledAt: FinanceFirestoreParser.optionalDate(data['cancelledAt']),
    );
  }
}
