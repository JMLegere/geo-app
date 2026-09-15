import 'package:earth_nova/ui/product_surfaces/profile/screens/settings_screen.dart';
import 'package:earth_nova_widgetbook/fixtures/profile_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: SettingsScreen,
  path: '[Product Surfaces]/Profile',
)
Widget settingsScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: settingsStoryOverrides(
    debugMode: false,
    desktopControlsAvailable: false,
  ),
  child: const SettingsScreen(),
);

@widgetbook.UseCase(
  name: '10 Developer Mode Enabled',
  type: SettingsScreen,
  path: '[Product Surfaces]/Profile',
)
Widget settingsScreenDeveloperModeEnabled(BuildContext context) =>
    earthNovaStory(
      overrides: settingsStoryOverrides(
        debugMode: true,
        desktopControlsAvailable: false,
      ),
      child: const SettingsScreen(),
    );

@widgetbook.UseCase(
  name: '20 Desktop Controls Available',
  type: SettingsScreen,
  path: '[Product Surfaces]/Profile',
)
Widget settingsScreenDesktopControlsAvailable(BuildContext context) =>
    earthNovaStory(
      overrides: settingsStoryOverrides(
        debugMode: false,
        desktopControlsAvailable: true,
      ),
      child: const SettingsScreen(),
    );

@widgetbook.UseCase(
  name: '30 Sign Out Dialog',
  type: SettingsScreen,
  path: '[Product Surfaces]/Profile',
)
Widget settingsScreenSignOutDialog(BuildContext context) => earthNovaStory(
  overrides: settingsStoryOverrides(
    debugMode: false,
    desktopControlsAvailable: false,
  ),
  child: const _SettingsSignOutDialogStory(),
);

class _SettingsSignOutDialogStory extends StatefulWidget {
  const _SettingsSignOutDialogStory();

  @override
  State<_SettingsSignOutDialogStory> createState() =>
      _SettingsSignOutDialogStoryState();
}

class _SettingsSignOutDialogStoryState
    extends State<_SettingsSignOutDialogStory> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visitDescendants(context, (element) {
        final widget = element.widget;
        if (widget is OutlinedButton) widget.onPressed?.call();
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

void _visitDescendants(
  BuildContext context,
  void Function(Element element) visit,
) {
  void walk(Element element) {
    visit(element);
    element.visitChildElements(walk);
  }

  context.visitChildElements(walk);
}
