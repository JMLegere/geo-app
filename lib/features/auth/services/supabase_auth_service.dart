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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
        isAnonymous: true,
      );
    } on supa.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Anonymous sign-in failed: $e');
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
        createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
