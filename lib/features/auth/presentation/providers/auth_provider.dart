import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/sign_in_with_phone.dart';
import 'package:earth_nova/features/auth/domain/use_cases/sign_out.dart';
import 'package:earth_nova/features/auth/domain/use_cases/restore_session.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final observabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final signInWithPhoneProvider = Provider<SignInWithPhone>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return SignInWithPhone(ref.watch(authRepositoryProvider));
  },
);

final signOutProvider = Provider<SignOut>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return SignOut(ref.watch(authRepositoryProvider));
  },
);

final restoreSessionProvider = Provider<RestoreSession>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return RestoreSession(ref.watch(authRepositoryProvider));
  },
);

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends ObservableNotifier<AuthState> {
  late final AuthRepository _authRepository;

  @override
  ObservabilityService get obs => ref.watch(observabilityProvider);

  @override
  String get category => 'auth';

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _listenToAuthStream();
    return const AuthState.loading();
  }

  void _listenToAuthStream() {
    _authRepository.authStateChanges.listen((event) {
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
      final useCase = ref.read(signInWithPhoneProvider);
      final user = await useCase.call(phone);
      obs.setUserId(user.id);
      transition(AuthState.authenticated(user), 'auth.sign_in_success');
    } on AuthException catch (e) {
      obs.log('auth.sign_in_error', category, data: {
        'error_type': 'AuthException',
        'error_message': e.message,
      });
      transition(AuthState.error(e.message), 'auth.sign_in_error');
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.sign_in_error');
      transition(const AuthState.error('Sign-in failed. Try again.'),
          'auth.sign_in_error');
    }
  }

  Future<void> signOut() async {
    try {
      final useCase = ref.read(signOutProvider);
      await useCase.call();
      transition(const AuthState.unauthenticated(), 'auth.sign_out');
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.sign_out_error');
    }
  }

  Future<void> restoreSession() async {
    transition(const AuthState.loading(), 'auth.session_restore_started');
    try {
      final useCase = ref.read(restoreSessionProvider);
      final user = await useCase.call();
      if (user != null) {
        obs.setUserId(user.id);
        transition(AuthState.authenticated(user), 'auth.session_restored');
        return;
      }
      transition(const AuthState.unauthenticated(), 'auth.no_session');
    } catch (e, stack) {
      obs.logError(e, stack, event: 'auth.session_restore_error');
      transition(
          const AuthState.unauthenticated(), 'auth.session_restore_error');
    }
  }
}
