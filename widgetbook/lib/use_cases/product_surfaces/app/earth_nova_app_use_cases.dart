import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/ui/product_surfaces/app/earth_nova_app.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/profile_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/system_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Product Surfaces]/App';

Widget _appRootStory(AuthState authState) => ProviderScope(
  overrides: [
    ...authStoryOverrides(state: authState),
    debugModeProvider.overrideWith(() => StoryDebugModeNotifier(false)),
  ],
  child: const EarthNovaApp(),
);

Widget _appRootPreparingStory() => ProviderScope(
  overrides: appRootPreparingStoryOverrides(),
  child: const EarthNovaApp(),
);

@widgetbook.UseCase(name: '00 Happy Path', type: EarthNovaApp, path: _path)
Widget earthNovaAppHappyPath(BuildContext context) =>
    _appRootStory(const AuthState.unauthenticated());

@widgetbook.UseCase(
  name: '10 Restoring Session',
  type: EarthNovaApp,
  path: _path,
)
Widget earthNovaAppRestoringSession(BuildContext context) =>
    _appRootStory(const AuthState.loading());

@widgetbook.UseCase(
  name: '20 Authentication Error',
  type: EarthNovaApp,
  path: _path,
)
Widget earthNovaAppAuthenticationError(BuildContext context) => _appRootStory(
  const AuthState.error('Your session has expired. Sign in again.'),
);

@widgetbook.UseCase(name: '30 Preparing World', type: EarthNovaApp, path: _path)
Widget earthNovaAppPreparingWorld(BuildContext context) =>
    _appRootPreparingStory();
