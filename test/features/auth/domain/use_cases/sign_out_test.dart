import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/sign_out.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> signOut({String? traceId}) async {
    signOutCalled = true;
    lastTraceId = traceId;
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
  Future<UserProfile?> getCurrentUser({String? traceId}) async => null;

  @override
  Future<bool> restoreSession({String? traceId}) async => false;

  @override
  Stream<AuthEvent> get authStateChanges => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  group('SignOut', () {
    test('calls repository signOut', () async {
      final repo = FakeAuthRepository();
      final useCase = SignOut(repo, TestObservabilityService());
      await useCase.call(null);
      expect(repo.signOutCalled, isTrue);
    });

    test('logs lifecycle and forwards trace id', () async {
      final repo = FakeAuthRepository();
      final obs = TestObservabilityService();
      final useCase = SignOut(repo, obs);

      await useCase.call(null);

      expect(obs.events, hasLength(2));
      expect(obs.events[0]['event'], 'operation.started');
      expect(obs.events[1]['event'], 'operation.completed');

      final startedData = obs.events[0]['data'] as Map<String, dynamic>;
      final completedData = obs.events[1]['data'] as Map<String, dynamic>;
      final traceId = startedData['trace_id'] as String;

      expect(startedData['operation_name'], 'auth.sign_out');
      expect(completedData['trace_id'], traceId);
      expect(repo.lastTraceId, traceId);
    });
  });
}
