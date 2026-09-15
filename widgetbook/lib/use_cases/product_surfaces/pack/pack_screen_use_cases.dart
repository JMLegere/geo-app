import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/ui/product_surfaces/pack/screens/pack_screen.dart';
import 'package:earth_nova_widgetbook/fixtures/pack_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: PackScreen,
  path: '[Product Surfaces]/Pack',
)
Widget packScreenHappyPath(BuildContext context) => earthNovaStory(
  child: const PackScreen(),
  overrides: packStoryOverrides(
    ItemsState(items: storyPackItems, hasLoaded: true),
  ),
);

@widgetbook.UseCase(
  name: '01 Empty Pack',
  type: PackScreen,
  path: '[Product Surfaces]/Pack',
)
Widget packScreenEmpty(BuildContext context) => earthNovaStory(
  child: const PackScreen(),
  overrides: packStoryOverrides(const ItemsState(hasLoaded: true)),
);

@widgetbook.UseCase(
  name: '02 Loading',
  type: PackScreen,
  path: '[Product Surfaces]/Pack',
)
Widget packScreenLoading(BuildContext context) => earthNovaStory(
  child: const PackScreen(),
  overrides: packStoryOverrides(const ItemsState(isLoading: true)),
);

@widgetbook.UseCase(
  name: '03 Load Error',
  type: PackScreen,
  path: '[Product Surfaces]/Pack',
)
Widget packScreenError(BuildContext context) => earthNovaStory(
  child: const PackScreen(),
  overrides: packStoryOverrides(
    const ItemsState(error: 'Connection timed out'),
  ),
);

@widgetbook.UseCase(
  name: '04 Fauna Filter Zero',
  type: PackScreen,
  path: '[Product Surfaces]/Pack',
)
Widget packScreenCategoryZero(BuildContext context) => earthNovaStory(
  child: const PackScreen(),
  overrides: packStoryOverrides(
    ItemsState(items: [storyExaminedFlora], hasLoaded: true),
  ),
);
