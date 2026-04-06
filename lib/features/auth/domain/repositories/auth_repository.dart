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
  Future<UserProfile> signInWithEmail(String email, String password);

  Future<UserProfile> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
  });

  Future<void> signOut();

  Future<UserProfile?> getCurrentUser();

  Future<bool> restoreSession();

  Stream<AuthEvent> get authStateChanges;

  void dispose();
}
