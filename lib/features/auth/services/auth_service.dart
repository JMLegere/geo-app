import 'package:fog_of_world/features/auth/models/user_profile.dart';

/// Thrown by [AuthService] implementations when an auth operation fails.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Abstract contract for authentication operations.
///
/// Two implementations:
/// - `MockAuthService` — in-memory, no network (dev & test).
/// - `SupabaseAuthService` — real backend (prod, requires credentials).
abstract class AuthService {
  /// Creates a new user account.
  ///
  /// Throws [AuthException] on invalid email, duplicate registration, or
  /// network failure.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Signs in with email and password.
  ///
  /// Throws [AuthException] on bad credentials or network failure.
  Future<UserProfile> signIn({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  Future<void> signOut();

  /// Returns the currently authenticated user, or null if no session exists.
  Future<UserProfile?> getCurrentUser();

  /// Returns true when a valid session is present.
  Future<bool> isSessionValid();

  /// Stream that emits the current user on sign-in and null on sign-out.
  Stream<UserProfile?> get authStateChanges;

  /// Releases resources held by this service.
  void dispose();
}
