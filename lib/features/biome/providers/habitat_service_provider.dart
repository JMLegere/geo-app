import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/biome/services/biome_feature_index.dart';
import 'package:earth_nova/features/biome/services/biome_service.dart';

/// Asynchronously loads [BiomeFeatureIndex] from the bundled JSON asset.
///
/// Uses [rootBundle] so it works in both the full app and in widget tests
/// (when the test framework sets up the asset bundle).
///
/// On web, loading is deferred by 10 seconds to avoid a ~45 MB memory spike
/// during boot (the 28 MB JSON expands to ~45 MB in-memory). This prevents
/// WKWebView crashes on memory-constrained devices (e.g. iPhone 13 Mini).
/// The map is interactive within ~5 s; biome data loads in the background
/// after. [cellPropertyResolverProvider] returns `null` until the index is
/// ready, so cells visited before biome loads simply skip habitat resolution.
final biomeFeatureIndexProvider =
    FutureProvider<BiomeFeatureIndex>((ref) async {
  if (kIsWeb) {
    await Future<void>.delayed(const Duration(seconds: 10));
  }
  final jsonString = await rootBundle.loadString('assets/biome_features.json');
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
