import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';

UserProfile _user(String id) => UserProfile(
      id: id,
      phone: '5555555555',
      createdAt: DateTime(2026),
    );

Future<void> _emitUser(
  MockAuthRepository auth,
  UserProfile? user,
) async {
  auth.emitEvent(AuthStateChanged(user));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('desktopControlsAvailableFor', () {
    test('allows desktop web platforms when the build enables controls', () {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          desktopControlsAvailableFor(
            buildEnabled: true,
            isWeb: true,
            platform: platform,
          ),
          isTrue,
        );
      }
    });

    test('keeps mobile web and native clients on their existing input', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          desktopControlsAvailableFor(
            buildEnabled: true,
            isWeb: true,
            platform: platform,
          ),
          isFalse,
        );
      }
      expect(
        desktopControlsAvailableFor(
          buildEnabled: true,
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        isFalse,
      );
    });
  });

  group('DesktopControlsNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ordinary builds are unavailable and cannot enable controls', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(desktopControlsAvailableProvider), isFalse);
      expect(container.read(desktopControlsProvider), isFalse);

      container.read(desktopControlsProvider.notifier).setEnabled(true);

      expect(container.read(desktopControlsProvider), isFalse);
    });

    test('persists controls independently for each authenticated account',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final auth = MockAuthRepository();
      final observability = ObservabilityService(sessionId: 'test-session');
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          observabilityProvider.overrideWithValue(observability),
          appObservabilityProvider.overrideWithValue(observability),
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopControlsAvailableProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.dispose);

      container.read(desktopControlsProvider);
      await _emitUser(auth, _user('explorer-a'));
      container.read(desktopControlsProvider.notifier).setEnabled(true);

      expect(container.read(desktopControlsProvider), isTrue);
      expect(
        prefs.getBool('desktop_controls_enabled.unknown.explorer-a'),
        isTrue,
      );

      await _emitUser(auth, null);
      expect(container.read(desktopControlsProvider), isFalse);

      await _emitUser(auth, _user('explorer-b'));
      expect(container.read(desktopControlsProvider), isFalse);

      await _emitUser(auth, _user('explorer-a'));
      expect(container.read(desktopControlsProvider), isTrue);
    });
  });
}
