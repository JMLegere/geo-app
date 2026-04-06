import 'package:earth_nova/core/domain/entities/user_profile.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  error,
}

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
