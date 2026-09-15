import 'package:earth_nova/ui/product_surfaces/map/platform/base_map_settled_signal.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/base_map_style_loaded_signal.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/map_level_gesture_bridge.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/maplibre_platform_view_visibility_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VM map platform fallbacks', () {
    test('style and settled signals stay passive through disposal', () {
      final loadedSources = <String>[];
      final settledSources = <String>[];
      final styleSignal = BaseMapStyleLoadedSignal(
        onLoaded: loadedSources.add,
      );
      final settledSignal = BaseMapSettledSignal(
        onSettled: settledSources.add,
      );

      styleSignal.dispose();
      settledSignal.dispose();

      expect(loadedSources, isEmpty);
      expect(settledSources, isEmpty);
      expect(BaseMapStyleLoadedSignal.eventName, isNotEmpty);
      expect(BaseMapSettledSignal.eventName, isNotEmpty);
    });

    test('visibility and gesture bridges are no-op fallbacks on the VM', () {
      final pinchEvents = <(String, String)>[];
      final visibilityBridge = MapLibrePlatformViewVisibilityBridge();
      final gestureBridge = MapLevelGestureBridge(
        onPinch: (direction, source) => pinchEvents.add((direction, source)),
      );

      visibilityBridge.setVisible(false);
      visibilityBridge.setVisible(false);
      visibilityBridge.setVisible(true);
      visibilityBridge.setVisible(true);
      visibilityBridge.dispose();
      gestureBridge.dispose();

      expect(pinchEvents, isEmpty);
      expect(
        MapLibrePlatformViewVisibilityBridge.showEventName,
        isNot(MapLibrePlatformViewVisibilityBridge.hideEventName),
      );
      expect(MapLevelGestureBridge.closeEventName, isNotEmpty);
      expect(MapLevelGestureBridge.spreadEventName, isNotEmpty);
    });
  });
}
