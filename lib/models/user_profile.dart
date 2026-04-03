import 'package:flutter/foundation.dart';

/// Immutable model representing an authenticated user.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.phoneNumber,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;

  /// Phone number in E.164 format (e.g. '+13334445555').
  ///
  /// Primary login identifier. Email is retained for backward compatibility
  /// and future upgrade flows.
  final String? phoneNumber;

  final String? displayName;
  final DateTime createdAt;

  UserProfile copyWith({
    String? id,
    String? email,
    String? phoneNumber,
    String? displayName,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      displayName: json['displayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.displayName == displayName &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, email, phoneNumber, displayName, createdAt);

  @override
  String toString() =>
      'UserProfile(id: $id, email: $email, phone: $phoneNumber, '
      'displayName: $displayName)';
}
