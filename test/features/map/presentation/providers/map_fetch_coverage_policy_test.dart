import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/presentation/providers/map_fetch_coverage_policy.dart';

void main() {
  group('MapFetchCoveragePolicy', () {
    test('fetch radius covers a landscape GPS viewport with padding', () {
      expect(
        MapFetchCoveragePolicy.fetchRadiusMeters,
        greaterThanOrEqualTo(3200),
        reason:
            'Fetched geometry must cover wide landscape map views so explored cells do not sit behind unknown fog at the viewport edge.',
      );
    });

    test('fetch radius is larger than the nominal render radius', () {
      expect(
        MapFetchCoveragePolicy.fetchRadiusMeters,
        greaterThan(MapFetchCoveragePolicy.renderRadiusMeters),
      );
    });
  });
}
