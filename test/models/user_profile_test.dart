import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    final profile = UserProfile(
      id: 'u_1',
      email: 'test@example.com',
      phoneNumber: '+13334445555',
      displayName: 'Explorer',
      createdAt: DateTime(2026, 1, 1),
    );

    test('constructor stores all fields', () {
      expect(profile.id, 'u_1');
      expect(profile.email, 'test@example.com');
      expect(profile.phoneNumber, '+13334445555');
      expect(profile.displayName, 'Explorer');
      expect(profile.createdAt, DateTime(2026, 1, 1));
    });

    test('copyWith overrides specified fields', () {
      final updated = profile.copyWith(displayName: 'Adventurer');
      expect(updated.displayName, 'Adventurer');
      expect(updated.id, 'u_1');
    });

    test('toJson and fromJson round-trip', () {
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored, profile);
    });

    test('equality by all fields', () {
      final a = UserProfile(
        id: 'u_1',
        email: 'test@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      final b = UserProfile(
        id: 'u_1',
        email: 'test@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when id differs', () {
      final other = profile.copyWith(id: 'u_2');
      expect(other == profile, false);
    });

    test('optional fields can be null', () {
      final minimal = UserProfile(
        id: 'u_2',
        email: 'min@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(minimal.phoneNumber, isNull);
      expect(minimal.displayName, isNull);
    });

    test('toString contains id', () {
      expect(profile.toString(), contains('u_1'));
    });
  });
}
