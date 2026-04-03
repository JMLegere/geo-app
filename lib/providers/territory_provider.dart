import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/providers/detection_zone_provider.dart';
import 'package:earth_nova/providers/hierarchy_provider.dart';

/// Pre-computed territory data for map rendering.
/// Rebuilt when the detection zone changes.
class TerritoryState {
  /// District ancestry: districtId → (cityId, stateId, countryId)
  final Map<String, ({String? cityId, String? stateId, String? countryId})>
      ancestry;

  /// Cell → district attribution from detection zone
  final Map<String, String> cellDistrictIds;

  const TerritoryState({
    this.ancestry = const {},
    this.cellDistrictIds = const {},
  });
}

final territoryProvider = NotifierProvider<TerritoryNotifier, TerritoryState>(
    () => TerritoryNotifier());

class TerritoryNotifier extends Notifier<TerritoryState> {
  StreamSubscription<dynamic>? _zoneSub;

  @override
  TerritoryState build() {
    final detectionZone = ref.watch(detectionZoneProvider);

    // Listen for zone changes
    _zoneSub?.cancel();
    _zoneSub = detectionZone.onZoneChanged.listen((_) => _rebuild());
    ref.onDispose(() => _zoneSub?.cancel());

    return const TerritoryState();
  }

  Future<void> _rebuild() async {
    final hierarchyRepo = ref.read(hierarchyRepoProvider);
    final detectionZone = ref.read(detectionZoneProvider);

    final districts = await hierarchyRepo.getAllDistricts();
    final ancestry =
        <String, ({String? cityId, String? stateId, String? countryId})>{};

    for (final district in districts) {
      final city = await hierarchyRepo.getCity(district.cityId);
      final stateObj =
          city != null ? await hierarchyRepo.getState(city.stateId) : null;
      ancestry[district.id] = (
        cityId: district.cityId,
        stateId: city?.stateId,
        countryId: stateObj?.countryId,
      );
    }

    if (!ref.mounted) return;
    state = TerritoryState(
      ancestry: ancestry,
      cellDistrictIds: Map.from(detectionZone.cellDistrictAttribution),
    );
  }

  /// Force rebuild (e.g., after hierarchy data loads).
  Future<void> refresh() => _rebuild();
}
