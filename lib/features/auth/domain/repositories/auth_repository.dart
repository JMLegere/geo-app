import 'package:earth_nova/core/domain/entities/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  /// Stable credential outcome used by the phone sign-in flow to initiate its
  /// first-use sign-up path.
  const AuthException.invalidCredentials() : this('Invalid login credentials.');

  /// Stable safe failure for unavailable or malformed auth responses.
  const AuthException.unavailable()
      : this('Authentication service unavailable.');

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

sealed class AuthEvent {
  const AuthEvent();
}

class AuthStateChanged extends AuthEvent {
  const AuthStateChanged(this.user);
  final UserProfile? user;
}

class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

class AuthExternalSignOut extends AuthEvent {
  const AuthExternalSignOut();
}

abstract class AuthRepository {
  Future<UserProfile> signInWithEmail(
    String email,
    String password, {
    String? traceId,
  });

  Future<UserProfile> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
    String? traceId,
  });

  Future<void> signOut({String? traceId});

  Future<UserProfile?> getCurrentUser({String? traceId});

  Future<bool> restoreSession({String? traceId});

  Stream<AuthEvent> get authStateChanges;

  void dispose();
}
