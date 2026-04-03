import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/models/fog_state.dart';
import 'package:earth_nova/providers/cell_provider.dart';
import 'package:earth_nova/providers/fog_provider.dart';

// ---------------------------------------------------------------------------
// Minimal CellService mock to satisfy fogResolverProvider dependency.
// ---------------------------------------------------------------------------

class _StubCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => 'v_0_0';
  @override
  Geographic getCellCenter(String cellId) => Geographic(lat: 0, lon: 0);
  @override
  List<Geographic> getCellBoundary(String cellId) => [];
  @override
  List<String> getNeighborIds(String cellId) => [];
  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];
  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];
  @override
  double get cellEdgeLengthMeters => 180.0;
  @override
  String get systemName => 'stub';
}

void main() {
  group('FogNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Override the real Voronoi cell service with a stub so we don't
          // need FFI/native libraries in unit tests.
          cellServiceProvider.overrideWithValue(_StubCellService()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('initial fog map is empty', () {
      expect(container.read(fogProvider), isEmpty);
    });

    test('updateFog adds entries to the map', () {
      container.read(fogProvider.notifier).updateFog({
        'v_1': FogState.explored,
        'v_2': FogState.nearby,
      });

      final fog = container.read(fogProvider);
      expect(fog['v_1'], FogState.explored);
      expect(fog['v_2'], FogState.nearby);
    });

    test('updateFog overwrites existing entries', () {
      container.read(fogProvider.notifier).updateFog({'v_1': FogState.unknown});
      container.read(fogProvider.notifier).updateFog({'v_1': FogState.present});

      expect(container.read(fogProvider)['v_1'], FogState.present);
    });

    test('clear resets to empty map', () {
      container
          .read(fogProvider.notifier)
          .updateFog({'v_1': FogState.explored});
      container.read(fogProvider.notifier).clear();

      expect(container.read(fogProvider), isEmpty);
    });

    test('fog state accessible by cell ID', () {
      container.read(fogProvider.notifier).updateFog({
        'cell_abc': FogState.detected,
      });

      expect(container.read(fogProvider)['cell_abc'], FogState.detected);
      expect(container.read(fogProvider)['cell_missing'], isNull);
    });

    test('replaceAll replaces entire map', () {
      container.read(fogProvider.notifier).updateFog({
        'old_1': FogState.unknown,
        'old_2': FogState.explored,
      });

      container.read(fogProvider.notifier).replaceAll({
        'new_1': FogState.present,
      });

      final fog = container.read(fogProvider);
      expect(fog.containsKey('old_1'), isFalse);
      expect(fog['new_1'], FogState.present);
    });
  });
}
