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

  /// Signs in anonymously (Supabase anonymous auth).
  Future<UserProfile> signInAnonymously();

  /// Upgrades an anonymous user to a permanent email+password account.
  ///
  /// Uses Supabase `updateUser()` to preserve the existing UUID.
  /// Throws [AuthException] if not currently anonymous, email is invalid,
  /// or the operation fails.
  Future<UserProfile> upgradeWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Links an OAuth provider (Google/Apple) to the current anonymous account.
  ///
  /// Uses Supabase `linkIdentity()` to preserve the existing UUID.
  /// Throws [AuthException] if not currently anonymous or linking fails.
  Future<UserProfile> linkOAuthIdentity({required String provider});

  /// Returns true when a valid session is present.
  Future<bool> isSessionValid();

  /// Stream that emits the current user on sign-in and null on sign-out.
  Stream<UserProfile?> get authStateChanges;

  /// Releases resources held by this service.
  void dispose();
}
