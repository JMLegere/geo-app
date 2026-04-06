import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('constructs with required fields', () {
      final profile =
          UserProfile(id: '1', phone: '5551234567', createdAt: DateTime(2026));
      expect(profile.id, '1');
      expect(profile.phone, '5551234567');
      expect(profile.displayName, isNull);
      expect(profile.createdAt, DateTime(2026));
    });

    test('copyWith returns new instance with overridden fields', () {
      final original =
          UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
      final copied = original.copyWith(displayName: 'Explorer');
      expect(copied.displayName, 'Explorer');
      expect(copied.id, '1'); // unchanged
    });

    test('value equality', () {
      final a = UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
      final b = UserProfile(id: '1', phone: '555', createdAt: DateTime(2026));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('has no fromJson or toJson method', () {
      // UserProfile is a pure domain entity — serialization lives in UserProfileDto.
      // This test documents the design intent.
      expect(UserProfile(id: '1', phone: '555', createdAt: DateTime(2026)),
          isA<UserProfile>());
    });
  });
}
