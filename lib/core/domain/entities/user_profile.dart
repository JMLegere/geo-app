class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.displayName,
    required this.createdAt,
  });

  final String id;
  final String phone;
  final String? displayName;
  final DateTime createdAt;

  UserProfile copyWith({
    String? id,
    String? phone,
    String? displayName,
    DateTime? createdAt,
  }) =>
      UserProfile(
        id: id ?? this.id,
        phone: phone ?? this.phone,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phone == other.phone &&
          displayName == other.displayName &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, phone, displayName, createdAt);
}
