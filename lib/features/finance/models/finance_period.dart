import 'dart:math' as math;

class FinancePeriod {
  final DateTime start;
  final DateTime endExclusive;

  const FinancePeriod({required this.start, required this.endExclusive});

  factory FinancePeriod.fromReference({required int year, required int month}) {
    return FinancePeriod(
      start: DateTime(year, month, 15),
      endExclusive: DateTime(year, month + 1, 15),
    );
  }

  factory FinancePeriod.containing(DateTime date) {
    final start = date.day >= 15
        ? DateTime(date.year, date.month, 15)
        : DateTime(date.year, date.month - 1, 15);

    return FinancePeriod(
      start: start,
      endExclusive: DateTime(start.year, start.month + 1, 15),
    );
  }

  int get referenceYear => start.year;

  int get referenceMonth => start.month;

  DateTime get displayEnd {
    return endExclusive.subtract(const Duration(days: 1));
  }

  String get key {
    final year = referenceYear.toString().padLeft(4, '0');
    final month = referenceMonth.toString().padLeft(2, '0');

    return '$year-$month';
  }

  bool contains(DateTime date) {
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  DateTime dueDateForDay(int dueDay) {
    if (dueDay < 1 || dueDay > 31) {
      throw ArgumentError.value(
        dueDay,
        'dueDay',
        'O dia do vencimento deve estar entre 1 e 31.',
      );
    }

    final dueYear = dueDay >= 15 ? start.year : endExclusive.year;
    final dueMonth = dueDay >= 15 ? start.month : endExclusive.month;
    final lastDay = DateTime(dueYear, dueMonth + 1, 0).day;
    final adjustedDay = math.min(dueDay, lastDay);

    return DateTime(dueYear, dueMonth, adjustedDay);
  }
}
