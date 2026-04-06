import 'package:earth_nova/core/domain/entities/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.id,
    required this.phone,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String? displayName;
  final DateTime createdAt;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
        id: json['id'] as String,
        phone: json['phone'] as String? ?? '',
        displayName: json['display_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'display_name': displayName,
        'created_at': createdAt.toIso8601String(),
      };

  UserProfile toDomain() => UserProfile(
        id: id,
        phone: phone,
        displayName: displayName,
        createdAt: createdAt,
      );

  factory UserProfileDto.fromDomain(UserProfile profile) => UserProfileDto(
        id: profile.id,
        phone: profile.phone,
        displayName: profile.displayName,
        createdAt: profile.createdAt,
      );
}
