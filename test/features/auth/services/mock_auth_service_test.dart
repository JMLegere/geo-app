import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/services/auth_service.dart';
import 'package:fog_of_world/features/auth/services/mock_auth_service.dart';

void main() {
  group('MockAuthService', () {
    late MockAuthService service;

    setUp(() {
      service = MockAuthService();
    });

    tearDown(() {
      service.dispose();
    });

    // ── signUp ───────────────────────────────────────────────────────────────

    test('signUp creates user and returns profile with correct email',
        () async {
      final profile = await service.signUp(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(profile.email, 'test@example.com');
      expect(profile.id, isNotEmpty);
    });

    test('signUp stores displayName when provided', () async {
      final profile = await service.signUp(
        email: 'test@example.com',
        password: 'password123',
        displayName: 'Explorer',
      );

      expect(profile.displayName, 'Explorer');
    });

    test('signUp with duplicate email throws AuthException', () async {
      await service.signUp(email: 'dupe@example.com', password: 'pass123');

      await expectLater(
        service.signUp(email: 'dupe@example.com', password: 'other'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          ),
        ),
      );
    });

    test('signUp with invalid email format throws AuthException', () async {
      await expectLater(
        service.signUp(email: 'not-an-email', password: 'pass123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Invalid email format'),
          ),
        ),
      );
    });

    test('signUp with missing @ throws AuthException', () async {
      await expectLater(
        service.signUp(email: 'bademail.com', password: 'pass123'),
        throwsA(isA<AuthException>()),
      );
    });

    // ── signIn ───────────────────────────────────────────────────────────────

    test('signIn with valid credentials returns profile', () async {
      await service.signUp(email: 'user@example.com', password: 'secret');

      final profile =
          await service.signIn(email: 'user@example.com', password: 'secret');

      expect(profile.email, 'user@example.com');
      expect(profile, isA<UserProfile>());
    });

    test('signIn with wrong password throws AuthException', () async {
      await service.signUp(email: 'user@example.com', password: 'correct');

      await expectLater(
        service.signIn(email: 'user@example.com', password: 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Wrong password'),
          ),
        ),
      );
    });

    test('signIn with unknown email throws AuthException', () async {
      await expectLater(
        service.signIn(email: 'ghost@example.com', password: 'pass'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('User not found'),
          ),
        ),
      );
    });

    // ── signOut ──────────────────────────────────────────────────────────────

    test('signOut clears session', () async {
      await service.signUp(email: 'user@example.com', password: 'pass');
      expect(await service.isSessionValid(), isTrue);

      await service.signOut();

      expect(await service.isSessionValid(), isFalse);
      expect(await service.getCurrentUser(), isNull);
    });

    // ── getCurrentUser ───────────────────────────────────────────────────────

    test('getCurrentUser returns null when not logged in', () async {
      final user = await service.getCurrentUser();
      expect(user, isNull);
    });

    test('getCurrentUser returns user after signIn', () async {
      await service.signUp(email: 'user@example.com', password: 'pass');
      await service.signOut();

      await service.signIn(email: 'user@example.com', password: 'pass');

      final user = await service.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.email, 'user@example.com');
    });

    // ── isSessionValid ───────────────────────────────────────────────────────

    test('isSessionValid returns false when not logged in', () async {
      expect(await service.isSessionValid(), isFalse);
    });

    test('isSessionValid returns true after signIn', () async {
      await service.signUp(email: 'user@example.com', password: 'pass');

      expect(await service.isSessionValid(), isTrue);
    });

    // ── authStateChanges ─────────────────────────────────────────────────────

    test('authStateChanges emits user on signIn and null on signOut', () async {
      final events = <UserProfile?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.signUp(email: 'u@example.com', password: 'pw');
      await service.signOut();

      // Allow broadcast stream events to deliver.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();

      // signUp emits a profile, signOut emits null.
      expect(events.length, 2);
      expect(events[0], isNotNull);
      expect(events[0]!.email, 'u@example.com');
      expect(events[1], isNull);
    });

    test('authStateChanges emits user on signIn', () async {
      await service.signUp(email: 'u@example.com', password: 'pw');
      await service.signOut();

      final events = <UserProfile?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.signIn(email: 'u@example.com', password: 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.last, isNotNull);
      expect(events.last!.email, 'u@example.com');
    });

    // ── upgradeWithEmail ─────────────────────────────────────────────────────

    test('upgradeWithEmail preserves id and sets isAnonymous to false', () async {
      final anon = await service.signInAnonymously();
      expect(anon.isAnonymous, isTrue);

      final upgraded = await service.upgradeWithEmail(
        email: 'user@example.com',
        password: 'pass123',
      );

      expect(upgraded.id, anon.id);
      expect(upgraded.email, 'user@example.com');
      expect(upgraded.isAnonymous, isFalse);
    });

    test('upgradeWithEmail updates displayName when provided', () async {
      await service.signInAnonymously();

      final upgraded = await service.upgradeWithEmail(
        email: 'user@example.com',
        password: 'pass123',
        displayName: 'Named User',
      );

      expect(upgraded.displayName, 'Named User');
    });

    test('upgradeWithEmail preserves displayName when not provided', () async {
      final anon = await service.signInAnonymously();

      final upgraded = await service.upgradeWithEmail(
        email: 'user@example.com',
        password: 'pass123',
      );

      expect(upgraded.displayName, anon.displayName);
    });

    test('upgradeWithEmail throws when not anonymous', () async {
      await service.signUp(email: 'user@example.com', password: 'pass');

      await expectLater(
        service.upgradeWithEmail(email: 'other@example.com', password: 'pass'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('already upgraded'),
          ),
        ),
      );
    });

    test('upgradeWithEmail throws for invalid email', () async {
      await service.signInAnonymously();

      await expectLater(
        service.upgradeWithEmail(email: 'not-valid', password: 'pass'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Invalid email'),
          ),
        ),
      );
    });

    test('upgradeWithEmail throws for duplicate email', () async {
      await service.signUp(email: 'taken@example.com', password: 'pass');
      await service.signOut();

      // Sign in as a new anonymous user
      await service.signInAnonymously();

      await expectLater(
        service.upgradeWithEmail(email: 'taken@example.com', password: 'pass'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          ),
        ),
      );
    });

    test('upgradeWithEmail throws when no user signed in', () async {
      await expectLater(
        service.upgradeWithEmail(email: 'user@example.com', password: 'pass'),
        throwsA(isA<AuthException>()),
      );
    });

    test('upgradeWithEmail emits updated profile on authStateChanges', () async {
      await service.signInAnonymously();

      final events = <UserProfile?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.upgradeWithEmail(
        email: 'user@example.com',
        password: 'pass',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.last, isNotNull);
      expect(events.last!.isAnonymous, isFalse);
      expect(events.last!.email, 'user@example.com');
    });

    // ── linkOAuthIdentity ────────────────────────────────────────────────────

    test('linkOAuthIdentity preserves id and sets isAnonymous to false', () async {
      final anon = await service.signInAnonymously();

      final upgraded = await service.linkOAuthIdentity(provider: 'google');

      expect(upgraded.id, anon.id);
      expect(upgraded.isAnonymous, isFalse);
    });

    test('linkOAuthIdentity throws when not anonymous', () async {
      await service.signUp(email: 'user@example.com', password: 'pass');

      await expectLater(
        service.linkOAuthIdentity(provider: 'google'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('already upgraded'),
          ),
        ),
      );
    });

    test('linkOAuthIdentity throws when no user signed in', () async {
      await expectLater(
        service.linkOAuthIdentity(provider: 'google'),
        throwsA(isA<AuthException>()),
      );
    });

    test('linkOAuthIdentity emits updated profile on authStateChanges', () async {
      await service.signInAnonymously();

      final events = <UserProfile?>[];
      final sub = service.authStateChanges.listen(events.add);

      await service.linkOAuthIdentity(provider: 'apple');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(events, isNotEmpty);
      expect(events.last, isNotNull);
      expect(events.last!.isAnonymous, isFalse);
    });
  });
}
