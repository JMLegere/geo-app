import 'package:earth_nova/ui/product_surfaces/home/screens/home_screen.dart';
import 'package:earth_nova_widgetbook/fixtures/home_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: HomeScreen,
  path: '[Product Surfaces]/Home',
)
Widget homeScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: homeStoryOverrides(() async => storyHome),
  child: const HomeScreen(),
);

@widgetbook.UseCase(
  name: '10 Loading',
  type: HomeScreen,
  path: '[Product Surfaces]/Home',
)
Widget homeScreenLoading(BuildContext context) => earthNovaStory(
  overrides: homeStoryOverrides(storyHomeLoading),
  child: const HomeScreen(),
);

@widgetbook.UseCase(
  name: '20 Load Error',
  type: HomeScreen,
  path: '[Product Surfaces]/Home',
)
Widget homeScreenLoadError(BuildContext context) => earthNovaStory(
  overrides: homeStoryOverrides(storyHomeUnavailable),
  child: const HomeScreen(),
);
