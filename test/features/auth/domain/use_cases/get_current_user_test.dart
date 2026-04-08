import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/get_current_user.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  UserProfile? currentUser;

  @override
  Future<UserProfile?> getCurrentUser({String? traceId}) async => currentUser;

  @override
  Future<UserProfile> signInWithEmail(String email, String password,
          {String? traceId}) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> signUpWithEmail(String email, String password,
          {Map<String, dynamic>? metadata, String? traceId}) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut({String? traceId}) async {}

  @override
  Future<bool> restoreSession({String? traceId}) async => false;

  @override
  Stream<AuthEvent> get authStateChanges => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  group('GetCurrentUser', () {
    test('returns user from repository when user is signed in', () async {
      final user =
          UserProfile(id: 'u1', phone: '5551234567', createdAt: DateTime(2026));
      final repo = FakeAuthRepository()..currentUser = user;
      final useCase = GetCurrentUser(repo);
      final result = await useCase.call();
      expect(result, user);
    });

    test('returns null from repository when no user', () async {
      final repo = FakeAuthRepository()..currentUser = null;
      final useCase = GetCurrentUser(repo);
      final result = await useCase.call();
      expect(result, isNull);
    });
  });
}
