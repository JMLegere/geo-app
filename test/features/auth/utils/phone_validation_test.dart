import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/utils/phone_validation.dart';

void main() {
  group('isValidE164', () {
    test('accepts valid E.164 numbers with various country codes', () {
      expect(isValidE164('+15555550100'), isTrue);
      expect(isValidE164('+447911123456'), isTrue);
      expect(isValidE164('+33123456789'), isTrue);
      expect(isValidE164('+81312345678'), isTrue);
      expect(isValidE164('+1'), isTrue); // Minimum: + and 1 digit
    });

    test('accepts E.164 numbers with maximum length (15 digits)', () {
      expect(isValidE164('+123456789012345'), isTrue); // 15 digits
    });

    test('rejects E.164 numbers exceeding 15 digits', () {
      expect(isValidE164('+1234567890123456'), isFalse); // 16 digits
      expect(isValidE164('+1234567890123456789'), isFalse); // 19 digits
    });

    test('rejects numbers without + prefix', () {
      expect(isValidE164('15555550100'), isFalse);
      expect(isValidE164('447911123456'), isFalse);
    });

    test('rejects numbers with leading zero after +', () {
      expect(isValidE164('+0123'), isFalse);
      expect(isValidE164('+01234567890'), isFalse);
    });

    test('rejects + alone', () {
      expect(isValidE164('+'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidE164(''), isFalse);
    });

    test('rejects numbers with spaces', () {
      expect(isValidE164('+1 555 555 0100'), isFalse);
      expect(isValidE164('+ 1 555 555 0100'), isFalse);
    });

    test('rejects numbers with dashes', () {
      expect(isValidE164('+1-555-555-0100'), isFalse);
    });

    test('rejects numbers with parentheses', () {
      expect(isValidE164('+1(555)555-0100'), isFalse);
    });

    test('rejects numbers with letters', () {
      expect(isValidE164('+1555abc0100'), isFalse);
      expect(isValidE164('+abc'), isFalse);
    });

    test('rejects numbers with special characters', () {
      expect(isValidE164('+1.555.555.0100'), isFalse);
      expect(isValidE164('+1#555#555#0100'), isFalse);
    });
  });

  group('normalizePhone', () {
    test('normalizes valid numbers with space formatting', () {
      expect(normalizePhone('+1 555 555 0100'), equals('+15555550100'));
      expect(normalizePhone('+44 7911 123456'), equals('+447911123456'));
    });

    test('normalizes valid numbers with dash formatting', () {
      expect(normalizePhone('+1-555-555-0100'), equals('+15555550100'));
      expect(normalizePhone('+33-1-23-45-67-89'), equals('+33123456789'));
    });

    test('normalizes valid numbers with parentheses formatting', () {
      expect(normalizePhone('+1(555)555-0100'), equals('+15555550100'));
      expect(normalizePhone('+1 (555) 555-0100'), equals('+15555550100'));
    });

    test('normalizes valid numbers with dot formatting', () {
      expect(normalizePhone('+1.555.555.0100'), equals('+15555550100'));
    });

    test('normalizes valid numbers with mixed formatting', () {
      expect(normalizePhone('+1 (555) 555-0100'), equals('+15555550100'));
      expect(normalizePhone('+44 7911 123456'), equals('+447911123456'));
    });

    test('returns already-normalized E.164 numbers unchanged', () {
      expect(normalizePhone('+15555550100'), equals('+15555550100'));
      expect(normalizePhone('+447911123456'), equals('+447911123456'));
    });

    test('returns null for numbers without country code', () {
      expect(normalizePhone('5555550100'), isNull);
      expect(normalizePhone('555-555-0100'), isNull);
      expect(normalizePhone('(555) 555-0100'), isNull);
    });

    test('returns null for empty string', () {
      expect(normalizePhone(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(normalizePhone('   '), isNull);
      expect(normalizePhone('\t\n'), isNull);
    });

    test('returns null for letters-only input', () {
      expect(normalizePhone('abc'), isNull);
      expect(normalizePhone('phone'), isNull);
    });

    test('returns null for input with letters and numbers', () {
      expect(normalizePhone('555abc0100'), isNull);
      expect(normalizePhone('+1abc555'), isNull);
    });

    test('returns null for + with invalid format after normalization', () {
      expect(normalizePhone('+0 555 555 0100'), isNull); // Leading zero
      expect(normalizePhone('+'), isNull); // + alone
    });

    test('returns null for numbers exceeding 15 digits after normalization',
        () {
      expect(normalizePhone('+1 234 567 890 123 456'), isNull); // 16 digits
    });

    test('handles leading/trailing whitespace', () {
      expect(normalizePhone('  +1 555 555 0100  '), equals('+15555550100'));
      expect(normalizePhone('\t+1 555 555 0100\n'), equals('+15555550100'));
    });
  });
}
