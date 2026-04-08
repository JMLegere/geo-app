import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class MapRootScreen extends ConsumerStatefulWidget {
  const MapRootScreen({super.key});

  @override
  ConsumerState<MapRootScreen> createState() => _MapRootScreenState();
}

class _MapRootScreenState extends ConsumerState<MapRootScreen> {
  static const _kPinchCloseThreshold = 0.92;
  static const _kPinchSpreadThreshold = 1.08;

  late final List<Widget> _levelScreens;
  double _lastScale = 1;

  @override
  void initState() {
    super.initState();
    _levelScreens = const [
      MapScreen(),
      _MapHierarchyLevelScreen(level: MapLevel.district),
      _MapHierarchyLevelScreen(level: MapLevel.city),
      _MapHierarchyLevelScreen(level: MapLevel.state),
      _MapHierarchyLevelScreen(level: MapLevel.country),
      _MapHierarchyLevelScreen(level: MapLevel.world),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(mapLevelProvider);
    final notifier = ref.read(mapLevelProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (_) {
        _lastScale = 1;
      },
      onScaleUpdate: (details) {
        _lastScale = details.scale;
      },
      onScaleEnd: (_) {
        if (_lastScale <= _kPinchCloseThreshold) {
          notifier.pinchClose();
          return;
        }

        if (_lastScale >= _kPinchSpreadThreshold) {
          notifier.pinchSpread();
        }
      },
      child: IndexedStack(
        index: level.index,
        children: _levelScreens,
      ),
    );
  }
}

class _MapHierarchyLevelScreen extends StatelessWidget {
  const _MapHierarchyLevelScreen({required this.level});

  final MapLevel level;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: Center(
        child: Text(
          level.name.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
