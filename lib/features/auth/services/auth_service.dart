import 'package:earth_nova/features/auth/models/user_profile.dart';

/// Thrown by [AuthService] implementations when an auth operation fails.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Abstract contract for phone+OTP authentication.
///
/// Implementations:
/// - `SupabaseAuthService` — real backend (prod, requires credentials).
/// - In-memory stub available for development and testing.
abstract class AuthService {
  /// Sends a one-time password (OTP) SMS to [phone].
  ///
  /// [phone] must be in E.164 format (e.g. '+13334445555').
  ///
  /// Throws [AuthException] on invalid phone format, rate limiting, or
  /// network failure.
  Future<void> sendOtp(String phone);

  /// Verifies the OTP [code] sent to [phone] and returns the authenticated user.
  ///
  /// [phone] must be the same E.164 number passed to [sendOtp].
  /// [code] is the 6-digit SMS code the user received.
  ///
  /// Throws [AuthException] if the code is invalid, expired, or the network
  /// is unavailable.
  Future<UserProfile> verifyOtp({required String phone, required String code});

  /// Signs out the current user and clears the local session.
  Future<void> signOut();

  /// Returns the currently authenticated user, or null if no session exists.
  Future<UserProfile?> getCurrentUser();

  /// Checks whether a valid cached session exists without making a network call.
  ///
  /// Returns true if a non-expired session is present in local storage.
  /// Returns false if there is no session or it has expired — the user must
  /// go through the OTP flow again.
  Future<bool> restoreSession();

  /// Signs in (or signs up) using only a phone number — no OTP, no password
  /// from the user's perspective.
  ///
  /// A deterministic password is derived behind the scenes so the same phone
  /// always resolves to the same Supabase account. Requires "Phone
  /// Confirmations" to be disabled in the Supabase dashboard.
  ///
  /// [phone] must be in E.164 format (e.g. '+13334445555').
  ///
  /// Throws [AuthException] on invalid phone, network failure, or backend
  /// misconfiguration.
  Future<UserProfile> signInWithPhone(String phone);

  /// Stream that emits the current [UserProfile] on sign-in and null on sign-out.
  Stream<UserProfile?> get authStateChanges;

  /// Releases resources held by this service.
  void dispose();
}
