import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/ui/product_surfaces/living_world/widgets/venue_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/living_world/data/living_world_test_data.dart';
import 'phase_seven_capture_support.dart';

const _assets = <String>[
  'venue/marker-glyph-390x844.png',
  'venue/marker-glyph-1440x900.png',
  'venue/marker-compact-390x844.png',
  'venue/marker-compact-1440x900.png',
];

void main() {
  test('declares only visible Venue marker states', () {
    expect(_assets, hasLength(4));
    expect(_assets.toSet(), hasLength(4));
  });

  for (final viewport in const [
    (size: phaseSevenMobileSize, suffix: '390x844'),
    (size: phaseSevenDesktopSize, suffix: '1440x900'),
  ]) {
    for (final mode in VenueMarkerDisplayMode.values) {
      final name = mode == VenueMarkerDisplayMode.glyphOnly
          ? 'glyph'
          : 'compact';
      testWidgets(
        'captures venue/marker-$name-${viewport.suffix}.png',
        (tester) => capturePhaseSevenFixture(
          tester,
          size: viewport.size,
          name: 'venue/marker-$name-${viewport.suffix}.png',
          child: Scaffold(
            body: Center(
              child: VenueMarker(venue: _venue, displayMode: mode),
            ),
          ),
          prepare: (tester) async {
            expect(find.byType(VenueMarker), findsOneWidget);
          },
        ),
        skip: !phaseSevenCaptureEnabled,
      );
    }
  }
}

final _venue = LivingWorldTownDto.fromJson(
  town(withVillager: true),
  playerId: playerId,
).toDomain().venues.single;
