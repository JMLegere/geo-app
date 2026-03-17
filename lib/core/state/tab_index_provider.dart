import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSelectedTabKey = 'selected_tab_index';

/// Tracks the currently selected tab index in the main navigation.
///
/// State starts at 0 (Map tab) and loads persisted value from
/// SharedPreferences asynchronously. Using `int` directly — the
/// IndexedStack index maps 1:1 to tab positions.
///
/// Tab indices: 0=Map, 1=Home, 2=Town, 3=Pack
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() {
    _loadState();
    return 0; // Default to Map tab
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final saved = prefs.getInt(_kSelectedTabKey);
    if (saved != null && saved >= 0 && saved <= 3) {
      state = saved;
    }
  }

  /// Updates the selected tab and persists to SharedPreferences.
  Future<void> setTab(int index) async {
    if (index < 0 || index > 3) return;
    state = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedTabKey, index);
  }
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);
