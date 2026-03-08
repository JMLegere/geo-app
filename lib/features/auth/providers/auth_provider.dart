import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';

/// Thin auth state holder with action wrappers.
///
/// Auth orchestration (session restore, anonymous fallback) lives in
/// [gameCoordinatorProvider]. This notifier handles:
///   - State storage (reactive, watched by UI and routing)
///   - Action wrappers that delegate to [authServiceProvider]
///   - Loading/error state transitions for each action
///
/// [gameCoordinatorProvider] calls [setState] for auth lifecycle events.
/// UI calls action methods (signIn, signOut, etc.) which read
/// [authServiceProvider] for the actual service instance.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

  /// Direct state setter — called by gameCoordinatorProvider for auth
  /// lifecycle events (session restore, anonymous fallback, stream events).
  void setState(AuthState newState) {
    state = newState;
  }

  // ---------------------------------------------------------------------------
  // UI-facing action methods — delegate to authServiceProvider
  // ---------------------------------------------------------------------------

  /// Signs in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signIn(email: email, password: password);
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Creates a new account with email and password.
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final service = ref.read(authServiceProvider);
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

  /// Signs in (or creates an account) with a phone number.
  ///
  /// Does NOT transition through [AuthState.loading] — the user is already
  /// authenticated anonymously and we're upgrading in-place. A loading
  /// transition would null the user ID, causing downstream providers
  /// (GameCoordinator, inventory, fog) to see a null user and potentially
  /// reset game state.
  Future<void> signInWithPhone({required String phoneNumber}) async {
    final service = ref.read(authServiceProvider);
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

  /// Signs out the current user.
  Future<void> signOut() async {
    final service = ref.read(authServiceProvider);
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

  /// Signs out with a guard for anonymous users.
  ///
  /// Anonymous users cannot safely sign out — their local data would be lost.
  /// Sets an error state instead of signing out.
  Future<void> signOutWithWarning() async {
    if (state.isAnonymous) {
      state = AuthState.error(
        'Cannot sign out anonymous user — data will be lost',
      );
      return;
    }
    await signOut();
  }

  /// Signs in anonymously. Falls back to error state if it fails — the
  /// fallback-to-mock logic lives in gameCoordinatorProvider.
  Future<void> continueAsGuest() async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    state = const AuthState.loading();
    try {
      final user = await service.signInAnonymously();
      if (!ref.mounted) return;
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.message);
    }
  }

  /// Upgrades an anonymous account to a permanent email+password account.
  /// Preserves the existing UUID — no data is orphaned.
  Future<void> upgradeWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    if (!state.isAnonymous) return;
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
      if (previousUser != null) {
        state = AuthState.authenticated(previousUser);
      } else {
        state = AuthState.error(e.message);
      }
    }
  }

  /// Links an OAuth provider (Google/Apple) to the current anonymous account.
  Future<void> linkOAuth({required String provider}) async {
    final service = ref.read(authServiceProvider);
    if (service == null) return;
    if (!state.isAnonymous) return;
    final previousUser = state.user;
    try {
      await service.linkOAuthIdentity(provider: provider);
      if (!ref.mounted) return;
    } on AuthException catch (e) {
      if (!ref.mounted) return;
      if (previousUser != null) {
        state = AuthState.authenticated(previousUser);
      } else {
        state = AuthState.error(e.message);
      }
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Holds the [AuthService] instance created by gameCoordinatorProvider
/// during auth initialization.
///
/// Null until auth init completes. [AuthNotifier] reads this for all
/// auth operations. UI can also read it directly if needed.
class AuthServiceHolder extends Notifier<AuthService?> {
  @override
  AuthService? build() => null;

  void set(AuthService service) {
    state = service;
  }
}

final authServiceProvider =
    NotifierProvider<AuthServiceHolder, AuthService?>(AuthServiceHolder.new);
