import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/observable_notifier.dart';
import 'package:earth_nova/services/auth_service.dart';
import 'package:earth_nova/services/mock_auth_service.dart';
import 'package:earth_nova/services/observability_service.dart';

/// Provider for the auth service — overridden with real impl in main.dart.
final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

/// Provider for the observability service.
final observabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

/// Auth state provider — manages the full auth lifecycle.
final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends ObservableNotifier<AuthState> {
  late final AuthService _auth;

  @override
  ObservabilityService get obs => ref.watch(observabilityProvider);

  @override
  String get category => 'auth';

  @override
  AuthState build() {
    _auth = ref.watch(authServiceProvider);
    _listenToAuthStream();
    return const AuthState.loading();
  }

  void _listenToAuthStream() {
    _auth.authStateChanges.listen((event) {
      switch (event) {
        case AuthStateChanged(user: final user?):
          transition(
              AuthState.authenticated(user), 'auth.external_state_changed');
        case AuthStateChanged(user: null):
          transition(
              const AuthState.unauthenticated(), 'auth.external_sign_out');
        case AuthSessionExpired():
          transition(const AuthState.unauthenticated(), 'auth.session_expired');
        case AuthExternalSignOut():
          transition(
              const AuthState.unauthenticated(), 'auth.external_sign_out');
      }
    });
  }

  Future<void> signInWithPhone(String phone) async {
    transition(const AuthState.loading(), 'auth.sign_in_started',
        data: {'phone_hash': hashPhone(phone)});
    try {
      final user = await _auth.signInWithPhone(phone);
      obs.setUserId(user.id);
      transition(AuthState.authenticated(user), 'auth.sign_in_success');
    } on AuthException catch (e) {
      obs.log('auth.sign_in_error', category, data: {
        'error_type': 'AuthException',
        'error_message': e.message,
      });
      state = AuthState.error(e.message);
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.sign_in_error');
      state = const AuthState.error('Sign-in failed. Try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      transition(const AuthState.unauthenticated(), 'auth.sign_out');
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.sign_out_error');
    }
  }

  Future<void> restoreSession() async {
    transition(const AuthState.loading(), 'auth.session_restore_started');
    try {
      final restored = await _auth.restoreSession();
      if (restored) {
        final user = await _auth.getCurrentUser();
        if (user != null) {
          obs.setUserId(user.id);
          transition(AuthState.authenticated(user), 'auth.session_restored');
          return;
        }
      }
      transition(const AuthState.unauthenticated(), 'auth.no_session');
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.session_restore_error');
      state = const AuthState.unauthenticated();
    }
  }
}
