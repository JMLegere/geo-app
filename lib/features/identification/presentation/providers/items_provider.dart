import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/use_cases/fetch_items.dart';

/// Observability provider for ItemsNotifier — overridden with real impl in main.dart.
final itemsObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

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

/// Provider for the item repository — overridden with real impl in main.dart.
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  throw UnimplementedError('Must be overridden with real or mock repository');
});

/// Items provider — fetches and caches user's items from Supabase.
final itemsProvider =
    NotifierProvider<ItemsNotifier, ItemsState>(ItemsNotifier.new);

class ItemsNotifier extends ObservableNotifier<ItemsState> {
  late ItemRepository _itemRepository;

  @override
  ObservabilityService get obs => ref.watch(itemsObservabilityProvider);

  @override
  String get category => 'data';

  @override
  ItemsState build() {
    _itemRepository = ref.watch(itemRepositoryProvider);
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
      final useCase = FetchItems(_itemRepository);
      final items = await useCase.call(userId);
      transition(
        state.copyWith(items: items, isLoading: false),
        'items.fetch_success',
        data: {'count': items.length},
      );
    } catch (e, stack) {
      obs.logError(e, stack, event: 'items.fetch_error');
      transition(
        state.copyWith(
          isLoading: false,
          error: "Couldn't load your collection. Pull to retry.",
        ),
        'items.fetch_error',
      );
    }
  }
}
