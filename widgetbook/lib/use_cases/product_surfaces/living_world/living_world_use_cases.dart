import 'package:earth_nova/ui/product_surfaces/living_world/screens/town_screen.dart';
import 'package:earth_nova/ui/product_surfaces/living_world/screens/venue_detail_screen.dart';
import 'package:earth_nova/ui/product_surfaces/living_world/widgets/venue_marker.dart';
import 'package:earth_nova_widgetbook/fixtures/living_world_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownVenueWithServices),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '10 Loading',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenLoading(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(storyTownLoading),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '20 Load Error',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenLoadError(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(storyTownUnavailable),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '30 Empty',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenEmpty(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownEmpty),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '40 Venue Without Villagers',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenVenueWithoutVillagers(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownVenueWithoutVillagers),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '50 Multiple Venues',
  type: TownScreen,
  path: '[Product Surfaces]/Living World',
)
Widget townScreenMultipleVenues(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownMultipleVenues),
  child: const TownScreen(),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: VenueDetailScreen,
  path: '[Product Surfaces]/Living World',
)
Widget venueDetailScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownVenueWithServices),
  child: VenueDetailScreen(venue: storyTownVenueWithServices.venues.single),
);

@widgetbook.UseCase(
  name: '10 No Villagers',
  type: VenueDetailScreen,
  path: '[Product Surfaces]/Living World',
)
Widget venueDetailScreenNoVillagers(BuildContext context) => earthNovaStory(
  overrides: townStoryOverrides(() async => storyTownVenueWithoutVillagers),
  child: VenueDetailScreen(venue: storyTownVenueWithoutVillagers.venues.single),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: VenueMarker,
  path: '[Product Surfaces]/Living World',
)
Widget venueMarkerHappyPath(BuildContext context) => earthNovaStory(
  child: Center(
    child: VenueMarker(venue: storyTownVenueWithServices.venues.single),
  ),
);

@widgetbook.UseCase(
  name: '10 Glyph Only',
  type: VenueMarker,
  path: '[Product Surfaces]/Living World',
)
Widget venueMarkerGlyphOnly(BuildContext context) => earthNovaStory(
  child: Center(
    child: VenueMarker(
      venue: storyTownVenueWithServices.venues.single,
      displayMode: VenueMarkerDisplayMode.glyphOnly,
    ),
  ),
);

@widgetbook.UseCase(
  name: '20 Long Label',
  type: VenueMarker,
  path: '[Product Surfaces]/Living World',
)
Widget venueMarkerLongLabel(BuildContext context) => earthNovaStory(
  child: Center(
    child: VenueMarker(venue: storyTownMultipleVenues.venues.first),
  ),
);
