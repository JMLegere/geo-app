import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
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

  /// Awaits `bootstrap.ready`, creates the auth service, and checks for an
  /// existing session — all without blocking the first frame.
  ///
  /// When Supabase anonymous sign-in fails (e.g. anonymous auth disabled,
  /// 422 response), automatically falls back to [MockAuthService] so the
  /// user always reaches the map.
  Future<void> _initializeAuth() async {
    try {
      final bootstrap = ref.read(supabaseBootstrapProvider);
      await bootstrap.ready;
      if (!ref.mounted) return;

      _authService = bootstrap.initialized
          ? SupabaseAuthService()
          : MockAuthService();

      _listenToAuthChanges();

      // Check for a persisted session.
      final user = await _authService!.getCurrentUser();
      if (!ref.mounted) return;
      if (user != null) {
        state = AuthState.authenticated(user);
        return;
      }

      // No existing session — auto-create anonymous session so the user
      // goes straight to the map.
      await _signInAnonymouslyWithFallback();
    } catch (_) {
      // Provider disposed or session check failed — fall back to mock so
      // the user always gets in.
      if (ref.mounted) {
        await _fallbackToMock();
      }
    }
  }

  /// Subscribes to external auth state changes (token expiry, Supabase events).
  void _listenToAuthChanges() {
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
        // Fall through — session check handles the fallback.
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
    } catch (_) {
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
  ///
  /// Falls back to [MockAuthService] if Supabase anonymous auth fails,
  /// ensuring the user always reaches the map.
  Future<void> continueAsGuest() async {
    if (_authService == null) return;
    state = const AuthState.loading();
    try {
      final user = await _authService!.signInAnonymously();
      state = AuthState.authenticated(user);
    } on AuthException {
      // Supabase anonymous auth failed — fall back to mock.
      await _fallbackToMock();
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
