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
    icon: '👣',
    targetValue: 1,
  ),
  AchievementId.explorer: AchievementDefinition(
    id: AchievementId.explorer,
    title: 'Explorer',
    description: 'Observe 10 cells',
    icon: '🗺️',
    targetValue: 10,
  ),
  AchievementId.cartographer: AchievementDefinition(
    id: AchievementId.cartographer,
    title: 'Cartographer',
    description: 'Observe 50 cells',
    icon: '🧭',
    targetValue: 50,
  ),
  AchievementId.naturalist: AchievementDefinition(
    id: AchievementId.naturalist,
    title: 'Naturalist',
    description: 'Collect 5 species',
    icon: '🌿',
    targetValue: 5,
  ),
  AchievementId.biologist: AchievementDefinition(
    id: AchievementId.biologist,
    title: 'Biologist',
    description: 'Collect 15 species',
    icon: '🔬',
    targetValue: 15,
  ),
  AchievementId.taxonomist: AchievementDefinition(
    id: AchievementId.taxonomist,
    title: 'Taxonomist',
    description: 'Collect 50 species',
    icon: '📚',
    targetValue: 50,
  ),
  AchievementId.forestFriend: AchievementDefinition(
    id: AchievementId.forestFriend,
    title: 'Forest Friend',
    description: 'Collect all species from Forest habitat',
    icon: '🌲',
    targetValue: 1,
  ),
  AchievementId.oceanExplorer: AchievementDefinition(
    id: AchievementId.oceanExplorer,
    title: 'Ocean Explorer',
    description: 'Collect all species from Saltwater habitat',
    icon: '🌊',
    targetValue: 1,
  ),
  AchievementId.mountaineer: AchievementDefinition(
    id: AchievementId.mountaineer,
    title: 'Mountaineer',
    description: 'Collect all species from Mountain habitat',
    icon: '⛰️',
    targetValue: 1,
  ),
  AchievementId.dedicated: AchievementDefinition(
    id: AchievementId.dedicated,
    title: 'Dedicated',
    description: '7-day visit streak',
    icon: '🔥',
    targetValue: 7,
  ),
  AchievementId.devoted: AchievementDefinition(
    id: AchievementId.devoted,
    title: 'Devoted',
    description: '30-day visit streak',
    icon: '💎',
    targetValue: 30,
  ),
  AchievementId.marathon: AchievementDefinition(
    id: AchievementId.marathon,
    title: 'Marathon',
    description: 'Walk 10km total',
    icon: '🏃',
    targetValue: 10,
  ),
};
