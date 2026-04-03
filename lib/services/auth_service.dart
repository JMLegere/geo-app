import 'package:earth_nova/models/auth_state.dart';

/// Exception thrown by auth operations.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

/// Abstract auth service — pure Dart, no Flutter dependency.
abstract class AuthService {
  /// Sign in with a phone number.
  /// Derives email and password internally, calls Supabase.
  Future<UserProfile> signInWithPhone(String phone);

  /// Sign out the current user.
  Future<void> signOut();

  /// Get the current user, if any.
  Future<UserProfile?> getCurrentUser();

  /// Restore a stored session. Returns true if a valid session was found.
  Future<bool> restoreSession();

  /// Stream of auth state changes.
  Stream<AuthEvent> get authStateChanges;

  void dispose();
}

/// Auth state change events from the service.
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
