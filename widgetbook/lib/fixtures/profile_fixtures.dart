import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:riverpod/misc.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';

List<Override> settingsStoryOverrides({
  required bool debugMode,
  required bool desktopControlsAvailable,
}) {
  return [
    ...authStoryOverrides(),
    debugModeProvider.overrideWith(() => StoryDebugModeNotifier(debugMode)),
    desktopControlsAvailableProvider.overrideWithValue(
      desktopControlsAvailable,
    ),
    desktopControlsProvider.overrideWith(
      () => StoryDesktopControlsNotifier(enabled: false),
    ),
  ];
}

final class StoryDebugModeNotifier extends DebugModeNotifier {
  StoryDebugModeNotifier(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;

  @override
  void toggle() => state = !state;
}

final class StoryDesktopControlsNotifier extends DesktopControlsNotifier {
  StoryDesktopControlsNotifier({required this.enabled});

  final bool enabled;

  @override
  bool build() => enabled;

  @override
  void setEnabled(bool value) => state = value;
}
