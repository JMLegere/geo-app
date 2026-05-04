import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthException stringifies with message', () {
    expect(
      const AuthException('bad credentials').toString(),
      'AuthException: bad credentials',
    );
  });

  test('auth event types preserve payloads', () {
    final user = UserProfile(
      id: 'u1',
      phone: '+15551234567',
      displayName: 'Jeremy',
      createdAt: DateTime.utc(2026, 5, 4),
    );

    final changed = AuthStateChanged(user);
    const expired = AuthSessionExpired();
    const externalSignOut = AuthExternalSignOut();

    expect(changed.user, user);
    expect(expired, isA<AuthEvent>());
    expect(externalSignOut, isA<AuthEvent>());
  });
}
