import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:earth_nova/data/sync/auth_service.dart';
import 'package:earth_nova/data/sync/mock_auth_service.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/user_profile.dart';

/// Holds the active [AuthService] implementation.
///
/// Initialized in `main()` before `runApp()`:
/// ```dart
/// container.read(authServiceProvider.notifier).state = authService;
/// ```
final authServiceProvider =
    StateProvider<AuthService>((ref) => MockAuthService());

/// Auth state machine — loading → unauthenticated | authenticated | otpSent.
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<UserProfile?>? _authStreamSub;

  @override
  AuthState build() {
    final authService = ref.watch(authServiceProvider);

    _authStreamSub?.cancel();
    _authStreamSub = authService.authStateChanges.listen((user) {
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    });
    ref.onDispose(() => _authStreamSub?.cancel());

    return const AuthState.loading();
  }

  /// Push a new auth state. Called by main() for session restore.
  void setState(AuthState newState) => state = newState;

  /// Convenience: mark as authenticated with [user].
  void setAuthenticated(UserProfile user) =>
      state = AuthState.authenticated(user);

  /// Convenience: mark as unauthenticated.
  void setUnauthenticated() => state = const AuthState.unauthenticated();

  /// Convenience: mark auth error.
  void setError(String message) => state = AuthState.error(message);

  /// Sign in with phone number (no-OTP flow).
  Future<void> signInWithPhone(String phone) async {
    state = const AuthState.loading();
    try {
      final user = await ref.read(authServiceProvider).signInWithPhone(phone);
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.message);
    } catch (e) {
      state = AuthState.error('Sign-in failed: $e');
    }
  }

  /// Sign out current user.
  Future<void> signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } on AuthException catch (e) {
      debugPrint('[Auth] signOut failed: ${e.message}');
    }
    state = const AuthState.unauthenticated();
  }
}
