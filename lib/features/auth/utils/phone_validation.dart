/// Phone number validation utilities for E.164 format compliance.
/// E.164 is the international standard for phone numbers required by Supabase.
/// Format: +[1-9][0-9]{0,14} (+ followed by 1-15 digits, first digit 1-9)

/// Validates a phone number against E.164 format.
///
/// E.164 format requirements:
/// - Starts with `+`
/// - Followed by 1-15 digits
/// - First digit after `+` must be 1-9 (no leading zero)
/// - No spaces, dashes, parentheses, or other characters
///
/// Examples:
/// - `+15555550100` → true
/// - `+447911123456` → true
/// - `555-555-0100` → false (missing country code)
/// - `+0123` → false (leading zero after +)
/// - `+1234567890123456789` → false (too long)
bool isValidE164(String phone) {
  final e164Regex = RegExp(r'^\+[1-9]\d{0,14}$');
  return e164Regex.hasMatch(phone);
}

/// Normalizes a phone number by removing common formatting characters.
///
/// Attempts to convert a formatted phone number to E.164 format.
/// Removes spaces, dashes, parentheses, and dots.
///
/// Returns:
/// - E.164 formatted string if normalization succeeds
/// - null if the input cannot be normalized to E.164 (e.g., missing country code)
///
/// Examples:
/// - `+1 555 555 0100` → `+15555550100`
/// - `+1-555-555-0100` → `+15555550100`
/// - `+1(555)555-0100` → `+15555550100`
/// - `5555550100` → null (no country code, unrecoverable)
/// - `` (empty) → null
/// - `abc` → null
String? normalizePhone(String input) {
  if (input.isEmpty) {
    return null;
  }

  // Remove common formatting characters: spaces, dashes, parentheses, dots
  final normalized = input.replaceAll(RegExp(r'[\s\-().]'), '');

  if (normalized.isEmpty) {
    return null;
  }

  // If it starts with +, validate as E.164
  if (normalized.startsWith('+')) {
    if (isValidE164(normalized)) {
      return normalized;
    }
    return null;
  }

  // If it's only digits (no +), we can't recover the country code
  if (RegExp(r'^\d+$').hasMatch(normalized)) {
    return null;
  }

  // Contains letters or other invalid characters
  return null;
}
