import 'package:earth_nova/models/item_definition.dart';

/// Emoji/symbol constants for game elements.
///
/// Used across status bars, discovery toasts, and collection views.
/// All values are single emoji or Unicode characters that render correctly
/// on iOS, Android, and web without any custom font.
abstract final class GameIcons {
  // ── Status bar stats ─────────────────────────────────────────────────────

  /// Cells explored counter.
  static const String cellsExplored = '🗺️';

  /// Step counter.
  static const String steps = '👣';

  /// Daily exploration streak.
  static const String streak = '🔥';

  // ── Discovery toasts / item icons ────────────────────────────────────────

  /// Fallback icon for any item with no richer classification.
  static const String unknown = '❓';

  /// Returns the best icon emoji for a [FaunaDefinition].
  ///
  /// Falls back through: animalClass → animalType → generic paw.
  static String fauna(FaunaDefinition item) {
    // Animal-type fallbacks
    switch (item.animalType?.name) {
      case 'mammal':
        return '🐾';
      case 'bird':
        return '🐦';
      case 'fish':
        return '🐟';
      case 'reptile':
        return '🦎';
      case 'bug':
        return '🐛';
    }
    return '🐾';
  }
}
