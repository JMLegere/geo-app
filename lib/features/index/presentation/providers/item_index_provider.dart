import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:earth_nova/features/index/domain/use_cases/fetch_item_index.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Intentionally unwired until an Item Index surface is introduced.
final itemIndexObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError(
      'Item Index observability must be provided by bootstrap.');
});

/// Intentionally unwired read boundary for the Item Index surface.
final itemIndexRepositoryProvider = Provider<ItemIndexRepository>((ref) {
  throw UnimplementedError(
      'Item Index repository must be provided by bootstrap.');
});

final fetchItemIndexProvider = Provider<FetchItemIndex>((ref) {
  return FetchItemIndex(
    ref.watch(itemIndexRepositoryProvider),
    ref.watch(itemIndexObservabilityProvider),
  );
});

/// Immutable read state for the stable Base Item Index.
final class ItemIndexState {
  ItemIndexState({
    List<IndexEntry> entries = const [],
    this.isLoading = false,
    this.error,
  }) : entries = List<IndexEntry>.unmodifiable(entries);

  final List<IndexEntry> entries;
  final bool isLoading;
  final String? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemIndexState &&
          _sameEntries(entries, other.entries) &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(Object.hashAll(entries), isLoading, error);
}

/// Read-only controller for loading, refreshing, and invalidating Index data.
final itemIndexProvider =
    NotifierProvider<ItemIndexNotifier, ItemIndexState>(ItemIndexNotifier.new);

final class ItemIndexNotifier extends ObservableNotifier<ItemIndexState> {
  late FetchItemIndex _fetchIndex;
  int _requestGeneration = 0;

  @override
  ObservabilityService get obs => ref.watch(itemIndexObservabilityProvider);

  @override
  String get category => 'data';

  @override
  ItemIndexState build() {
    _fetchIndex = ref.watch(fetchItemIndexProvider);
    return ItemIndexState();
  }

  Future<void> load() => _load('item_index.load');

  Future<void> refresh() => _load('item_index.refresh');

  /// Drops cached projection data without deriving a substitute from Pack state.
  void invalidate() {
    _requestGeneration += 1;
    transition(ItemIndexState(), 'item_index.invalidate');
  }

  Future<void> _load(String event) async {
    final request = ++_requestGeneration;
    transition(
      ItemIndexState(entries: state.entries, isLoading: true),
      '$event.started',
    );
    try {
      final entries = await _fetchIndex(null);
      if (request != _requestGeneration) return;
      transition(
        ItemIndexState(entries: entries),
        '$event.completed',
        data: {'entry_count': entries.length},
      );
    } catch (error) {
      if (request != _requestGeneration) return;
      transition(
        ItemIndexState(
          entries: state.entries,
          error: 'Unable to load your Item Index. Pull to retry.',
        ),
        '$event.failed',
        data: {'error_type': error.runtimeType.toString()},
      );
    }
  }
}

bool _sameEntries(List<IndexEntry> left, List<IndexEntry> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
