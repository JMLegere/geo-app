import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/auth_state.dart';
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

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _auth;
  late final ObservabilityService _obs;

  @override
  AuthState build() {
    _auth = ref.watch(authServiceProvider);
    _obs = ref.watch(observabilityProvider);
    _listenToAuthStream();
    return const AuthState.loading();
  }

  void _listenToAuthStream() {
    _auth.authStateChanges.listen((event) {
      switch (event) {
        case AuthStateChanged(user: final user?):
          state = AuthState.authenticated(user);
        case AuthStateChanged(user: null):
          state = const AuthState.unauthenticated();
        case AuthSessionExpired():
          state = const AuthState.unauthenticated();
        case AuthExternalSignOut():
          state = const AuthState.unauthenticated();
      }
    });
  }

  Future<void> signInWithPhone(String phone) async {
    state = const AuthState.loading();
    try {
      final user = await _auth.signInWithPhone(phone);
      _obs.setUserId(user.id);
      _obs.log('auth.sign_in_success', 'auth');
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      _obs.log('auth.sign_in_error', 'auth', data: {
        'error_message': e.message,
      });
      state = AuthState.error(e.message);
    } catch (e) {
      _obs.logError(e, StackTrace.current, event: 'auth.sign_in_error');
      state = const AuthState.error('Sign-in failed. Try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _obs.log('auth.sign_out', 'auth');
      state = const AuthState.unauthenticated();
    } catch (e) {
      _obs.logError(e, StackTrace.current, event: 'auth.sign_out_error');
    }
  }

  Future<void> restoreSession() async {
    state = const AuthState.loading();
    _obs.log('auth.session_restore_started', 'auth');
    try {
      final restored = await _auth.restoreSession();
      if (restored) {
        final user = await _auth.getCurrentUser();
        if (user != null) {
          _obs.setUserId(user.id);
          _obs.log('auth.session_restored', 'auth');
          state = AuthState.authenticated(user);
          return;
        }
      }
      _obs.log('auth.no_session', 'auth');
      state = const AuthState.unauthenticated();
    } catch (e) {
      _obs.logError(e, StackTrace.current, event: 'auth.session_restore_error');
      state = const AuthState.unauthenticated();
    }
  }
}
