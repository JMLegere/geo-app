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

  /// Signs in (or creates an account) with a phone number.
  ///
  /// Unified flow: if [phoneNumber] is new, creates an account; if it already
  /// exists, signs in the existing user. Phone must be E.164 format
  /// (e.g. '+13334445555').
  ///
  /// **Current behavior (pre-OTP):** Authenticates immediately without SMS
  /// verification. Accounts created this way will be wiped when OTP
  /// verification is enabled.
  ///
  /// **Future behavior (post-OTP):** Will call `signInWithOtp(phone:)` to
  /// send an SMS code, then require `verifyOtp()` before granting a session.
  ///
  /// Throws [AuthException] on invalid phone format or network failure.
  // TODO(auth): Add OTP verification step when Twilio SMS is configured.
  // Flow will become: signInWithPhone → requestOtp → verifyOtp → session.
  Future<UserProfile> signInWithPhone({required String phoneNumber});

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
