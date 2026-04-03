import 'package:earth_nova/models/user_profile.dart';

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
/// - `MockAuthService` — in-memory stub for development and testing.
abstract class AuthService {
  /// Sends a one-time password (OTP) SMS to [phone].
  ///
  /// [phone] must be in E.164 format (e.g. '+13334445555').
  Future<void> sendOtp(String phone);

  /// Verifies the OTP [code] sent to [phone] and returns the authenticated user.
  Future<UserProfile> verifyOtp({required String phone, required String code});

  /// Signs out the current user and clears the local session.
  Future<void> signOut();

  /// Returns the currently authenticated user, or null if no session exists.
  Future<UserProfile?> getCurrentUser();

  /// Checks whether a valid cached session exists without making a network call.
  Future<bool> restoreSession();

  /// Signs in (or signs up) using only a phone number — no OTP from the user.
  ///
  /// [phone] must be in E.164 format (e.g. '+13334445555').
  Future<UserProfile> signInWithPhone(String phone);

  /// Stream that emits the current [UserProfile] on sign-in and null on sign-out.
  Stream<UserProfile?> get authStateChanges;

  /// Releases resources held by this service.
  void dispose();
}
