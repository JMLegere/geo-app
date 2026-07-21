import 'dart:convert';

final class IdentificationWireValidation {
  const IdentificationWireValidation._();

  static Map<String, dynamic> object(
    Object? value,
    Set<String> keys,
  ) {
    if (value is! Map) _invalid();
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) _invalid();
      result[entry.key as String] = entry.value;
    }
    if (result.length != keys.length ||
        !result.keys.toSet().containsAll(keys)) {
      _invalid();
    }
    return result;
  }

  static List<dynamic> array(Object? value) {
    if (value is! List) _invalid();
    return List<dynamic>.unmodifiable(value);
  }

  static String string(Object? value) {
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      _invalid();
    }
    return value;
  }

  static String uuid(Object? value) {
    final result = string(value);
    if (!_uuidExpression.hasMatch(result)) _invalid();
    return result;
  }

  static int positiveInt(Object? value) {
    if (value is! int || value <= 0) _invalid();
    return value;
  }

  static int ordinal(Object? value, int expected) {
    if (value is! int || value != expected) _invalid();
    return value;
  }

  static double positiveWeight(Object? value) {
    if (value is! num) _invalid();
    final result = value.toDouble();
    if (!result.isFinite || result <= 0) _invalid();
    return result;
  }

  static DateTime timestamp(Object? value) {
    if (value is! String || !_timestampExpression.hasMatch(value)) _invalid();
    final result = DateTime.tryParse(value);
    if (result == null) _invalid();
    return result;
  }

  static void nullableString(Object? value) {
    if (value != null && value is! String) _invalid();
  }

  static void nullableUuid(Object? value) {
    if (value != null) uuid(value);
  }

  static void jsonStringArray(Object? value) {
    if (value is! String) _invalid();
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List || decoded.any((entry) => entry is! String)) {
        _invalid();
      }
    } on FormatException {
      _invalid();
    }
  }

  static Never invalid() => _invalid();

  static Never _invalid() =>
      throw StateError('Invalid Item Identification response.');
}

final _uuidExpression = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
final _timestampExpression = RegExp(
  r'^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:\d{2})$',
);
