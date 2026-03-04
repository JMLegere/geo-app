import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/services/auth_service.dart';
import 'package:fog_of_world/features/auth/services/mock_auth_service.dart';
import 'package:fog_of_world/features/auth/services/supabase_auth_service.dart';
import 'package:fog_of_world/features/sync/services/supabase_bootstrap.dart';

/// Manages all auth state transitions.
///
/// On construction, awaits [supabaseReady] before deciding which
/// [AuthService] to use. This allows `main()` to fire-and-forget
/// `initializeSupabase()` while the UI renders a lightweight splash.
///
/// Uses `MockAuthService` when Supabase is not configured or init fails.
class AuthNotifier extends Notifier<AuthState> {
  AuthService? _authService;
  StreamSubscription<void>? _authSubscription;

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

  /// Awaits [supabaseReady], creates the auth service, and checks for an
  /// existing session — all without blocking the first frame.
  Future<void> _initializeAuth() async {
    try {
      await supabaseReady;
      if (!ref.mounted) return;

      _authService = supabaseInitialized
          ? SupabaseAuthService()
          : MockAuthService();

      // Mirror external auth state changes (e.g. token expiry, Supabase events).
      _authSubscription = _authService!.authStateChanges.listen(
        (user) {
          if (user != null) {
            state = AuthState.authenticated(user);
          } else if (state.status != AuthStatus.guest) {
            state = const AuthState.unauthenticated();
          }
        },
        onError: (_) {
          // Supabase may not be initialised (e.g. web locale crash).
          // Fall through to session check which handles the fallback.
        },
      );

      // Check for a persisted session.
      final user = await _authService!.getCurrentUser();
      if (!ref.mounted) return;
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        // No existing session — auto-create anonymous session so the user
        // goes straight to the map. Supabase anonymous auth gives each
        // device a persistent session via localStorage (effectively device
        // ID login). MockAuthService does the same in offline mode.
        final anonUser = await _authService!.signInAnonymously();
        if (!ref.mounted) return;
        state = AuthState.authenticated(anonUser);
      }
    } catch (_) {
      // Provider disposed or session check failed.
      // If still mounted, transition to unauthenticated so the user sees
      // the login screen instead of being stuck in loading forever.
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
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
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
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.message);
    }
  }

  /// Signs out and transitions to unauthenticated.
  Future<void> signOut() async {
    final service = _authService;
    if (service == null) return;
    try {
      await service.signOut();
      state = const AuthState.unauthenticated();
    } on AuthException catch (e) {
      state = AuthState.error(e.message);
    }
  }

  /// Signs in anonymously via Supabase (or mock) anonymous auth.
  /// The user gets a real session and can upgrade to email later.
  Future<void> continueAsGuest() async {
    final service = _authService;
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signInAnonymously();
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.message);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
