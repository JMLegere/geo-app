import 'package:earth_nova/shared/game_icons.dart';

/// Achievement identifiers — one per unlockable milestone.
enum AchievementId {
  firstSteps,
  explorer,
  cartographer,
  naturalist,
  biologist,
  taxonomist,
  forestFriend,
  oceanExplorer,
  mountaineer,
  dedicated,
  devoted,
  marathon,
  restorer,
}

/// Static metadata for a single achievement.
///
/// Holds the display content and target value. Progress tracking lives in
/// `AchievementProgress` (achievement_state.dart).
class AchievementDefinition {
  final AchievementId id;
  final String title;
  final String description;
  final String icon;
  final int targetValue;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetValue,
  });
}

/// Registry mapping every [AchievementId] to its [AchievementDefinition].
///
/// Authoritative source for achievement metadata. All IDs in [AchievementId]
/// must have an entry here — this is enforced by tests.
const Map<AchievementId, AchievementDefinition> kAchievementDefinitions = {
  AchievementId.firstSteps: AchievementDefinition(
    id: AchievementId.firstSteps,
    title: 'First Steps',
    description: 'Observe your first cell',
    icon: GameIcons.distance,
    targetValue: 1,
  ),
  AchievementId.explorer: AchievementDefinition(
    id: AchievementId.explorer,
    title: 'Explorer',
    description: 'Observe 10 cells',
    icon: GameIcons.cellsExplored,
    targetValue: 10,
  ),
  AchievementId.cartographer: AchievementDefinition(
    id: AchievementId.cartographer,
    title: 'Cartographer',
    description: 'Observe 50 cells',
    icon: GameIcons.cartographer,
    targetValue: 50,
  ),
  AchievementId.naturalist: AchievementDefinition(
    id: AchievementId.naturalist,
    title: 'Naturalist',
    description: 'Collect 5 species',
    icon: GameIcons.naturalist,
    targetValue: 5,
  ),
  AchievementId.biologist: AchievementDefinition(
    id: AchievementId.biologist,
    title: 'Biologist',
    description: 'Collect 15 species',
    icon: GameIcons.biologist,
    targetValue: 15,
  ),
  AchievementId.taxonomist: AchievementDefinition(
    id: AchievementId.taxonomist,
    title: 'Taxonomist',
    description: 'Collect 50 species',
    icon: GameIcons.taxonomist,
    targetValue: 50,
  ),
  AchievementId.forestFriend: AchievementDefinition(
    id: AchievementId.forestFriend,
    title: 'Forest Friend',
    description: 'Collect all species from Forest habitat',
    icon: GameIcons.forest,
    targetValue: 1,
  ),
  AchievementId.oceanExplorer: AchievementDefinition(
    id: AchievementId.oceanExplorer,
    title: 'Ocean Explorer',
    description: 'Collect all species from Saltwater habitat',
    icon: GameIcons.saltwater,
    targetValue: 1,
  ),
  AchievementId.mountaineer: AchievementDefinition(
    id: AchievementId.mountaineer,
    title: 'Mountaineer',
    description: 'Collect all species from Mountain habitat',
    icon: GameIcons.mountain,
    targetValue: 1,
  ),
  AchievementId.dedicated: AchievementDefinition(
    id: AchievementId.dedicated,
    title: 'Dedicated',
    description: '7-day visit streak',
    icon: GameIcons.streak,
    targetValue: 7,
  ),
  AchievementId.devoted: AchievementDefinition(
    id: AchievementId.devoted,
    title: 'Devoted',
    description: '30-day visit streak',
    icon: GameIcons.devoted,
    targetValue: 30,
  ),
  AchievementId.marathon: AchievementDefinition(
    id: AchievementId.marathon,
    title: 'Marathon',
    description: 'Walk 10km total',
    icon: GameIcons.marathon,
    targetValue: 10,
  ),
  AchievementId.restorer: AchievementDefinition(
    id: AchievementId.restorer,
    title: 'Restorer',
    description: 'Fully restore 5 cells',
    icon: GameIcons.restorer,
    targetValue: 5,
  ),
};
