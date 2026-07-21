import 'dart:async';

import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:earth_nova/features/index/presentation/providers/item_index_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class RecordingObservabilityService extends ObservabilityService {
  RecordingObservabilityService() : super(sessionId: 'index-test');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({'event': event, 'category': category, ...?data});
  }
}

final class FakeItemIndexRepository implements ItemIndexRepository {
  FakeItemIndexRepository({this.entries = const [], this.failure});

  List<IndexEntry> entries;
  Object? failure;
  int calls = 0;
  final List<String?> traceIds = [];

  @override
  Future<List<IndexEntry>> fetchIndex({String? traceId}) async {
    calls += 1;
    traceIds.add(traceId);
    final error = failure;
    if (error != null) throw error;
    return entries;
  }
}

IndexEntry indexEntry() {
  final baseItemId = StableContentId<BaseItemContent>('base-jaguar');
  return IndexEntry(
    baseItemId: baseItemId,
    category: ItemCategory.fauna,
    firstIdentifiedItemId: 'item-jaguar',
    firstVersion: ExactVersionRef<BaseItemContent>(
      stableId: baseItemId,
      versionId: ContentVersionId<BaseItemContent>('version-jaguar'),
      revision: 1,
    ),
    displayName: 'Jaguar',
    scientificName: 'Panthera onca',
    discoveryProvenance: DiscoveryProvenance.explicitIdentification,
    discoveredAt: DateTime.utc(2026, 7, 20),
  );
}

ProviderContainer containerFor(
  ItemIndexRepository repository,
  RecordingObservabilityService observability,
) =>
    ProviderContainer(
      overrides: [
        itemIndexRepositoryProvider.overrideWithValue(repository),
        itemIndexObservabilityProvider.overrideWithValue(observability),
      ],
    );

void main() {
  group('ItemIndexNotifier', () {
    test('loads the stable Index with an observable loading state', () async {
      final release = Completer<List<IndexEntry>>();
      final repository = _DeferredItemIndexRepository(release.future);
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      container.read(itemIndexProvider);
      final load = container.read(itemIndexProvider.notifier).load();
      expect(container.read(itemIndexProvider).isLoading, isTrue);

      release.complete([indexEntry()]);
      await load;

      final state = container.read(itemIndexProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.entries, [indexEntry()]);
      expect(
        () => state.entries.add(indexEntry()),
        throwsA(isA<UnsupportedError>()),
      );
      expect(repository.traceIds.single, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(observability.events.map((event) => event['event']),
          contains('item_index.load.completed'));
    });

    test('refresh reloads and invalidate clears without Pack derivation',
        () async {
      final repository = FakeItemIndexRepository(entries: [indexEntry()]);
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      await container.read(itemIndexProvider.notifier).load();
      await container.read(itemIndexProvider.notifier).refresh();
      container.read(itemIndexProvider.notifier).invalidate();

      expect(repository.calls, 2);
      expect(container.read(itemIndexProvider).entries, isEmpty);
      expect(container.read(itemIndexProvider).isLoading, isFalse);
      expect(container.read(itemIndexProvider).error, isNull);
    });

    test('turns unsafe repository errors into a safe failure state', () async {
      final repository = FakeItemIndexRepository(
        failure: StateError('server token should never reach telemetry'),
      );
      final observability = RecordingObservabilityService();
      final container = containerFor(repository, observability);
      addTearDown(container.dispose);

      await container.read(itemIndexProvider.notifier).load();

      final state = container.read(itemIndexProvider);
      expect(state.error, 'Unable to load your Item Index. Pull to retry.');
      expect(state.isLoading, isFalse);
      expect(observability.events.join(), isNot(contains('server token')));
    });
  });
}

final class _DeferredItemIndexRepository implements ItemIndexRepository {
  _DeferredItemIndexRepository(this.result);

  final Future<List<IndexEntry>> result;

  final List<String?> traceIds = [];
  @override
  Future<List<IndexEntry>> fetchIndex({String? traceId}) {
    traceIds.add(traceId);
    return result;
  }
}
