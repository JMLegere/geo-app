import 'package:fog_of_world/features/auth/models/user_profile.dart';

enum AuthStatus { unauthenticated, loading, authenticated }

/// Immutable auth state managed by `AuthNotifier`.
///
/// Factory constructors cover every transition:
/// - [AuthState.initial] — checking for a saved session (loading).
/// - [AuthState.loading] — an auth operation is in progress.
/// - [AuthState.authenticated] — user is signed in (includes anonymous).
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

  /// True when the user has an active session.
  bool get isLoggedIn => status == AuthStatus.authenticated;

  /// True when the current user is an anonymous (not upgraded) user.
  bool get isAnonymous => user?.isAnonymous ?? false;

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
