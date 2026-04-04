import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/providers/observable_notifier.dart';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemsState &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(items, isLoading, error);
}

/// Provider for the item service — overridden with real impl in main.dart.
final itemServiceProvider = Provider<ItemService>((ref) {
  final client = Supabase.instance.client;
  return ItemService(client: client);
});

/// Items provider — fetches and caches user's items from Supabase.
final itemsProvider =
    NotifierProvider<ItemsNotifier, ItemsState>(ItemsNotifier.new);

class ItemsNotifier extends ObservableNotifier<ItemsState> {
  late ItemService _itemService;

  @override
  ObservabilityService get obs => ref.watch(observabilityProvider);

  @override
  String get category => 'data';

  @override
  ItemsState build() {
    _itemService = ref.watch(itemServiceProvider);
    return const ItemsState();
  }

  Future<void> fetchItems() async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;

    transition(
      state.copyWith(isLoading: true, error: null),
      'items.fetch_started',
    );

    try {
      final userId = authState.user!.id;
      final items = await _itemService.fetchItems(userId);
      transition(
        state.copyWith(items: items, isLoading: false),
        'items.fetch_success',
        data: {'count': items.length},
      );
    } catch (e, stack) {
      obs.logError(e, stack, event: 'items.fetch_error');
      state = state.copyWith(
        isLoading: false,
        error: 'Couldn\'t load your collection. Pull to retry.',
      );
    }
  }
}
