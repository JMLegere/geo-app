import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/city_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/country_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/district_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/province_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/world_screen.dart';

class MapRootScreen extends ConsumerStatefulWidget {
  const MapRootScreen({super.key});

  @override
  ConsumerState<MapRootScreen> createState() => _MapRootScreenState();
}

class _MapRootScreenState extends ConsumerState<MapRootScreen> {
  static const _kPinchCloseThreshold = 0.92;
  static const _kPinchSpreadThreshold = 1.08;

  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(mapLevelProvider);
    final notifier = ref.read(mapLevelProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onScaleStart: (_) => _lastScale = 1,
      onScaleUpdate: (details) => _lastScale = details.scale,
      onScaleEnd: (_) {
        if (_lastScale <= _kPinchCloseThreshold) {
          notifier.pinchClose();
          return;
        }
        if (_lastScale >= _kPinchSpreadThreshold) {
          notifier.pinchSpread();
        }
      },
      child: Stack(
        children: [
          // MapScreen stays mounted at all times so WebGL context is preserved.
          Offstage(
            offstage: level != MapLevel.cell,
            child: const MapScreen(),
          ),
          // Hierarchy screens are only mounted when active.
          if (level != MapLevel.cell)
            Positioned.fill(
              child: switch (level) {
                MapLevel.district => const DistrictScreen(),
                MapLevel.city => const CityScreen(),
                MapLevel.state => const ProvinceScreen(),
                MapLevel.country => const CountryScreen(),
                MapLevel.world => const WorldScreen(),
                MapLevel.cell => const SizedBox.shrink(),
              },
            ),
        ],
      ),
    );
  }
}
