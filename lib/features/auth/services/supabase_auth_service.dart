import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/services/auth_service.dart';

/// Production [AuthService] backed by Supabase.
///
/// This file **must compile** but is NOT the active implementation until
/// Supabase credentials are configured. `MockAuthService` is used instead
/// during development and testing.
///
/// Swap in via `AuthNotifier` once `SUPABASE_URL` / `SUPABASE_ANON_KEY` are
/// supplied as `--dart-define` values and `Supabase.initialize()` is called
/// from `main.dart`.
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
      final response =
          await _auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign-up failed: no user returned');
      }
      return UserProfile(
        id: user.id,
        email: user.email ?? email,
        displayName: displayName,
        createdAt: DateTime.parse(user.createdAt),
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
      return UserProfile(
        id: user.id,
        email: user.email ?? email,
        displayName: _displayNameFrom(user),
        createdAt: DateTime.parse(user.createdAt),
      );
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign-in failed: $e');
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
      return UserProfile(
        id: user.id,
        email: '',
        displayName: 'Explorer',
        createdAt: DateTime.parse(user.createdAt),
        isAnonymous: true,
      );
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
      return UserProfile(
        id: user.id,
        email: user.email ?? email,
        displayName: displayName ?? _displayNameFrom(user),
        createdAt: DateTime.parse(user.createdAt),
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
      // listener (_listenToAuthChanges in AuthNotifier) handles the result.
      await _auth.linkIdentity(supa.OAuthProvider.values.firstWhere(
        (p) => p.name == provider,
        orElse: () => throw AuthException('Unknown OAuth provider: $provider'),
      ));
      // After linkIdentity, the session is updated. Read the current user.
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthException('OAuth link failed: no user after linking');
      }
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: _displayNameFrom(user),
        createdAt: DateTime.parse(user.createdAt),
        isAnonymous: false,
      );
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
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: _displayNameFrom(user),
        createdAt: DateTime.parse(user.createdAt),
        isAnonymous: user.isAnonymous == true,
      );
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
        final user = session.user;
        return UserProfile(
          id: user.id,
          email: user.email ?? '',
          displayName: _displayNameFrom(user),
          createdAt: DateTime.parse(user.createdAt),
          isAnonymous: user.isAnonymous == true,
        );
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
