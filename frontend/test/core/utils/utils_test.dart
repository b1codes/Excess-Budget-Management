import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/json_parsing.dart';
import 'package:frontend/core/utils/optional.dart';
import 'package:frontend/core/utils/validation_utils.dart';

void main() {
  group('parseAmount', () {
    test('accepts JSON numbers and numeric strings', () {
      expect(parseAmount(5), 5.0);
      expect(parseAmount(5.25), 5.25);
      expect(parseAmount('100.00'), 100.0);
      expect(parseAmount('-3.5'), -3.5);
    });

    test('rejects null, non-numeric strings and other types', () {
      expect(() => parseAmount(null), throwsFormatException);
      expect(() => parseAmount('abc'), throwsFormatException);
      expect(() => parseAmount(true), throwsFormatException);
      expect(
        () => parseAmount(const <String, dynamic>{}),
        throwsFormatException,
      );
    });
  });

  group('parseAmountOrNull', () {
    test('returns null for null and parses everything parseAmount does', () {
      expect(parseAmountOrNull(null), isNull);
      expect(parseAmountOrNull('1.50'), 1.5);
      expect(parseAmountOrNull(2), 2.0);
    });

    test('still rejects garbage instead of hiding it as null', () {
      expect(() => parseAmountOrNull('1,000'), throwsFormatException);
      expect(() => parseAmountOrNull([1]), throwsFormatException);
    });
  });

  group('ValidationUtils.validateAmount', () {
    test('requires a value', () {
      expect(ValidationUtils.validateAmount(null), 'Amount is required');
      expect(ValidationUtils.validateAmount(''), 'Amount is required');
    });

    test('requires a number', () {
      expect(
        ValidationUtils.validateAmount('abc'),
        'Please enter a valid number',
      );
    });

    test('requires a positive amount', () {
      expect(
        ValidationUtils.validateAmount('0'),
        'Amount must be greater than zero',
      );
      expect(
        ValidationUtils.validateAmount('-5'),
        'Amount must be greater than zero',
      );
    });

    test('allows at most two decimal places', () {
      expect(ValidationUtils.validateAmount('1.5'), isNull);
      expect(ValidationUtils.validateAmount('1.50'), isNull);
      expect(
        ValidationUtils.validateAmount('1.505'),
        'Maximum 2 decimal places allowed',
      );
    });

    test('accepts whole numbers', () {
      expect(ValidationUtils.validateAmount('100'), isNull);
    });
  });

  group('ValidationUtils.validateRequired', () {
    test('rejects null, empty and whitespace-only values', () {
      for (final v in [null, '', '   ']) {
        expect(ValidationUtils.validateRequired(v, 'Name'), 'Name is required');
      }
    });

    test('accepts any non-blank value', () {
      expect(ValidationUtils.validateRequired(' x ', 'Name'), isNull);
    });
  });

  group('ValidationUtils.validateSelection', () {
    test('requires a selection', () {
      expect(
        ValidationUtils.validateSelection(null, 'category'),
        'Please select a category',
      );
      expect(ValidationUtils.validateSelection('cat-1', 'category'), isNull);
    });
  });

  test('Wrapped distinguishes "explicitly null" from "not provided"', () {
    const explicitNull = Wrapped<String?>(null);
    Wrapped<String?>? notProvided;
    expect(explicitNull.value, isNull);
    expect(notProvided, isNull);
    expect(const Wrapped<int>(3).value, 3);
  });
}
