import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/domain/use_cases/sign_out.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';

class FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile> signUpWithEmail(String email, String password,
          {Map<String, dynamic>? metadata}) async =>
      throw UnimplementedError();

  @override
  Future<UserProfile?> getCurrentUser() async => null;

  @override
  Future<bool> restoreSession() async => false;

  @override
  Stream<AuthEvent> get authStateChanges => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  group('SignOut', () {
    test('calls repository signOut', () async {
      final repo = FakeAuthRepository();
      final useCase = SignOut(repo);
      await useCase.call();
      expect(repo.signOutCalled, isTrue);
    });
  });
}
