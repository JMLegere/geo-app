import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/services/auth_service.dart';

void main() {
  group('AuthException', () {
    test('message is preserved', () {
      const e = AuthException('bad phone');
      expect(e.message, 'bad phone');
    });

    test('toString includes prefix', () {
      const e = AuthException('invalid');
      expect(e.toString(), 'AuthException: invalid');
    });
  });

  group('AuthEvent sealed classes', () {
    test('AuthStateChanged with user', () {
      const event = AuthStateChanged(null);
      expect(event.user, isNull);
      expect(event, isA<AuthEvent>());
    });

    test('AuthSessionExpired', () {
      const event = AuthSessionExpired();
      expect(event, isA<AuthEvent>());
    });

    test('AuthExternalSignOut', () {
      const event = AuthExternalSignOut();
      expect(event, isA<AuthEvent>());
    });
  });
}
