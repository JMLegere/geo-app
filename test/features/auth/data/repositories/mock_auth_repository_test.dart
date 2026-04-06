import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';

void main() {
  group('MockAuthRepository', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = MockAuthRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('accepts 10-digit phone and returns a user', () async {
      final user = await repo.signInWithEmail(
        '5551234567@earthnova.app',
        'anypassword',
      );
      expect(user.id, isNotEmpty);
      expect(user.phone, '5551234567');
    });

    test('rejects phone with fewer than 10 digits', () async {
      expect(
        () => repo.signInWithEmail('12345@earthnova.app', 'anypassword'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sign out clears current user', () async {
      await repo.signInWithEmail('5551234567@earthnova.app', 'anypassword');
      expect(await repo.getCurrentUser(), isNotNull);
      await repo.signOut();
      expect(await repo.getCurrentUser(), isNull);
    });

    test('signUpWithEmail also creates a user', () async {
      final user = await repo.signUpWithEmail(
        '5551234567@earthnova.app',
        'anypassword',
        metadata: {'phone_number': '5551234567'},
      );
      expect(user.id, isNotEmpty);
    });

    test('restoreSession returns true when user is signed in', () async {
      await repo.signInWithEmail('5551234567@earthnova.app', 'anypassword');
      final restored = await repo.restoreSession();
      expect(restored, isTrue);
    });

    test('restoreSession returns false when no user', () async {
      final restored = await repo.restoreSession();
      expect(restored, isFalse);
    });
  });
}
