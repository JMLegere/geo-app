import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/restore_session.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({
      'event': event,
      'category': category,
      'data': data ?? <String, dynamic>{},
    });
    super.log(event, category, data: data);
  }
}

class FakeAuthRepository implements AuthRepository {
  bool sessionValid = false;
  UserProfile? currentUser;
  bool signOutCalled = false;
  String? lastRestoreTraceId;
  String? lastCurrentUserTraceId;

  @override
  Future<bool> restoreSession({String? traceId}) async {
    lastRestoreTraceId = traceId;
    return sessionValid;
  }

  @override
  Future<UserProfile?> getCurrentUser({String? traceId}) async {
    lastCurrentUserTraceId = traceId;
    return currentUser;
  }

  @override
  Future<void> signOut({String? traceId}) async {
    signOutCalled = true;
  }

  @override
  Future<UserProfile> signInWithEmail(String email, String password,
          {String? traceId}) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> signUpWithEmail(String email, String password,
          {Map<String, dynamic>? metadata, String? traceId}) async =>
      throw UnimplementedError();

  @override
  Stream<AuthEvent> get authStateChanges => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  group('RestoreSession', () {
    test('returns user when session is valid', () async {
      final user =
          UserProfile(id: 'u1', phone: '5551234567', createdAt: DateTime(2026));
      final repo = FakeAuthRepository()
        ..sessionValid = true
        ..currentUser = user;
      final useCase = RestoreSession(repo, TestObservabilityService());
      final result = await useCase.call(null);
      expect(result, user);
    });

    test('returns null when no session', () async {
      final repo = FakeAuthRepository()..sessionValid = false;
      final useCase = RestoreSession(repo, TestObservabilityService());
      final result = await useCase.call(null);
      expect(result, isNull);
    });

    test('returns null when session valid but no current user', () async {
      final repo = FakeAuthRepository()
        ..sessionValid = true
        ..currentUser = null;
      final useCase = RestoreSession(repo, TestObservabilityService());
      final result = await useCase.call(null);
      expect(result, isNull);
    });

    test('logs lifecycle and forwards trace id to repository calls', () async {
      final user =
          UserProfile(id: 'u1', phone: '5551234567', createdAt: DateTime(2026));
      final repo = FakeAuthRepository()
        ..sessionValid = true
        ..currentUser = user;
      final obs = TestObservabilityService();
      final useCase = RestoreSession(repo, obs);

      await useCase.call(null);

      expect(obs.events, hasLength(2));
      expect(obs.events[0]['event'], 'operation.started');
      expect(obs.events[1]['event'], 'operation.completed');

      final startedData = obs.events[0]['data'] as Map<String, dynamic>;
      final completedData = obs.events[1]['data'] as Map<String, dynamic>;
      final traceId = startedData['trace_id'] as String;

      expect(startedData['operation'], 'auth.restore_session');
      expect(completedData['trace_id'], traceId);
      expect(repo.lastRestoreTraceId, traceId);
      expect(repo.lastCurrentUserTraceId, traceId);
    });
  });
}
