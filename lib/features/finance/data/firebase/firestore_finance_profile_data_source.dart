import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/finance_enums.dart';
import '../../models/finance_settings.dart';
import '../../models/financial_profile.dart';
import 'finance_firestore_parser.dart';

class FirestoreFinanceProfileDataSource {
  final FirebaseFirestore firestore;

  FirestoreFinanceProfileDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _settings(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('financialSettings')
        .doc('general');
  }

  CollectionReference<Map<String, dynamic>> _profiles(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('financialProfiles');
  }

  Future<FinanceSettings> getSettings({required String academyId}) async {
    final document = await _settings(academyId).get();
    final defaults = FinanceSettings.defaults(academyId: academyId);
    final data = document.data();

    if (!document.exists || data == null) {
      return defaults;
    }

    return FinanceSettings(
      academyId: academyId,
      gympassCheckInValueCents: FinanceFirestoreParser.integer(
        data['gympassCheckInValueCents'],
        fallback: defaults.gympassCheckInValueCents,
      ),
      gympassMonthlyLimit: FinanceFirestoreParser.integer(
        data['gympassMonthlyLimit'],
        fallback: defaults.gympassMonthlyLimit,
      ),
      movingFitnessPercentage: FinanceFirestoreParser.integer(
        data['movingFitnessPercentage'],
        fallback: defaults.movingFitnessPercentage,
      ),
      instructorName: FinanceFirestoreParser.string(
        data['instructorName'],
        fallback: defaults.instructorName,
      ),
      instructorFixedAmountCents: FinanceFirestoreParser.integer(
        data['instructorFixedAmountCents'],
        fallback: defaults.instructorFixedAmountCents,
      ),
      gracieBarraReservePercentage: FinanceFirestoreParser.integer(
        data['gracieBarraReservePercentage'],
        fallback: defaults.gracieBarraReservePercentage,
      ),
      remainingPartnersCount: FinanceFirestoreParser.integer(
        data['remainingPartnersCount'],
        fallback: defaults.remainingPartnersCount,
      ),
      updatedAt: FinanceFirestoreParser.optionalDate(data['updatedAt']),
      updatedBy: FinanceFirestoreParser.string(data['updatedBy']),
    );
  }

  Future<void> saveSettings({
    required FinanceSettings settings,
    required String updatedBy,
  }) {
    _validateSettings(settings);

    return _settings(settings.academyId).set({
      'gympassCheckInValueCents': settings.gympassCheckInValueCents,
      'gympassMonthlyLimit': settings.gympassMonthlyLimit,
      'movingFitnessPercentage': settings.movingFitnessPercentage,
      'instructorName': settings.instructorName.trim(),
      'instructorFixedAmountCents': settings.instructorFixedAmountCents,
      'gracieBarraReservePercentage': settings.gracieBarraReservePercentage,
      'remainingPartnersCount': settings.remainingPartnersCount,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Future<FinancialProfile?> getFinancialProfile({
    required String academyId,
    required String studentId,
  }) async {
    final document = await _profiles(academyId).doc(studentId).get();
    final data = document.data();

    if (!document.exists || data == null) {
      return null;
    }

    return _profileFromDocument(academyId: academyId, document: document);
  }

  Future<List<FinancialProfile>> getFinancialProfiles({
    required String academyId,
  }) async {
    final snapshot = await _profiles(academyId).get();

    final profiles = snapshot.docs
        .map(
          (document) =>
              _profileFromDocument(academyId: academyId, document: document),
        )
        .toList();

    profiles.sort((a, b) => a.studentId.compareTo(b.studentId));

    return profiles;
  }

  Future<void> saveFinancialProfile({required FinancialProfile profile}) {
    if (profile.monthlyFeeCents < 0) {
      throw ArgumentError('O valor da mensalidade não pode ser negativo.');
    }

    if (profile.dueDay < 1 || profile.dueDay > 31) {
      throw ArgumentError('O vencimento deve estar entre os dias 1 e 31.');
    }

    return _profiles(profile.academyId).doc(profile.studentId).set({
      'studentId': profile.studentId,
      'billingMode': profile.billingMode.name,
      'monthlyFeeCents': profile.monthlyFeeCents,
      'dueDay': profile.dueDay,
      'isActive': profile.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': profile.updatedBy,
    }, SetOptions(merge: true));
  }

  FinancialProfile _profileFromDocument({
    required String academyId,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data()!;

    return FinancialProfile(
      academyId: academyId,
      studentId: document.id,
      billingMode: FinanceFirestoreParser.enumValue(
        BillingMode.values,
        data['billingMode'],
        BillingMode.monthlyFee,
      ),
      monthlyFeeCents: FinanceFirestoreParser.integer(data['monthlyFeeCents']),
      dueDay: FinanceFirestoreParser.integer(data['dueDay'], fallback: 1),
      isActive: FinanceFirestoreParser.boolean(
        data['isActive'],
        fallback: true,
      ),
      updatedAt: FinanceFirestoreParser.optionalDate(data['updatedAt']),
      updatedBy: FinanceFirestoreParser.string(data['updatedBy']),
    );
  }

  void _validateSettings(FinanceSettings settings) {
    if (settings.gympassCheckInValueCents < 0 ||
        settings.gympassMonthlyLimit < 1 ||
        settings.instructorFixedAmountCents < 0 ||
        settings.remainingPartnersCount < 1) {
      throw ArgumentError('As configurações financeiras são inválidas.');
    }

    if (settings.movingFitnessPercentage < 0 ||
        settings.movingFitnessPercentage > 100 ||
        settings.gracieBarraReservePercentage < 0 ||
        settings.gracieBarraReservePercentage > 100) {
      throw ArgumentError('Os percentuais devem estar entre 0 e 100.');
    }

    if (settings.instructorName.trim().isEmpty) {
      throw ArgumentError('Informe o nome do professor.');
    }
  }
}
