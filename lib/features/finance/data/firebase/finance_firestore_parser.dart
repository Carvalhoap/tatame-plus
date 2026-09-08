import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceFirestoreParser {
  const FinanceFirestoreParser._();

  static int integer(dynamic value, {int fallback = 0}) {
    return value is num ? value.toInt() : fallback;
  }

  static String string(dynamic value, {String fallback = ''}) {
    return value is String ? value : fallback;
  }

  static String? optionalString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    return value is bool ? value : fallback;
  }

  static DateTime date(dynamic value, {DateTime? fallback}) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? optionalDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static T enumValue<T extends Enum>(
    Iterable<T> values,
    dynamic rawValue,
    T fallback,
  ) {
    if (rawValue is String) {
      for (final value in values) {
        if (value.name == rawValue) {
          return value;
        }
      }
    }

    return fallback;
  }

  static T? optionalEnumValue<T extends Enum>(
    Iterable<T> values,
    dynamic rawValue,
  ) {
    if (rawValue is String) {
      for (final value in values) {
        if (value.name == rawValue) {
          return value;
        }
      }
    }

    return null;
  }
}
