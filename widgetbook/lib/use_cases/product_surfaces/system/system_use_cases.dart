import 'package:earth_nova/ui/product_surfaces/system/stub_screen.dart';
import 'package:earth_nova/ui/product_surfaces/app/tab_shell.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:earth_nova_widgetbook/fixtures/system_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _tabScreens = [
  ColoredBox(
    color: Color(0xFF1E2A35),
    child: Center(child: Text('Map catalog surface')),
  ),
  ColoredBox(
    color: Color(0xFF27382D),
    child: Center(child: Text('Pack catalog surface')),
  ),
];

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: TabShell,
  path: '[Product Surfaces]/System',
)
Widget tabShellHappyPath(BuildContext context) => earthNovaStory(
  overrides: tabShellStoryOverrides(
    debugMode: false,
    desktopControlsAvailable: false,
  ),
  child: const TabShell(screens: _tabScreens),
);

@widgetbook.UseCase(
  name: '10 Debug Controls',
  type: TabShell,
  path: '[Product Surfaces]/System',
)
Widget tabShellDebugControls(BuildContext context) => earthNovaStory(
  overrides: tabShellStoryOverrides(
    debugMode: true,
    desktopControlsAvailable: false,
  ),
  child: const TabShell(screens: _tabScreens),
);

@widgetbook.UseCase(
  name: '20 Desktop Settings Access',
  type: TabShell,
  path: '[Product Surfaces]/System',
)
Widget tabShellDesktopSettingsAccess(BuildContext context) => earthNovaStory(
  overrides: tabShellStoryOverrides(
    debugMode: false,
    desktopControlsAvailable: true,
  ),
  child: const TabShell(screens: _tabScreens),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: StubScreen,
  path: '[Product Surfaces]/System',
)
Widget stubScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: systemStoryOverrides(),
  child: const StubScreen(label: 'Future tab'),
);

@widgetbook.UseCase(
  name: '10 Long Label',
  type: StubScreen,
  path: '[Product Surfaces]/System',
)
Widget stubScreenLongLabel(BuildContext context) => earthNovaStory(
  overrides: systemStoryOverrides(),
  child: const StubScreen(label: 'Expedition Archive'),
);
