import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/services/item_service.dart';
import 'package:earth_nova/services/observability_service.dart';

/// Items state — immutable snapshot of the pack.
class ItemsState {
  const ItemsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Item> items;
  final bool isLoading;
  final String? error;

  ItemsState copyWith({
    List<Item>? items,
    bool? isLoading,
    String? error,
  }) =>
      ItemsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Provider for the item service — overridden with real impl in main.dart.
final itemServiceProvider = Provider<ItemService>((ref) {
  final client = Supabase.instance.client;
  return ItemService(client: client);
});

/// Items provider — fetches and caches user's items from Supabase.
final itemsProvider =
    NotifierProvider<ItemsNotifier, ItemsState>(ItemsNotifier.new);

class ItemsNotifier extends Notifier<ItemsState> {
  late ItemService _itemService;
  late ObservabilityService _obs;

  @override
  ItemsState build() {
    _itemService = ref.watch(itemServiceProvider);
    _obs = ref.watch(observabilityProvider);
    return const ItemsState();
  }

  Future<void> fetchItems() async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;

    state = state.copyWith(isLoading: true, error: null);
    _obs.log('items.fetch_started', 'data');

    try {
      final userId = authState.user!.id;
      final items = await _itemService.fetchItems(userId);
      _obs.log('items.fetch_success', 'data', data: {'count': items.length});
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      _obs.logError(e, StackTrace.current, event: 'items.fetch_error');
      state = state.copyWith(
        isLoading: false,
        error: 'Couldn\'t load your collection. Pull to retry.',
      );
    }
  }
}
