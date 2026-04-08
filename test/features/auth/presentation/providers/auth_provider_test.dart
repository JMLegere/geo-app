import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];
  final List<({Object error, String event})> errors = [];
  String? userId;

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  @override
  void logError(Object error, StackTrace stack,
      {String event = 'app.crash.unhandled'}) {
    errors.add((error: error, event: event));
    super.logError(error, stack, event: event);
  }

  @override
  void setUserId(String id) {
    userId = id;
    super.setUserId(id);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

void main() {
  group('AuthNotifier observability', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late MockAuthRepository auth;

    setUp(() {
      obs = TestObservabilityService();
      auth = MockAuthRepository();
      container = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      auth.dispose();
    });

    test('signInWithPhone logs sign_in_started then sign_in_success', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      expect(obs.eventNames, contains('auth.sign_in_started'));
      expect(obs.eventNames, contains('auth.sign_in_success'));

      final startIdx = obs.eventNames.indexOf('auth.sign_in_started');
      final successIdx = obs.eventNames.indexOf('auth.sign_in_success');
      expect(startIdx, lessThan(successIdx));
    });

    test('signInWithPhone logs phone_hash, never raw phone', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      final startEvent =
          obs.events.firstWhere((e) => e.event == 'auth.sign_in_started');
      expect(startEvent.data, isNotNull);
      expect(startEvent.data!['phone_hash'], isA<String>());
      expect(startEvent.data!['phone_hash'].length, 64);
      expect(startEvent.data!['phone_hash'], isNot(contains('555')));
    });

    test('signInWithPhone sets userId on success', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      expect(obs.userId, isNotNull);
      expect(obs.userId, startsWith('mock_'));
    });

    test('signInWithPhone logs sign_in_error on invalid phone', () async {
      container.read(authProvider);

      await container.read(authProvider.notifier).signInWithPhone('+1555');

      expect(obs.eventNames, contains('auth.sign_in_started'));
      final errorEvent =
          obs.events.where((e) => e.event == 'auth.sign_in_error');
      expect(errorEvent, isNotEmpty);
    });

    test('signInWithPhone uses category auth', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      for (final event in obs.events) {
        expect(event.category, 'auth');
      }
    });

    test('signOut logs auth.sign_out', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      obs.events.clear();

      await container.read(authProvider.notifier).signOut();

      expect(obs.eventNames, contains('auth.sign_out'));
    });

    test('restoreSession logs session_restore_started then no_session',
        () async {
      container.read(authProvider);

      await container.read(authProvider.notifier).restoreSession();

      expect(obs.eventNames, contains('auth.session_restore_started'));
      expect(obs.eventNames, contains('auth.no_session'));
    });

    test('restoreSession logs session_restored when session exists', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      obs.events.clear();

      await container.read(authProvider.notifier).restoreSession();

      expect(obs.eventNames, contains('auth.session_restore_started'));
      expect(obs.eventNames, contains('auth.session_restored'));
    });

    test('state transitions to authenticated on successful sign-in', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, isNotNull);
    });

    test('state transitions to error on failed sign-in', () async {
      container.read(authProvider);

      await container.read(authProvider.notifier).signInWithPhone('+1555');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
    });

    test('state transitions to unauthenticated on sign-out', () async {
      container.read(authProvider);

      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      await container.read(authProvider.notifier).signOut();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('auth stream handles AuthSessionExpired event', () async {
      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      // Simulate session expiry via the stream
      auth.emitEvent(const AuthSessionExpired());
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('auth stream handles AuthExternalSignOut event', () async {
      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');

      auth.emitEvent(const AuthExternalSignOut());
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('restoreSession transitions to error on exception', () async {
      final failingAuth = _FailingAuthRepository();
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(failingAuth),
        ],
      );

      c.read(authProvider);
      await c.read(authProvider.notifier).restoreSession();

      final state = c.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(obs.errors.map((e) => e.event),
          contains('auth.session_restore_error'));
      c.dispose();
    });

    test('signInWithPhone handles generic exception', () async {
      final failingAuth = _FailingAuthRepository();
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(failingAuth),
        ],
      );

      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');

      final state = c.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Sign-in failed. Try again.');
      c.dispose();
    });

    test('signOut handles exception gracefully', () async {
      final failingAuth = _FailingAuthRepository(failOnSignOut: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(failingAuth),
        ],
      );

      c.read(authProvider);
      // Sign out should not throw
      await c.read(authProvider.notifier).signOut();
      expect(obs.errors.map((e) => e.event), contains('auth.sign_out_error'));
      c.dispose();
    });
  });
}

/// Repository that throws generic exceptions (not AuthException).
class _FailingAuthRepository implements AuthRepository {
  _FailingAuthRepository({this.failOnSignOut = false});

  final bool failOnSignOut;
  final _controller = StreamController<AuthEvent>.broadcast();

  @override
  Stream<AuthEvent> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    throw Exception('Network error');
  }

  @override
  Future<UserProfile> signUpWithEmail(String email, String password,
      {Map<String, dynamic>? metadata}) async {
    throw Exception('Network error');
  }

  @override
  Future<void> signOut() async {
    if (failOnSignOut) throw Exception('Sign out failed');
  }

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<bool> restoreSession() async => throw Exception('Restore failed');

  @override
  void dispose() => _controller.close();
}
