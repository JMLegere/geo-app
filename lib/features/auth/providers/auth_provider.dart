import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/services/auth_service.dart';
import 'package:fog_of_world/features/auth/services/mock_auth_service.dart';
import 'package:fog_of_world/features/auth/services/supabase_auth_service.dart';
import 'package:fog_of_world/core/state/supabase_bootstrap_provider.dart';

/// Manages all auth state transitions.
///
/// On construction, awaits `supabaseBootstrapProvider.ready` before deciding
/// which [AuthService] to use. This allows `main()` to fire-and-forget
/// `bootstrap.initialize()` while the UI renders a lightweight splash.
///
/// Uses `MockAuthService` when Supabase is not configured or init fails.
class AuthNotifier extends Notifier<AuthState> {
  AuthService? _authService;
  StreamSubscription<UserProfile?>? _authSubscription;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
      _authService?.dispose();
    });

    // Wait for Supabase SDK, then create auth service and check session.
    _initializeAuth();

    return const AuthState.initial(); // loading state
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Awaits `bootstrap.ready`, creates the auth service, and checks for an
  /// existing session — all without blocking the first frame.
  ///
  /// When an existing session is found (phone user or anonymous), transitions
  /// directly to [AuthStatus.authenticated].
  /// When no session exists, signs in anonymously so the user reaches the map
  /// immediately. Users can upgrade to phone auth from settings.
  ///
  /// **Session restore race fix (Layer 2):**
  /// On web, Supabase restores sessions from localStorage asynchronously.
  /// `_auth.currentUser` may be null at the instant we check, even though a
  /// valid session exists. We subscribe to `authStateChanges` FIRST, then wait
  /// briefly for the SDK to fire its initial event. If the first event carries
  /// a user, we're done. If it's null or times out, we sign in anonymously.
  Future<void> _initializeAuth() async {
    try {
      final bootstrap = ref.read(supabaseBootstrapProvider);
      await bootstrap.ready;
      if (!ref.mounted) return;

      _authService =
          bootstrap.initialized ? SupabaseAuthService() : MockAuthService();

      _listenToAuthChanges();

      // Wait for the SDK's initial auth event — this is when a persisted
      // session (if any) becomes available. Timeout after 3s to avoid
      // blocking the user indefinitely on slow networks or missing sessions.
      final restoredUser = await _authService!.authStateChanges.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      if (!ref.mounted) return;

      if (restoredUser != null) {
        state = AuthState.authenticated(restoredUser);
        return;
      }

      // Also check synchronously in case the event already fired before our
      // stream subscription (belt-and-suspenders).
      final currentUser = await _authService!.getCurrentUser();
      if (!ref.mounted) return;
      if (currentUser != null) {
        state = AuthState.authenticated(currentUser);
        return;
      }

      // No existing session — sign in anonymously so the user reaches the map.
      await _signInAnonymouslyWithFallback();
    } catch (e) {
      debugPrint('[AuthNotifier] init failed, falling back to mock: $e');
      if (ref.mounted) {
        await _fallbackToMock();
      }
    }
  }

  /// Subscribes to external auth state changes (token expiry, Supabase events).
  void _listenToAuthChanges() {
    _authSubscription = _authService!.authStateChanges.listen(
      (user) {
        if (!ref.mounted) return;
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = const AuthState.unauthenticated();
        }
      },
      onError: (e) {
        debugPrint('[AuthNotifier] auth state stream error: $e');
      },
    );
  }

  /// Tries Supabase anonymous auth first. If it fails (e.g. 422 — anonymous
  /// auth disabled on the project), swaps to [MockAuthService] and retries.
  Future<void> _signInAnonymouslyWithFallback() async {
    try {
      final anonUser = await _authService!.signInAnonymously();
      if (!ref.mounted) return;
      state = AuthState.authenticated(anonUser);
    } on AuthException {
      // Supabase anonymous sign-in failed — fall back to mock.
      if (!ref.mounted) return;
      await _fallbackToMock();
    }
  }

  /// Disposes the current auth service, replaces it with [MockAuthService],
  /// and signs in anonymously. Guarantees the user reaches the map.
  Future<void> _fallbackToMock() async {
    _authSubscription?.cancel();
    _authService?.dispose();

    _authService = MockAuthService();
    _listenToAuthChanges();

    try {
      final anonUser = await _authService!.signInAnonymously();
      if (!ref.mounted) return;
      state = AuthState.authenticated(anonUser);
    } catch (e) {
      debugPrint('[AuthNotifier] mock fallback failed: $e');
      if (ref.mounted) {
        state = const AuthState.unauthenticated();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Creates a new account and transitions to authenticated.
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final service = _authService;
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Signs in and transitions to authenticated.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final service = _authService;
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signIn(
        email: email,
        password: password,
      );
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Signs in (or creates an account) with a phone number.
  ///
  /// Unified flow: new numbers create an account, existing numbers sign in.
  /// No OTP verification yet — see [AuthService.signInWithPhone].
  ///
  /// Does NOT transition through [AuthState.loading] — the user is already
  /// authenticated anonymously and we're upgrading in-place. A loading
  /// transition would null the user ID, causing downstream providers
  /// (GameCoordinator, inventory, fog) to see a null user and potentially
  /// reset game state.
  // TODO(auth): Add OTP verification step when Twilio SMS is configured.
  Future<void> signInWithPhone({required String phoneNumber}) async {
    final service = _authService;
    if (service == null) return;
    try {
      final user = await service.signInWithPhone(phoneNumber: phoneNumber);
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Signs out and transitions to unauthenticated.
  Future<void> signOut() async {
    final service = _authService;
    if (service == null) return;
    try {
      await service.signOut();
      if (!ref.mounted) return;
      state = const AuthState.unauthenticated();
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Signs in anonymously via Supabase (or mock) anonymous auth.
  /// The user gets a real session and can upgrade to email later.
  ///
  /// Falls back to [MockAuthService] if Supabase anonymous auth fails,
  /// ensuring the user always reaches the map.
  Future<void> continueAsGuest() async {
    final service = _authService;
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signInAnonymously();
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException {
      // Supabase anonymous auth failed — fall back to mock.
      if (!ref.mounted) return;
      await _fallbackToMock();
    }
  }

  /// Upgrades an anonymous account to a permanent email+password account.
  ///
  /// Preserves the existing UUID — no data is orphaned.
  /// No-op if the user is already upgraded (non-anonymous).
  Future<void> upgradeWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final service = _authService;
    if (service == null) return;
    if (!state.isAnonymous) return;
    // Preserve the anonymous session so we can restore it on failure —
    // AuthState.error() clears the user, which would block retry via the
    // isAnonymous guard.
    final previousUser = state.user;
    state = const AuthState.loading();
    try {
      final user = await service.upgradeWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      // Restore anonymous session so the user can retry.
      if (previousUser != null) {
        state = AuthState.authenticated(previousUser);
      } else {
        state = AuthState.error(e.message);
      }
    }
  }

  /// Links an OAuth provider (Google/Apple) to the current anonymous account.
  ///
  /// Preserves the existing UUID — no data is orphaned.
  /// No-op if the user is already upgraded (non-anonymous).
  /// State transition on success is handled by [_listenToAuthChanges].
  Future<void> linkOAuth({required String provider}) async {
    final service = _authService;
    if (service == null) return;
    if (!state.isAnonymous) return;
    // Preserve the anonymous session so we can restore it on failure —
    // same pattern as upgradeWithEmail.
    final previousUser = state.user;
    try {
      await service.linkOAuthIdentity(provider: provider);
      if (!ref.mounted) return;
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      // Restore anonymous session so the user can retry.
      if (previousUser != null) {
        state = AuthState.authenticated(previousUser);
      } else {
        state = AuthState.error(e.message);
      }
    }
  }

  /// Signs out with a guard for anonymous users.
  ///
  /// Anonymous users cannot safely sign out — their local data would be lost.
  /// Sets an error state instead of signing out when the current user is
  /// anonymous.
  Future<void> signOutWithWarning() async {
    if (state.isAnonymous) {
      state = AuthState.error(
        'Cannot sign out anonymous user — data will be lost',
      );
      return;
    }
    await signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
