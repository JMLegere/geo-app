import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/cells/country_resolver.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';

/// Asynchronously loads [CountryResolver] from the bundled country
/// boundaries JSON asset (~146 KB, 175 countries).
///
/// Uses [rootBundle] so it works in both the full app and in widget tests
/// (when the test framework sets up the asset bundle).
final countryResolverProvider = FutureProvider<CountryResolver>((ref) async {
  final sw = Stopwatch()..start();
  final jsonString =
      await rootBundle.loadString('assets/country_boundaries.json');
  final resolver = CountryResolver.load(jsonString);
  sw.stop();
  ObservabilityBuffer.instance?.event('asset_loaded', {
    'asset': 'country_boundaries.json',
    'duration_ms': sw.elapsedMilliseconds,
  });
  return resolver;
});
