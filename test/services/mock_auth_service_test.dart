import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/services/auth_service.dart';
import 'package:earth_nova/services/mock_auth_service.dart';

void main() {
  late MockAuthService service;

  setUp(() {
    service = MockAuthService();
  });

  tearDown(() {
    service.dispose();
  });

  group('MockAuthService', () {
    test('valid 10-digit phone returns UserProfile', () async {
      final user = await service.signInWithPhone('+15551234567');
      expect(user.id, 'mock_15551234567');
      expect(user.phone, '+15551234567');
      expect(user.displayName, 'MockExplorer');
    });

    test('phone with < 10 digits throws AuthException', () async {
      expect(
        () => service.signInWithPhone('+1123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('empty phone throws AuthException', () async {
      expect(
        () => service.signInWithPhone(''),
        throwsA(isA<AuthException>()),
      );
    });

    test('signOut clears user and emits null event', () async {
      await service.signInWithPhone('+15551234567');
      final events = <AuthEvent>[];
      final sub = service.authStateChanges.listen(events.add);
      await service.signOut();
      await Future<void>.delayed(Duration.zero); // let stream deliver
      expect(events.last, isA<AuthStateChanged>());
      expect((events.last as AuthStateChanged).user, isNull);
      await sub.cancel();
    });

    test('getCurrentUser returns user after sign-in', () async {
      await service.signInWithPhone('+15551234567');
      final user = await service.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, 'mock_15551234567');
    });

    test('getCurrentUser returns null before sign-in', () async {
      final user = await service.getCurrentUser();
      expect(user, isNull);
    });

    test('restoreSession returns false when no user', () async {
      final restored = await service.restoreSession();
      expect(restored, isFalse);
    });

    test('restoreSession returns true and emits event when user exists',
        () async {
      await service.signInWithPhone('+15551234567');
      final events = <AuthEvent>[];
      final sub = service.authStateChanges.listen(events.add);
      final restored = await service.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(restored, isTrue);
      expect(events.last, isA<AuthStateChanged>());
      expect((events.last as AuthStateChanged).user, isNotNull);
      await sub.cancel();
    });

    test('authStateChanges emits on sign-in', () async {
      final events = <AuthEvent>[];
      final sub = service.authStateChanges.listen(events.add);
      await service.signInWithPhone('+15551234567');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first, isA<AuthStateChanged>());
      expect((events.first as AuthStateChanged).user, isNotNull);
      await sub.cancel();
    });
  });
}
