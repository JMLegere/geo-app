/// Authentication status of the current user.
enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  error,
}

/// Immutable auth state — named constructors, no subclasses.
///
/// Use [when] to exhaustively handle all states without casting.
class AuthState {
  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.loading() : this._(status: AuthStatus.loading);
  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(UserProfile user)
      : this._(status: AuthStatus.authenticated, user: user);
  const AuthState.error(String errorMessage)
      : this._(status: AuthStatus.error, errorMessage: errorMessage);

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  /// Exhaustive pattern matching — forces handling of all states.
  T when<T>({
    required T Function() loading,
    required T Function() unauthenticated,
    required T Function(UserProfile user) authenticated,
    required T Function(String message) error,
  }) {
    switch (status) {
      case AuthStatus.loading:
        return loading();
      case AuthStatus.unauthenticated:
        return unauthenticated();
      case AuthStatus.authenticated:
        return authenticated(user!);
      case AuthStatus.error:
        return error(errorMessage!);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user == other.user &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, user, errorMessage);
}

/// User profile from Supabase auth.
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

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
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
