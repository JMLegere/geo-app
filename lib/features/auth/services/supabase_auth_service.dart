import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

/// Production [AuthService] backed by Supabase.
///
/// This file **must compile** but is NOT the active implementation until
/// Supabase credentials are configured. `MockAuthService` is used instead
/// during development and testing.
///
/// Wired by `gameCoordinatorProvider` when `SupabaseBootstrap.initialized`
/// is true (i.e. `SUPABASE_URL` / `SUPABASE_ANON_KEY` supplied as
/// `--dart-define` values and `Supabase.initialize()` succeeded).
class SupabaseAuthService implements AuthService {
  /// Convenience accessor — throws [AuthException] if Supabase is not
  /// initialised (credentials missing or `Supabase.initialize()` not called).
  supa.GoTrueClient get _auth {
    try {
      return supa.Supabase.instance.client.auth;
    } catch (e) {
      throw AuthException('Supabase not initialised: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Safely extracts `display_name` from Supabase user metadata.
  ///
  /// Returns `null` if the value is missing or not a [String].
  static String? _displayNameFrom(supa.User user) {
    final raw = user.userMetadata?['display_name'];
    return raw is String ? raw : null;
  }

  /// Safely extracts `phone_number` from Supabase user metadata.
  ///
  /// Returns `null` if the value is missing or not a [String].
  static String? _phoneNumberFrom(supa.User user) {
    final raw = user.userMetadata?['phone_number'];
    return (raw is String && raw.isNotEmpty) ? raw : null;
  }

  /// Builds a [UserProfile] from a Supabase [supa.User].
  ///
  /// Centralises metadata extraction so every call site stays consistent.
  static UserProfile _profileFrom(supa.User user) {
    final phone = _phoneNumberFrom(user);
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      phoneNumber: phone,
      displayName: _displayNameFrom(user),
      createdAt: DateTime.parse(user.createdAt),
      // A user with a phone number attached is no longer anonymous, even if
      // the Supabase `isAnonymous` flag hasn't flipped (we store phone in
      // metadata, not as the primary auth identity — yet).
      isAnonymous: phone == null && (user.isAnonymous == true),
    );
  }

  // ---------------------------------------------------------------------------
  // AuthService implementation
  // ---------------------------------------------------------------------------

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign-up failed: no user returned');
      }
      return _profileFrom(user).copyWith(
        email: user.email ?? email,
        displayName: displayName,
      );
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign-up failed: $e');
    }
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign-in failed: no user returned');
      }
      return _profileFrom(user);
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign-in failed: $e');
    }
  }

  @override
  Future<UserProfile> signInWithPhone({required String phoneNumber}) async {
    // TODO(auth): When Twilio SMS is configured in Supabase dashboard, replace
    // this with the real OTP flow:
    //   1. await _auth.signInWithOtp(phone: phoneNumber);
    //   2. User enters 6-digit code
    //   3. await _auth.verifyOTP(phone: phoneNumber, token: code, type: OtpType.sms);
    //
    // For now: attach the phone number to the current user's metadata.
    // If there is no existing session, create an anonymous one first.
    // Accounts created this way will be wiped when real phone verification
    // is enabled.
    try {
      // Use existing session if available (user is already signed in
      // anonymously from app startup). Only create a new anonymous session
      // if there's no current user.
      var user = _auth.currentUser;
      if (user == null) {
        final response = await _auth.signInAnonymously();
        user = response.user;
        if (user == null) {
          throw const AuthException(
              'Phone sign-in failed: no user returned from anonymous auth');
        }
      }

      // Attach phone number to the user's metadata.
      final updated = await _auth.updateUser(
        supa.UserAttributes(
          data: {'phone_number': phoneNumber},
        ),
      );

      return _profileFrom(updated.user ?? user);
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Phone sign-in failed: $e');
    }
  }

  @override
  Future<UserProfile> signInAnonymously() async {
    try {
      final response = await _auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw const AuthException('Anonymous sign-in failed: no user returned');
      }
      return _profileFrom(user).copyWith(displayName: 'Explorer');
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Anonymous sign-in failed: $e');
    }
  }

  @override
  Future<UserProfile> upgradeWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _auth.updateUser(
        supa.UserAttributes(
          email: email,
          password: password,
          data: displayName != null ? {'display_name': displayName} : null,
        ),
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Upgrade failed: no user returned');
      }
      return _profileFrom(user).copyWith(
        email: user.email ?? email,
        displayName: displayName ?? _displayNameFrom(user),
        isAnonymous: false,
      );
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Upgrade failed: $e');
    }
  }

  @override
  Future<UserProfile> linkOAuthIdentity({required String provider}) async {
    try {
      // linkIdentity opens an OAuth popup/redirect. The auth state change
      // listener (in gameCoordinatorProvider) handles the result.
      await _auth.linkIdentity(supa.OAuthProvider.values.firstWhere(
        (p) => p.name == provider,
        orElse: () => throw AuthException('Unknown OAuth provider: $provider'),
      ));
      // After linkIdentity, the session is updated. Read the current user.
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthException('OAuth link failed: no user after linking');
      }
      return _profileFrom(user).copyWith(isAnonymous: false);
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('OAuth link failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Sign-out failed: $e');
    }
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      return _profileFrom(user);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to get current user: $e');
    }
  }

  @override
  Future<bool> isSessionValid() async {
    try {
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    try {
      return _auth.onAuthStateChange.map((authState) {
        final session = authState.session;
        if (session == null) return null;
        return _profileFrom(session.user);
      });
    } catch (e) {
      return Stream.error(AuthException('Supabase not initialised: $e'));
    }
  }

  @override
  void dispose() {
    // Supabase manages its own resources — nothing to release here.
  }
}
