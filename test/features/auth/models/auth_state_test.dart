import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';

void main() {
  group('AuthState.isAnonymous', () {
    test('isAnonymous returns true for anonymous user', () {
      final profile = UserProfile(
        id: 'anon-123',
        email: '',
        displayName: 'Explorer',
        createdAt: DateTime(2024, 1, 1),
        isAnonymous: true,
      );

      final state = AuthState.authenticated(profile);

      expect(state.isAnonymous, isTrue);
    });

    test('isAnonymous returns false for email user', () {
      final profile = UserProfile(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
        isAnonymous: false,
      );

      final state = AuthState.authenticated(profile);

      expect(state.isAnonymous, isFalse);
    });

    test('isAnonymous returns false when no user', () {
      final state = AuthState.unauthenticated();

      expect(state.isAnonymous, isFalse);
    });
  });
}
