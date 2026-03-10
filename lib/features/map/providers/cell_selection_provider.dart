import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the currently selected cell ID from a map long press.
///
/// `null` means no cell is selected. Set by [_MapScreenState._onCellTapped]
/// when the user long-presses the map. Consumed by the exploration bottom sheet.
///
/// Uses a simple [Notifier] so the selection can be cleared programmatically
/// (e.g., when the bottom sheet is dismissed).
class CellSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Sets the selected cell ID.
  void select(String cellId) {
    state = cellId;
  }

  /// Clears the selection (e.g., bottom sheet dismissed).
  void clear() {
    state = null;
  }
}

/// Provider for the currently selected cell ID.
///
/// `null` = no selection. Updated by map long-press events in [MapScreen].
final cellSelectionProvider =
    NotifierProvider<CellSelectionNotifier, String?>(CellSelectionNotifier.new);
