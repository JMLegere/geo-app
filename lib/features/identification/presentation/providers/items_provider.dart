import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_property_value_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/use_cases/acquire_discovery_item.dart';
import 'package:earth_nova/features/identification/domain/use_cases/identify_unidentified_find.dart';
import 'package:earth_nova/features/identification/domain/use_cases/plan_item_identification.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';
import 'package:earth_nova/features/pack/domain/use_cases/fetch_pack_items.dart';
import 'package:earth_nova/features/pack/domain/use_cases/examine_pack_item.dart';
import 'package:earth_nova/core/observability/trace_context.dart';

/// Observability provider for ItemsNotifier — overridden with real impl in main.dart.
final itemsObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

/// Items state — immutable snapshot of the pack.
class ItemsState {
  const ItemsState({
    this.items = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
  });

  final List<Item> items;
  final bool isLoading;
  final bool hasLoaded;
  final String? error;

  ItemsState copyWith({
    List<Item>? items,
    bool? isLoading,
    bool? hasLoaded,
    String? error,
  }) => ItemsState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    error: error,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemsState &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          isLoading == other.isLoading &&
          hasLoaded == other.hasLoaded &&
          error == other.error;

  @override
  int get hashCode => Object.hash(items, isLoading, hasLoaded, error);
}

/// Provider for the item repository — overridden with real impl in main.dart.
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  throw UnimplementedError('Must be overridden with real or mock repository');
});

/// Read-only Pack boundary — overridden by bootstrap in every runtime mode.
final packRepositoryProvider = Provider<PackRepository>((ref) {
  throw UnimplementedError(
    'Must be overridden with real or mock Pack repository',
  );
});

/// Presentation-only reader for committed properties; absent outside Supabase.
final itemPropertyValueRepositoryProvider =
    Provider<ItemPropertyValueRepository?>((ref) => null);

/// Authoritative Item Identification boundary.
///
/// A null value is the explicit mock-only compatibility mode; production
/// bootstrap always provides the transactional repository.
final identificationRepositoryProvider = Provider<IdentificationRepository?>(
  (ref) => null,
);

final planItemIdentificationProvider = Provider<PlanItemIdentification>(
  (ref) => PlanItemIdentification(ref.watch(itemsObservabilityProvider)),
);

final fetchPackItemsProvider = Provider<FetchPackItems>((ref) {
  return FetchPackItems(
    ref.watch(packRepositoryProvider),
    ref.watch(itemsObservabilityProvider),
  );
});

final acquireDiscoveryItemProvider = Provider<AcquireDiscoveryItem>((ref) {
  return AcquireDiscoveryItem(
    ref.watch(itemRepositoryProvider),
    ref.watch(itemsObservabilityProvider),
  );
});

final identifyUnidentifiedFindProvider = Provider<IdentifyUnidentifiedFind>((
  ref,
) {
  return IdentifyUnidentifiedFind(
    ref.watch(itemRepositoryProvider),
    ref.watch(itemsObservabilityProvider),
  );
});

final examinePackItemProvider = Provider<ExaminePackItem>((ref) {
  return ExaminePackItem(
    ref.watch(itemRepositoryProvider),
    ref.watch(itemsObservabilityProvider),
  );
});

/// Items provider — fetches and caches the Player's Pack.
final itemsProvider = NotifierProvider<ItemsNotifier, ItemsState>(
  ItemsNotifier.new,
);

class ItemsNotifier extends ObservableNotifier<ItemsState> {
  @override
  ObservabilityService get obs => ref.watch(itemsObservabilityProvider);

  @override
  String get category => 'data';

  @override
  ItemsState build() {
    ref.watch(packRepositoryProvider);
    return const ItemsState();
  }

  void hydrate(List<Item> items) {
    transition(
      ItemsState(items: List<Item>.unmodifiable(items), hasLoaded: true),
      'items.hydrated',
      data: {'mode': 'pack', 'source': 'working_set', 'count': items.length},
    );
  }

  Future<void> fetchItems() async {
    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return;

    transition(
      state.copyWith(isLoading: true, error: null),
      'items.fetch_started',
      data: const {'mode': 'pack', 'terminal': 'started'},
    );

    try {
      final items = await ref.read(fetchPackItemsProvider)(authState.user!.id);
      transition(
        ItemsState(items: List<Item>.unmodifiable(items), hasLoaded: true),
        'items.fetch_success',
        data: {'mode': 'pack', 'terminal': 'succeeded', 'count': items.length},
      );
    } catch (_) {
      transition(
        state.copyWith(
          isLoading: false,
          error: "Couldn't load your collection. Pull to retry.",
        ),
        'items.fetch_error',
        data: const {'mode': 'pack', 'terminal': 'failed'},
      );
    }
  }

