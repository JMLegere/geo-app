import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/iucn_status.dart';

void main() {
  group('IucnStatus', () {
    test('fromString matches by name', () {
      expect(IucnStatus.fromString('leastConcern'), IucnStatus.leastConcern);
      expect(IucnStatus.fromString('endangered'), IucnStatus.endangered);
    });

    test('fromString matches by code', () {
      expect(IucnStatus.fromString('LC'), IucnStatus.leastConcern);
      expect(IucnStatus.fromString('EN'), IucnStatus.endangered);
      expect(IucnStatus.fromString('CR'), IucnStatus.criticallyEndangered);
    });

    test('fromString is case-insensitive', () {
      expect(IucnStatus.fromString('lc'), IucnStatus.leastConcern);
      expect(IucnStatus.fromString('LeastConcern'), IucnStatus.leastConcern);
    });

    test('fromString returns null for unknown', () {
      expect(IucnStatus.fromString('unknown'), isNull);
      expect(IucnStatus.fromString(null), isNull);
    });

    test('code and displayName are correct', () {
      expect(IucnStatus.leastConcern.code, 'LC');
      expect(IucnStatus.leastConcern.displayName, 'Least Concern');
      expect(IucnStatus.criticallyEndangered.code, 'CR');
      expect(IucnStatus.extinct.code, 'EX');
    });

    test('all statuses have color properties', () {
      for (final status in IucnStatus.values) {
        expect(status.color, isNotNull, reason: '${status.name} missing color');
        expect(status.fgColor, isNotNull,
            reason: '${status.name} missing fgColor');
        expect(status.borderAlpha, greaterThanOrEqualTo(0.0));
        expect(status.borderAlpha, lessThanOrEqualTo(1.0));
        expect(status.glowAlpha, greaterThanOrEqualTo(0.0));
        expect(status.glowAlpha, lessThanOrEqualTo(1.0));
      }
    });

    test('CR has highest glow, LC/NT/EX have none', () {
      expect(IucnStatus.criticallyEndangered.glowAlpha, greaterThan(0));
      expect(IucnStatus.endangered.glowAlpha, greaterThan(0));
      expect(IucnStatus.vulnerable.glowAlpha, greaterThan(0));
      expect(IucnStatus.nearThreatened.glowAlpha, 0.0);
      expect(IucnStatus.leastConcern.glowAlpha, 0.0);
      expect(IucnStatus.extinct.glowAlpha, 0.0);
    });

    test('rarity sort order: CR > EN > VU > NT > LC by borderAlpha', () {
      expect(IucnStatus.criticallyEndangered.borderAlpha,
          greaterThan(IucnStatus.endangered.borderAlpha));
      expect(IucnStatus.endangered.borderAlpha,
          greaterThan(IucnStatus.vulnerable.borderAlpha));
      expect(IucnStatus.vulnerable.borderAlpha,
          greaterThan(IucnStatus.nearThreatened.borderAlpha));
      expect(IucnStatus.nearThreatened.borderAlpha,
          greaterThan(IucnStatus.leastConcern.borderAlpha));
    });
  });

  group('AuthState', () {
    test('loading has correct status', () {
      const state = AuthState.loading();
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    test('unauthenticated has correct status', () {
      const state = AuthState.unauthenticated();
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
    });

    test('authenticated has user', () {
      final user = _testUser();
      final state = AuthState.authenticated(user);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, user);
      expect(state.errorMessage, isNull);
    });

    test('error has message', () {
      const state = AuthState.error('Network error');
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Network error');
      expect(state.user, isNull);
    });

    test('when maps all states', () {
      const loading = AuthState.loading();
      const unauth = AuthState.unauthenticated();
      final auth = AuthState.authenticated(_testUser());
      const err = AuthState.error('fail');

      expect(
          loading.when(
            loading: () => 'L',
            unauthenticated: () => 'U',
            authenticated: (_) => 'A',
            error: (_) => 'E',
          ),
          'L');

      expect(
          unauth.when(
            loading: () => 'L',
            unauthenticated: () => 'U',
            authenticated: (_) => 'A',
            error: (_) => 'E',
          ),
          'U');

      expect(
          auth.when(
            loading: () => 'L',
            unauthenticated: () => 'U',
            authenticated: (_) => 'A',
            error: (_) => 'E',
          ),
          'A');

      expect(
          err.when(
            loading: () => 'L',
            unauthenticated: () => 'U',
            authenticated: (_) => 'A',
            error: (_) => 'E',
          ),
          'E');
    });

    test('equality works', () {
      const a = AuthState.loading();
      const b = AuthState.loading();
      const c = AuthState.unauthenticated();
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });
  });

  group('UserProfile', () {
    test('construction and equality', () {
      final u1 = _testUser();
      final u2 = _testUser();
      expect(u1 == u2, isTrue);
    });

    test('copyWith replaces fields', () {
      final u1 = _testUser();
      final u2 = u1.copyWith(displayName: 'NewName');
      expect(u2.displayName, 'NewName');
      expect(u2.id, u1.id); // unchanged
    });

    test('copyWith preserves original when null', () {
      final u1 = _testUser();
      final u2 = u1.copyWith();
      expect(u2 == u1, isTrue);
    });

    test('JSON round-trip', () {
      final u1 = _testUser();
      final json = u1.toJson();
      final u2 = UserProfile.fromJson(json);
      expect(u1, u2);
    });

    test('fromJson handles null optionals', () {
      final json = {
        'id': 'u_1',
        'phone': '+15551234567',
        'created_at': '2026-01-01T00:00:00Z',
      };
      final user = UserProfile.fromJson(json);
      expect(user.displayName, isNull);
      expect(user.phone, '+15551234567');
    });
  });
}

UserProfile _testUser() => UserProfile(
      id: 'u_1',
      phone: '+15551234567',
      displayName: 'TestExplorer',
      createdAt: DateTime(2026, 1, 1),
    );
