import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    // ── phoneNumber field ──────────────────────────────────────────────────

    test('UserProfile stores phoneNumber', () {
      final profile = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile.phoneNumber, '+15551234567');
    });

    test('UserProfile phoneNumber defaults to null', () {
      final profile = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile.phoneNumber, isNull);
    });

    // ── copyWith ─────────────────────────────────────────────────────────────

    test('copyWith preserves phoneNumber', () {
      final profile = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = profile.copyWith(displayName: 'Bob');

      expect(updated.phoneNumber, '+15551234567');
      expect(updated.displayName, 'Bob');
    });

    test('copyWith overrides phoneNumber', () {
      final profile = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        createdAt: DateTime(2024, 1, 1),
      );

      final updated = profile.copyWith(phoneNumber: '+19998887777');

      expect(updated.phoneNumber, '+19998887777');
    });

    // ── toJson / fromJson ────────────────────────────────────────────────────

    test('toJson/fromJson round-trip with phoneNumber', () {
      final original = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        displayName: 'Phone User',
        createdAt: DateTime(2024, 1, 1),
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.phoneNumber, '+15551234567');
      expect(restored, original);
    });

    test('fromJson defaults phoneNumber to null when missing', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'displayName': 'Alice',
        'createdAt': '2024-01-01T00:00:00.000Z',
        // phoneNumber intentionally omitted
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.phoneNumber, isNull);
    });

    test('toJson/fromJson round-trip without phoneNumber', () {
      final original = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        displayName: 'Alice',
        createdAt: DateTime(2024, 1, 1),
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored, original);
    });

    // ── equality ─────────────────────────────────────────────────────────────

    test('equality includes phoneNumber', () {
      final profile1 = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        createdAt: DateTime(2024, 1, 1),
      );

      final profile2 = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+15551234567',
        createdAt: DateTime(2024, 1, 1),
      );

      final profile3 = UserProfile(
        id: 'user-123',
        email: '',
        phoneNumber: '+19998887777',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile1, profile2);
      expect(profile1, isNot(profile3));
    });

    test('profiles with same fields are equal', () {
      final profile1 = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );

      final profile2 = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile1, profile2);
    });
  });
}
