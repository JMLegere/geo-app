import 'package:earth_nova/core/domain/entities/user_profile.dart';

class AuthException implements Exception {
  const AuthException(this.message);
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
