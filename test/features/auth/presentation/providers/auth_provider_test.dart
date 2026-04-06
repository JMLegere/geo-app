import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
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
  });
}
