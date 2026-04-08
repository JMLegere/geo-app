import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/restore_session.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  bool sessionValid = false;
  UserProfile? currentUser;
  bool signOutCalled = false;

  @override
  Future<bool> restoreSession({String? traceId}) async => sessionValid;

  @override
  Future<UserProfile?> getCurrentUser({String? traceId}) async => currentUser;

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
      final useCase = RestoreSession(repo);
      final result = await useCase.call();
      expect(result, user);
    });

    test('returns null when no session', () async {
      final repo = FakeAuthRepository()..sessionValid = false;
      final useCase = RestoreSession(repo);
      final result = await useCase.call();
      expect(result, isNull);
    });

    test('returns null when session valid but no current user', () async {
      final repo = FakeAuthRepository()
        ..sessionValid = true
        ..currentUser = null;
      final useCase = RestoreSession(repo);
      final result = await useCase.call();
      expect(result, isNull);
    });
  });
}
