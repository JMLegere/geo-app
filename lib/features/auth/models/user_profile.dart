import 'package:flutter/foundation.dart';

/// Immutable model representing an authenticated user.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
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
        other.displayName == displayName &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, email, displayName, createdAt);

  @override
  String toString() =>
      'UserProfile(id: $id, email: $email, displayName: $displayName)';
}
