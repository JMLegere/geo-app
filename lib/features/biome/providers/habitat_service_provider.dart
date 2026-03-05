import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/features/biome/services/biome_feature_index.dart';
import 'package:fog_of_world/features/biome/services/biome_service.dart';

/// Asynchronously loads [BiomeFeatureIndex] from the bundled JSON asset.
///
/// Uses [rootBundle] so it works in both the full app and in widget tests
/// (when the test framework sets up the asset bundle).
final biomeFeatureIndexProvider = FutureProvider<BiomeFeatureIndex>((ref) async {
  final jsonString =
      await rootBundle.loadString('assets/biome_features.json');
  return BiomeFeatureIndex.load(jsonString);
});

/// Provides a [HabitatService] backed by real geographic feature data.
///
/// - **Loading** — falls back to plain `HabitatService()` (returns
///   `{Habitat.plains}` for all coordinates) until the asset is ready.
/// - **Error** — same plains fallback if the asset fails to load.
/// - **Ready** — uses `HabitatService.withFeatureIndex(index)` for full
///   multi-habitat detection from the biome features JSON.
final habitatServiceProvider = Provider<HabitatService>((ref) {
  final indexAsync = ref.watch(biomeFeatureIndexProvider);
  return indexAsync.when(
    data: (index) => HabitatService.withFeatureIndex(index),
    loading: HabitatService.new,
    error: (_, __) => HabitatService(),
  );
});
