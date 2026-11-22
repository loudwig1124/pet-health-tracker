/// Storage formats for the SQLite columns. Everything here mirrors the DDL
/// header: date-only values are `YYYY-MM-DD`, instants are ISO-8601 UTC.
library;

String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// `DateTime` -> `YYYY-MM-DD`. Uses the calendar fields as given (a date picked
/// in the device zone keeps its day).
String encodeDate(DateTime value) =>
    '${_pad(value.year, 4)}-${_pad(value.month, 2)}-${_pad(value.day, 2)}';

/// `YYYY-MM-DD` -> UTC midnight on that calendar day.
DateTime decodeDate(String value) {
  final List<int> parts = value
      .split('-')
      .map((String part) => int.parse(part))
      .toList(growable: false);
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

/// `DateTime?` -> nullable `YYYY-MM-DD`.
String? encodeNullableDate(DateTime? value) =>
    value == null ? null : encodeDate(value);

/// Nullable `YYYY-MM-DD` -> `DateTime?`.
DateTime? decodeNullableDate(Object? value) =>
    value == null ? null : decodeDate(value as String);

/// `DateTime` -> ISO-8601 UTC with milliseconds, e.g. `2026-11-21T08:30:00.000Z`.
String encodeInstant(DateTime value) => value.toUtc().toIso8601String();

/// ISO-8601 -> UTC `DateTime`.
DateTime decodeInstant(Object? value) =>
    DateTime.parse(value! as String).toUtc();

/// SQLite REAL can surface as int; always read it as a double.
double decodeWeight(Object? value) => (value! as num).toDouble();

/// Trims user text and turns blank into null, so nullable TEXT columns store
/// NULL rather than an empty string.
String? trimToNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Trims user text for NOT NULL columns.
String trimRequired(String value) => value.trim();
