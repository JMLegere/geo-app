import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  late final List<Widget> _levelScreens;
  double _lastScale = 1;

  @override
  void initState() {
    super.initState();
    _levelScreens = const [
      MapScreen(),
      DistrictScreen(),
      CityScreen(),
      ProvinceScreen(),
      CountryScreen(),
      WorldScreen(),
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
