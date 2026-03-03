import 'package:fog_of_world/features/auth/models/user_profile.dart';

enum AuthStatus { unauthenticated, loading, authenticated, guest }

/// Immutable auth state managed by `AuthNotifier`.
///
/// Factory constructors cover every transition:
/// - [AuthState.initial] — checking for a saved session (loading).
/// - [AuthState.loading] — an auth operation is in progress.
/// - [AuthState.authenticated] — user is signed in.
/// - [AuthState.guest] — user chose to skip sign-in.
/// - [AuthState.unauthenticated] — confirmed no session.
/// - [AuthState.error] — last auth operation failed.
class AuthState {
  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  /// Initial state while checking for an existing session.
  ///
  /// Deliberately returns [AuthStatus.loading] so the app can display the map
  /// while the session check completes, avoiding a brief LoginScreen flash on
  /// cold start.
  const AuthState.initial() : this._(status: AuthStatus.loading);

  /// An auth operation (sign-in / sign-up) is in progress.
  const AuthState.loading() : this._(status: AuthStatus.loading);

  /// User is fully authenticated.
  AuthState.authenticated(UserProfile user)
      : this._(status: AuthStatus.authenticated, user: user);

  /// User chose to continue without an account.
  const AuthState.guest() : this._(status: AuthStatus.guest);

  /// No session found after checking, or user signed out.
  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  /// An auth operation failed; [errorMessage] describes the failure.
  AuthState.error(String message)
      : this._(status: AuthStatus.unauthenticated, errorMessage: message);

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
  }) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// True when the user has an active session (signed in or guest).
  bool get isLoggedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.guest;

  /// True when the user is in guest mode.
  bool get isGuest => status == AuthStatus.guest;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, user, errorMessage);

  @override
  String toString() =>
      'AuthState(status: $status, user: $user, error: $errorMessage)';
}
