import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/platform/map_level_gesture_bridge.dart';
import 'package:earth_nova/features/map/presentation/platform/maplibre_platform_view_visibility_bridge.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/city_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/country_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/district_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/province_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/world_screen.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

class MapRootScreen extends ConsumerStatefulWidget {
  const MapRootScreen({super.key});

  @override
  ConsumerState<MapRootScreen> createState() => _MapRootScreenState();
}

class _MapRootScreenState extends ConsumerState<MapRootScreen> {
  static const _kPinchCloseThreshold = 0.92;
  static const _kPinchSpreadThreshold = 1.08;

  double _lastScale = 1;
  ProviderSubscription<MapLevel>? _mapLevelSubscription;
  MapLevelGestureBridge? _mapLevelGestureBridge;
  final MapLibrePlatformViewVisibilityBridge _platformViewVisibilityBridge =
      MapLibrePlatformViewVisibilityBridge();
  DateTime? _lastHandledPinchAt;
  String? _lastHandledPinchDirection;

  @override
  void initState() {
    super.initState();
    _mapLevelSubscription = ref.listenManual<MapLevel>(
      mapLevelProvider,
      (previous, next) {
        if (previous == null) return;
        ref.read(navigationScreenTransitionLoggerProvider).logScreenChanged(
              source: 'map_level',
              fromScreen: 'map.${previous.name}',
              toScreen: 'map.${next.name}',
            );
      },
    );
    _mapLevelGestureBridge = MapLevelGestureBridge(
      onPinch: (direction, source) {
        if (!mounted) return;
        _handlePinchDirection(direction, source: source);
      },
    );
  }

  @override
  void dispose() {
    _mapLevelSubscription?.close();
    _mapLevelGestureBridge?.dispose();
    _platformViewVisibilityBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obs = ref.watch(appObservabilityProvider);
    final level = ref.watch(mapLevelProvider);
    final mapState = ref.watch(mapProvider);
    final explorationState = ref.watch(explorationProvider);
    final hierarchyScopeId = hierarchyScopeIdForLevel(
      level: level,
      mapState: mapState,
      explorationState: explorationState,
    );
    _platformViewVisibilityBridge.setVisible(level == MapLevel.cell);
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      obs.log(event, category, data: data);
    }

    return ObservableScreen(
      screenName: 'map_root_screen',
      observability: obs,
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (_) => _lastScale = 1,
        onScaleUpdate: (details) => _lastScale = details.scale,
        onScaleEnd: ObservableInteraction.wrapScaleEnd(
          logger: logger,
          screenName: 'map_root_screen',
          widgetName: 'map_level_gesture_detector',
          actionType: 'pinch_level_change',
          payloadBuilder: (_) => {
            'gesture_direction': _pinchDirectionForScale(_lastScale),
            'source': 'flutter_scale_gesture',
          },
          callback: (_) {
            final direction = _pinchDirectionForScale(_lastScale);
            _handlePinchDirection(
              direction,
              source: 'flutter_scale_gesture',
              logInteraction: (_, __) {},
            );
          },
        ),
        child: Stack(
          children: [
            if (level == MapLevel.cell)
              Positioned.fill(child: const MapScreen()),
            // Hierarchy screens are only mounted when active.
            if (level != MapLevel.cell)
              Positioned.fill(
                child: switch (level) {
                  MapLevel.district =>
                    DistrictScreen(scopeId: hierarchyScopeId),
                  MapLevel.city => CityScreen(scopeId: hierarchyScopeId),
                  MapLevel.state => ProvinceScreen(scopeId: hierarchyScopeId),
                  MapLevel.country => CountryScreen(scopeId: hierarchyScopeId),
                  MapLevel.world => const WorldScreen(),
                  MapLevel.cell => const SizedBox.shrink(),
                },
              ),
          ],
        ),
      ),
    );
  }

  String _pinchDirectionForScale(double scale) {
    if (scale <= _kPinchCloseThreshold) return 'close';
    if (scale >= _kPinchSpreadThreshold) return 'spread';
    return 'none';
  }

  void _handlePinchDirection(
    String direction, {
    required String source,
    void Function(String direction, String source)? logInteraction,
  }) {
    if (direction != 'close' && direction != 'spread') return;
    if (_isDuplicatePinch(direction)) return;

    final notifier = ref.read(mapLevelProvider.notifier);
    (logInteraction ?? _logPinchInteraction).call(direction, source);
    if (direction == 'close') {
      notifier.pinchClose();
      return;
    }
    notifier.pinchSpread();
  }

  bool _isDuplicatePinch(String direction) {
    final now = DateTime.now();
    final lastAt = _lastHandledPinchAt;
    final isDuplicate = _lastHandledPinchDirection == direction &&
        lastAt != null &&
        now.difference(lastAt).inMilliseconds < 350;
    if (isDuplicate) return true;

    _lastHandledPinchDirection = direction;
    _lastHandledPinchAt = now;
    return false;
  }

  void _logPinchInteraction(String direction, String source) {
    ref.read(appObservabilityProvider).log(
          'interaction.action',
          'ui',
          data: ObservableInteraction.payload(
            actionType: 'pinch_level_change',
            screenName: 'map_root_screen',
            widgetName: 'map_level_gesture_detector',
            extra: {
              'gesture_direction': direction,
              'source': source,
            },
          ),
        );
  }
}

String? hierarchyScopeIdForLevel({
  required MapLevel level,
  required MapState mapState,
  required ExplorationStateData explorationState,
}) {
  if (level == MapLevel.cell || level == MapLevel.world) return null;
  if (mapState is! MapStateReady) return null;

  final currentCellId =
      explorationState.currentCellId ?? explorationState.lastEnteredCellId;
  if (currentCellId == null || currentCellId.trim().isEmpty) return null;

  for (final cell in mapState.cells) {
    if (cell.id != currentCellId) continue;
    final scopeId = switch (level) {
      MapLevel.district => cell.districtId,
      MapLevel.city => cell.cityId,
      MapLevel.state => cell.stateId,
      MapLevel.country => cell.countryId,
      MapLevel.cell || MapLevel.world => '',
    };
    final trimmed = scopeId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  return null;
}
