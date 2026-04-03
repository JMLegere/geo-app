import 'package:earth_nova/models/user_profile.dart';

enum AuthStatus {
  unauthenticated,
  loading,
  otpSent,
  otpVerifying,
  authenticated
}

/// Immutable auth state pushed by `gameCoordinatorProvider` via
/// `AuthNotifier.setState()`.
///
/// Factory constructors cover every transition:
/// - [AuthState.loading] — an auth operation is in progress (UI indicator only).
/// - [AuthState.otpSent] — OTP was sent to phone, waiting for user input.
/// - [AuthState.otpVerifying] — user submitted OTP, verification in progress.
/// - [AuthState.authenticated] — user is signed in.
/// - [AuthState.unauthenticated] — confirmed no session, or user signed out.
/// - [AuthState.error] — last auth operation failed.
class AuthState {
  const AuthState._({
    required this.status,
    this.user,
    this.phone,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? phone;
  final String? errorMessage;

  /// An auth operation is in progress (UI indicator only — does NOT reset game state).
  const AuthState.loading() : this._(status: AuthStatus.loading);

  /// User is fully authenticated.
  AuthState.authenticated(UserProfile user)
      : this._(status: AuthStatus.authenticated, user: user);

  /// No session found, or user signed out.
  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  /// OTP was sent to [phone]. Waiting for user to enter code.
  AuthState.otpSent({required String phone})
      : this._(status: AuthStatus.otpSent, phone: phone);

  /// User submitted OTP code. Verification in progress.
  AuthState.otpVerifying({required String phone})
      : this._(status: AuthStatus.otpVerifying, phone: phone);

  /// An auth operation failed; [errorMessage] describes the failure.
  AuthState.error(String message)
      : this._(status: AuthStatus.unauthenticated, errorMessage: message);

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? phone,
    String? errorMessage,
  }) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      phone: phone ?? this.phone,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// True when the user has an active session.
  bool get isLoggedIn => status == AuthStatus.authenticated;

  /// Pattern-match over auth status, similar to sealed class `when`.
  ///
  /// Maps each known status to a builder function. [otpVerifying] falls
  /// through to [loading] since both represent in-progress operations.
  T when<T>({
    required T Function() loading,
    required T Function() unauthenticated,
    required T Function(UserProfile user) authenticated,
    required T Function(String? phone) otpSent,
  }) {
    switch (status) {
      case AuthStatus.loading:
      case AuthStatus.otpVerifying:
        return loading();
      case AuthStatus.unauthenticated:
        return unauthenticated();
      case AuthStatus.authenticated:
        return authenticated(user!);
      case AuthStatus.otpSent:
        return otpSent(phone);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.phone == phone &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(status, user, phone, errorMessage);

  @override
  String toString() =>
      'AuthState(status: $status, user: $user, phone: $phone, error: $errorMessage)';
}
