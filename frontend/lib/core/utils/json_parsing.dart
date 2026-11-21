/// Helpers for reading values out of API JSON.
///
/// The backend serialises money (Python `Decimal`) as strings such as
/// `"100.00"`, while other numbers arrive as JSON numbers. These helpers accept
/// either so models don't break when a field switches between the two.
library;

/// Reads a required number that may be a JSON number or a numeric string.
///
/// Throws a [FormatException] for anything else, including `null`.
double parseAmount(Object? value) {
  final parsed = parseAmountOrNull(value);
  if (parsed == null) {
    throw FormatException('Expected a number or numeric string', value);
  }
  return parsed;
}

/// Like [parseAmount], but returns `null` for `null`.
///
/// Throws a [FormatException] for a non-numeric value, so bad data is still
/// reported rather than silently dropped.
double? parseAmountOrNull(Object? value) {
  return switch (value) {
    null => null,
    num() => value.toDouble(),
    String() =>
      double.tryParse(value) ??
          (throw FormatException('Expected a numeric string', value)),
    _ => throw FormatException('Expected a number or numeric string', value),
  };
}
