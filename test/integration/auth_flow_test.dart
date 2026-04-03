// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/sync/auth_service.dart';
import 'package:earth_nova/data/sync/mock_auth_service.dart';

void main() {
  late MockAuthService auth;

  setUp(() {
    auth = MockAuthService();
  });

  tearDown(() {
    auth.dispose();
  });

  group('MockAuthService', () {
    test('signIn via OTP: sendOtp → verifyOtp → session established', () async {
      await auth.sendOtp('+13334445555');
      final user = await auth.verifyOtp(phone: '+13334445555', code: '123456');

      expect(user.phoneNumber, '+13334445555');
      expect(user.id, isNotEmpty);

      final current = await auth.getCurrentUser();
      expect(current, isNotNull);
      expect(current!.id, user.id);
    });

    test('signOut clears session', () async {
      await auth.sendOtp('+13334445555');
      await auth.verifyOtp(phone: '+13334445555', code: '123456');

      await auth.signOut();

      final current = await auth.getCurrentUser();
      expect(current, isNull);
    });

    test('OTP verification with correct code succeeds', () async {
      await auth.sendOtp('+14445556666');
      final user = await auth.verifyOtp(phone: '+14445556666', code: '123456');
      expect(user, isNotNull);
      expect(user.phoneNumber, '+14445556666');
    });

    test('OTP verification with wrong code fails', () async {
      await auth.sendOtp('+15556667777');
      expect(
        () => auth.verifyOtp(phone: '+15556667777', code: '999999'),
        throwsA(isA<AuthException>()),
      );
    });

    test('restoreSession returns false on fresh start with no session',
        () async {
      final restored = await auth.restoreSession();
      expect(restored, isFalse);
    });

    test('getCurrentUser returns user after signIn', () async {
      await auth.sendOtp('+16667778888');
      final signedIn =
          await auth.verifyOtp(phone: '+16667778888', code: '123456');
      final current = await auth.getCurrentUser();
      expect(current!.id, signedIn.id);
    });

    test('verifyOtp without sendOtp first throws AuthException', () async {
      expect(
        () => auth.verifyOtp(phone: '+13334445555', code: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('signInWithPhone creates new session directly', () async {
      final user = await auth.signInWithPhone('+17778889999');
      expect(user, isNotNull);

      final current = await auth.getCurrentUser();
      expect(current!.id, user.id);
    });

    test('authStateChanges emits user on signIn and null on signOut', () async {
      final states = <Object?>[];
      final sub = auth.authStateChanges.listen((u) => states.add(u?.id));

      await auth.sendOtp('+13334445555');
      await auth.verifyOtp(phone: '+13334445555', code: '123456');
      await auth.signOut();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      sub.cancel();

      // First emission is current state (null), then user, then null after signOut.
      expect(states, isNotEmpty);
      expect(states.any((s) => s != null), isTrue,
          reason: 'Should have emitted a user ID after sign-in');
      expect(states.last, isNull, reason: 'Last state after signOut is null');
    });
  });
}