  void registerOwnedDiscovery(Item item) {
    final existingIndex = state.items.indexWhere(
      (existing) => existing.id == item.id,
    );
    final nextItems = [...state.items];
    if (existingIndex == -1) {
      nextItems.insert(0, item);
    } else {
      nextItems[existingIndex] = item;
    }
    transition(
      state.copyWith(items: List<Item>.unmodifiable(nextItems), error: null),
      'items.owned_discovery_registered',
      data: {
        'mode': 'encounter',
        'terminal': 'registered',
        'deduped': existingIndex != -1,
      },
    );
  }

  Future<Item?> identifyUnidentifiedFind(String itemId) async {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) return null;
    final item = state.items[index];
    if (!item.isUnidentified) return item;

    final trace = TraceContext.start();
    final traceId = trace.traceId;
    final authoritativeRepository = ref.read(identificationRepositoryProvider);
    final mode = authoritativeRepository == null
        ? 'legacy_mock'
        : 'authoritative';
    transition(
      state.copyWith(error: null),
      'items.identification_started',
      data: {'mode': mode, 'terminal': 'started', 'trace_id': traceId},
    );

    try {
      final identified = authoritativeRepository == null
          ? await ref.read(identifyUnidentifiedFindProvider).call(item)
          : (await authoritativeRepository.commit(
              await ref
                  .read(planItemIdentificationProvider)
                  .call(
                    await authoritativeRepository.prepare(
                      ItemKnowledgeItemId(item.id),
                      traceId: traceId,
                    ),
                    parent: trace,
                  ),
              traceId: traceId,
            )).committedItem;
      final nextItems = [...state.items];
      nextItems[index] = identified;
      transition(
        state.copyWith(items: List<Item>.unmodifiable(nextItems), error: null),
        'items.identification_completed',
        data: {'mode': mode, 'terminal': 'committed', 'trace_id': traceId},
      );
      return identified;
    } catch (_) {
      transition(
        state.copyWith(error: "Couldn't identify that find. Try again."),
        'items.identification_completed',
        data: {'mode': mode, 'terminal': 'failed', 'trace_id': traceId},
      );
      return null;
    }
  }

  Future<Item?> examinePackItem(String itemId, {TraceContext? parent}) async {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index == -1) return null;
    final item = state.items[index];
    if (item.isExamined) return item;

    final authState = ref.read(authProvider);
    if (authState.status != AuthStatus.authenticated) return null;

    final previousState = state;
    final trace = parent ?? TraceContext.start();
    transition(
      state.copyWith(error: null),
      'items.examination_started',
      data: {
        'terminal': 'started',
        'item_id': item.id,
        'trace_id': trace.traceId,
      },
    );

    try {
      final examined = await ref
          .read(examinePackItemProvider)
          .call(item, parent: trace);
      if (examined.id != item.id) {
        throw StateError('Examination returned a different Item.');
      }

      final nextItems = [...state.items];
      final currentIndex = nextItems.indexWhere(
        (existing) => existing.id == item.id,
      );
      if (currentIndex == -1) {
        throw StateError('Examined Item is no longer in the Pack.');
      }
      nextItems[currentIndex] = examined;
      transition(
        state.copyWith(items: List<Item>.unmodifiable(nextItems), error: null),
        'items.examination_optimistic',
        data: {
          'terminal': 'examined',
          'item_id': item.id,
          'trace_id': trace.traceId,
        },
      );

      final reloaded = await ref
          .read(fetchPackItemsProvider)
          .call(authState.user!.id, parent: trace);
      transition(
        state.copyWith(items: reloaded, error: null),
        'items.examination_completed',
        data: {
          'terminal': 'committed',
          'item_id': item.id,
          'trace_id': trace.traceId,
        },
      );
      return examined;
    } catch (_) {
      transition(
        previousState.copyWith(error: "Couldn't examine that find. Try again."),
        'items.examination_completed',
        data: {
          'terminal': 'failed',
          'item_id': item.id,
          'trace_id': trace.traceId,
        },
      );
      return null;
    }
  }
}
