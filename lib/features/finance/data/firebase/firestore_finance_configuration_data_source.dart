import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/check_in_provider.dart';
import '../../models/recurring_expense.dart';
import 'finance_firestore_parser.dart';
import 'firestore_finance_profile_data_source.dart';

class FirestoreFinanceConfigurationDataSource {
  final FirebaseFirestore firestore;
  final FirestoreFinanceProfileDataSource profileDataSource;

  FirestoreFinanceConfigurationDataSource({
    FirebaseFirestore? firestore,
    FirestoreFinanceProfileDataSource? profileDataSource,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       profileDataSource =
           profileDataSource ??
           FirestoreFinanceProfileDataSource(firestore: firestore);

  CollectionReference<Map<String, dynamic>> _providers(String academyId) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('checkInProviders');
  }

  CollectionReference<Map<String, dynamic>> _recurringExpenses(
    String academyId,
  ) {
    return firestore
        .collection('academies')
        .doc(academyId)
        .collection('recurringExpenses');
  }

  Future<List<CheckInProvider>> getCheckInProviders({
    required String academyId,
  }) async {
    final snapshot = await _providers(academyId).get();

    final providers = snapshot.docs.map((document) {
      final data = document.data();

      return CheckInProvider(
        id: document.id,
        academyId: academyId,
        name: FinanceFirestoreParser.string(data['name']),
        checkInValueCents: FinanceFirestoreParser.integer(
          data['checkInValueCents'],
        ),
        monthlyLimit: FinanceFirestoreParser.integer(
          data['monthlyLimit'],
          fallback: 1,
        ),
        sharesWithMoving: FinanceFirestoreParser.boolean(
          data['sharesWithMoving'],
          fallback: true,
        ),
        isActive: FinanceFirestoreParser.boolean(
          data['isActive'],
          fallback: true,
        ),
        updatedAt: FinanceFirestoreParser.optionalDate(data['updatedAt']),
        updatedBy: FinanceFirestoreParser.string(data['updatedBy']),
      );
    }).toList();

    final hasGympass = providers.any(
      (provider) =>
          provider.id.toLowerCase() == 'gympass' ||
          provider.name.trim().toLowerCase() == 'gympass',
    );

    if (!hasGympass) {
      final settings = await profileDataSource.getSettings(
        academyId: academyId,
      );

      providers.add(
        CheckInProvider(
          id: 'gympass',
          academyId: academyId,
          name: 'Gympass',
          checkInValueCents: settings.gympassCheckInValueCents,
          monthlyLimit: settings.gympassMonthlyLimit,
          sharesWithMoving: true,
          isActive: true,
          updatedAt: settings.updatedAt,
          updatedBy: settings.updatedBy,
        ),
      );
    }

    providers.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return providers;
  }

  Future<String> saveCheckInProvider({
    required CheckInProvider provider,
    required String updatedBy,
  }) async {
    final name = provider.name.trim();

    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Informe um nome válido para o convênio.');
    }

    if (provider.checkInValueCents < 0) {
      throw ArgumentError('O valor do check-in não pode ser negativo.');
    }

    if (provider.monthlyLimit < 1) {
      throw ArgumentError('O limite mensal deve ser maior que zero.');
    }

    if (updatedBy.trim().isEmpty) {
      throw ArgumentError('O usuário responsável não foi informado.');
    }

    final normalizedId = provider.id.trim();

    final reference = normalizedId.isEmpty
        ? _providers(provider.academyId).doc()
        : _providers(provider.academyId).doc(normalizedId);

    await reference.set({
      'name': name,
      'checkInValueCents': provider.checkInValueCents,
      'monthlyLimit': provider.monthlyLimit,
      'sharesWithMoving': provider.sharesWithMoving,
      'isActive': provider.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));

    return reference.id;
  }

  Future<List<RecurringExpense>> getRecurringExpenses({
    required String academyId,
  }) async {
    final snapshot = await _recurringExpenses(academyId).get();

    final expenses = snapshot.docs.map((document) {
      final data = document.data();

      return RecurringExpense(
        id: document.id,
        academyId: academyId,
        category: FinanceFirestoreParser.string(data['category']),
        description: FinanceFirestoreParser.string(data['description']),
        amountCents: FinanceFirestoreParser.integer(data['amountCents']),
        isActive: FinanceFirestoreParser.boolean(
          data['isActive'],
          fallback: true,
        ),
        updatedAt: FinanceFirestoreParser.optionalDate(data['updatedAt']),
        updatedBy: FinanceFirestoreParser.string(data['updatedBy']),
      );
    }).toList();

    final settings = await profileDataSource.getSettings(academyId: academyId);

    final instructorName = settings.instructorName.trim().toLowerCase();

    final hasLegacyInstructor = expenses.any(
      (expense) =>
          expense.id == 'professor_wagner' ||
          expense.description.trim().toLowerCase() == instructorName,
    );

    if (!hasLegacyInstructor) {
      expenses.add(
        RecurringExpense(
          id: 'professor_wagner',
          academyId: academyId,
          category: 'Professores',
          description: settings.instructorName,
          amountCents: settings.instructorFixedAmountCents,
          isActive: true,
          updatedAt: settings.updatedAt,
          updatedBy: settings.updatedBy,
        ),
      );
    }

    expenses.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.description.toLowerCase().compareTo(
        second.description.toLowerCase(),
      );
    });

    return expenses;
  }

  Future<String> saveRecurringExpense({
    required RecurringExpense expense,
    required String updatedBy,
  }) async {
    final category = expense.category.trim();
    final description = expense.description.trim();

    if (category.isEmpty || category.length > 100) {
      throw ArgumentError('Informe uma categoria válida.');
    }

    if (description.isEmpty || description.length > 200) {
      throw ArgumentError('Informe uma descrição válida.');
    }

    if (expense.amountCents < 0) {
      throw ArgumentError('O valor da despesa não pode ser negativo.');
    }

    if (updatedBy.trim().isEmpty) {
      throw ArgumentError('O usuário responsável não foi informado.');
    }

    final normalizedId = expense.id.trim();

    final reference = normalizedId.isEmpty
        ? _recurringExpenses(expense.academyId).doc()
        : _recurringExpenses(expense.academyId).doc(normalizedId);

    await reference.set({
      'category': category,
      'description': description,
      'amountCents': expense.amountCents,
      'isActive': expense.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));

    return reference.id;
  }
}
