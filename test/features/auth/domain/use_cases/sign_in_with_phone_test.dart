import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/sign_in_with_phone.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  UserProfile? userToReturn;
  bool signInCalled = false;
  bool signUpCalled = false;
  String? lastEmail;
  String? lastPassword;
  bool shouldThrowOnSignIn = false;
  String signInErrorMessage = 'Invalid login credentials';

  @override
  Future<UserProfile> signInWithEmail(String email, String password,
      {String? traceId}) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    if (shouldThrowOnSignIn) throw AuthException(signInErrorMessage);
    return userToReturn!;
  }

  @override
  Future<UserProfile> signUpWithEmail(String email, String password,
      {Map<String, dynamic>? metadata, String? traceId}) async {
    signUpCalled = true;
    return userToReturn!;
  }

  @override
  Future<void> signOut({String? traceId}) async {}

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
  group('SignInWithPhone', () {
    test('derives email as digits@earthnova.app', () async {
      final repo = FakeAuthRepository()..userToReturn = _testUser();
      final useCase = SignInWithPhone(repo);
      await useCase.call('(555) 123-4567');
      expect(repo.lastEmail, '5551234567@earthnova.app');
    });

    test('derives password as SHA-256 of phone:earthnova-beta-2026', () async {
      final repo = FakeAuthRepository()..userToReturn = _testUser();
      final useCase = SignInWithPhone(repo);
      await useCase.call('5551234567');
      expect(repo.lastPassword, isNotEmpty);
      expect(repo.lastPassword!.length, 64);
    });

    test('falls back to signUp when signIn throws invalid credentials',
        () async {
      final repo = FakeAuthRepository()
        ..shouldThrowOnSignIn = true
        ..userToReturn = _testUser();
      final useCase = SignInWithPhone(repo);
      final result = await useCase.call('5551234567');
      expect(repo.signInCalled, isTrue);
      expect(repo.signUpCalled, isTrue);
      expect(result.id, _testUser().id);
    });

    test('rethrows non-credential AuthExceptions', () async {
      final repo = FakeAuthRepository()
        ..shouldThrowOnSignIn = true
        ..signInErrorMessage = 'Network error';
      final useCase = SignInWithPhone(repo);
      expect(
        () => useCase.call('5551234567'),
        throwsA(isA<AuthException>()),
      );
    });

    test('strips non-digit characters from phone for email derivation',
        () async {
      final repo = FakeAuthRepository()..userToReturn = _testUser();
      final useCase = SignInWithPhone(repo);
      await useCase.call('+1 (555) 123-4567');
      expect(repo.lastEmail, '15551234567@earthnova.app');
    });
  });
}

UserProfile _testUser() =>
    UserProfile(id: 'u1', phone: '5551234567', createdAt: DateTime(2026));
