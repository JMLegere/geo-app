import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/services/auth_service.dart';

import '../../../fixtures/auth_test_doubles.dart';

void main() {
  group('FakeAuthService', () {
    late FakeAuthService service;

    setUp(() {
      service = FakeAuthService();
    });

    tearDown(() {
      service.dispose();
    });

    // ── sendOtp ──────────────────────────────────────────────────────────────

    test('sendOtp succeeds for valid E.164 phone number', () async {
      await expectLater(
        service.sendOtp('+15551234567'),
        completes,
      );
    });

    test('sendOtp throws AuthException for invalid phone (no + prefix)',
        () async {
      await expectLater(
        service.sendOtp('5551234567'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('E.164'),
          ),
        ),
      );
    });

    test('sendOtp throws AuthException for short phone number', () async {
      await expectLater(
        service.sendOtp('+123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('sendOtp throws when shouldThrow is true', () async {
      service.shouldThrow = true;
      service.throwMessage = 'OTP send failed';

      await expectLater(
        service.sendOtp('+15551234567'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('OTP send failed'),
          ),
        ),
      );
    });

    // ── verifyOtp ────────────────────────────────────────────────────────────

    test('verifyOtp succeeds with correct code after sendOtp', () async {
      await service.sendOtp('+15551234567');

      final profile = await service.verifyOtp(
        phone: '+15551234567',
        code: '123456',
      );

      expect(profile.phoneNumber, '+15551234567');
      expect(profile.id, isNotEmpty);
    });

    test('verifyOtp throws for wrong OTP code', () async {
      await service.sendOtp('+15551234567');

      await expectLater(
        service.verifyOtp(phone: '+15551234567', code: '000000'),
        throwsA(isA<AuthException>()),
      );
    });

    test('verifyOtp throws when no OTP was sent first', () async {
      await expectLater(
        service.verifyOtp(phone: '+15551234567', code: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('verifyOtp throws when shouldThrow is true', () async {
      await service.sendOtp('+15551234567');
      service.shouldThrow = true;

      await expectLater(
        service.verifyOtp(phone: '+15551234567', code: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('verifyOtp returns same profile for existing phone number', () async {
      await service.sendOtp('+15551234567');
      final first = await service.verifyOtp(
        phone: '+15551234567',
        code: '123456',
      );

      // Sign out and re-verify same number.
      await service.signOut();
      await service.sendOtp('+15551234567');
      final second = await service.verifyOtp(
        phone: '+15551234567',
        code: '123456',
      );

      expect(second.id, first.id);
      expect(second.phoneNumber, first.phoneNumber);
    });

    // ── signOut ──────────────────────────────────────────────────────────────

    test('signOut clears session', () async {
      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');
      expect(await service.getCurrentUser(), isNotNull);

      await service.signOut();

      expect(await service.getCurrentUser(), isNull);
    });

    // ── getCurrentUser ───────────────────────────────────────────────────────

    test('getCurrentUser returns null when not logged in', () async {
      final user = await service.getCurrentUser();
      expect(user, isNull);
    });

    test('getCurrentUser returns user after verifyOtp', () async {
      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');

      final user = await service.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.phoneNumber, '+15551234567');
    });

    // ── restoreSession ───────────────────────────────────────────────────────

    test('restoreSession returns false when not logged in', () async {
      expect(await service.restoreSession(), isFalse);
    });

    test('restoreSession returns true after verifyOtp', () async {
      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');

      expect(await service.restoreSession(), isTrue);
    });

    test('restoreSession returns false after signOut', () async {
      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');
      await service.signOut();

      expect(await service.restoreSession(), isFalse);
    });

    // ── authStateChanges ─────────────────────────────────────────────────────

    test('authStateChanges emits initial null when not logged in', () async {
      final events = <Object?>[];
      final sub = service.authStateChanges.listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.first, isNull);
    });

    test('authStateChanges emits user on verifyOtp and null on signOut',
        () async {
      final events = <Object?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');
      await service.signOut();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      // Initial null + verifyOtp profile + signOut null.
      expect(events.length, greaterThanOrEqualTo(3));
      expect(events.first, isNull); // initial state
      expect(events.last, isNull); // after signOut
    });

    test('authStateChanges emits user on verifyOtp', () async {
      final events = <Object?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.sendOtp('+15551234567');
      await service.verifyOtp(phone: '+15551234567', code: '123456');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.last, isNotNull);
    });

    // ── setAuthenticated helper ───────────────────────────────────────────────

    test('setAuthenticated() sets current user to kTestUser', () async {
      service.setAuthenticated();

      final user = await service.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, kTestUser.id);
    });

    test('setAuthenticated() accepts custom user', () async {
      service.setAuthenticated(kTestUser);

      final user = await service.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.phoneNumber, kTestUser.phoneNumber);
    });
  });
}
