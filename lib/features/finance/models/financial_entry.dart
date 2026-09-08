import 'finance_enums.dart';

class FinancialEntry {
  final String id;
  final String academyId;
  final String? studentId;
  final FinancialEntryType type;
  final String category;
  final String description;
  final int amountCents;
  final PaymentMethod? paymentMethod;
  final DateTime occurredAt;
  final String createdBy;
  final DateTime? createdAt;
  final bool isCancelled;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  const FinancialEntry({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.type,
    required this.category,
    required this.description,
    required this.amountCents,
    required this.paymentMethod,
    required this.occurredAt,
    required this.createdBy,
    required this.createdAt,
    required this.isCancelled,
    required this.cancelledBy,
    required this.cancelledAt,
  });

  double get amount => amountCents / 100;

  bool get isIncome => type == FinancialEntryType.income;

  bool get isExpense => type == FinancialEntryType.expense;

  bool get isActive => !isCancelled;

  bool get isLinkedToStudent => studentId != null && studentId!.isNotEmpty;
}
