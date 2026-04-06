import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/data/dtos/user_profile_dto.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);

  group('UserProfileDto.fromJson → toDomain', () {
    test('round-trip with all fields', () {
      final json = {
        'id': 'u1',
        'phone': '5551234567',
        'display_name': 'Explorer',
        'created_at': createdAt.toIso8601String(),
      };
      final dto = UserProfileDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.id, 'u1');
      expect(domain.phone, '5551234567');
      expect(domain.displayName, 'Explorer');
      expect(domain.createdAt, createdAt);
    });

    test('null display_name handled', () {
      final json = {
        'id': 'u2',
        'phone': '555',
        'display_name': null,
        'created_at': createdAt.toIso8601String(),
      };
      final dto = UserProfileDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.displayName, isNull);
    });

    test('missing phone defaults to empty string', () {
      final json = {
        'id': 'u3',
        'created_at': createdAt.toIso8601String(),
      };
      final dto = UserProfileDto.fromJson(json);
      final domain = dto.toDomain();
      expect(domain.phone, '');
    });
  });

  group('UserProfileDto.fromDomain → toJson', () {
    test('round-trip', () {
      final profile = UserProfile(
        id: 'u1',
        phone: '5551234567',
        displayName: 'Explorer',
        createdAt: createdAt,
      );
      final dto = UserProfileDto.fromDomain(profile);
      final json = dto.toJson();
      expect(json['id'], 'u1');
      expect(json['phone'], '5551234567');
      expect(json['display_name'], 'Explorer');
      expect(json['created_at'], createdAt.toIso8601String());
    });

    test('null displayName preserved', () {
      final profile = UserProfile(id: 'u1', phone: '555', createdAt: createdAt);
      final dto = UserProfileDto.fromDomain(profile);
      final json = dto.toJson();
      expect(json['display_name'], isNull);
    });
  });
}
