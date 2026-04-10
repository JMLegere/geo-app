import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

class _TrackingHierarchyRepository implements HierarchyRepository {
  final List<String?> scopeIds = [];
  final Completer<void> allCallsCompleted = Completer<void>();

  int _callCount = 0;

  void _recordScopeId(String? scopeId) {
    scopeIds.add(scopeId);
    _callCount++;
    if (_callCount == 2 && !allCallsCompleted.isCompleted) {
      allCallsCompleted.complete();
    }
  }

  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    _recordScopeId(scopeId);
    return HierarchyProgressSummary(
      id: scopeId ?? 'scope-1',
      name: 'Scope',
      level: level,
      cellsVisited: 1,
      cellsTotal: 10,
      progressPercent: 10,
      rank: 1,
    );
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    _recordScopeId(scopeId);
    return const [];
  }
}

class _NeverCalledRepository implements HierarchyRepository {
  bool called = false;

  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    called = true;
    throw StateError('should not be called');
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    called = true;
    throw StateError('should not be called');
  }
}

Future<HierarchyState> _waitForNonLoading(
  ProviderContainer container,
  NotifierProvider<HierarchyScopeNotifier, HierarchyState> provider,
) async {
  final completer = Completer<HierarchyState>();
  final sub = container.listen(provider, (_, next) {
    if (next is! HierarchyStateLoading && !completer.isCompleted) {
      completer.complete(next);
    }
  });
  final current = container.read(provider);
  if (current is! HierarchyStateLoading) {
    sub.close();
    return current;
  }
  final result = await completer.future;
  sub.close();
  return result;
}

void main() {
  ProviderContainer makeContainer(HierarchyRepository repo) {
    return ProviderContainer(
      overrides: [
        hierarchyRepositoryProvider.overrideWithValue(repo),
        hierarchyObservabilityProvider.overrideWithValue(
          _TestObservabilityService(),
        ),
      ],
    );
  }

  group('hierarchyScopeProvider family caching', () {
    test('same args return the same cached provider instance', () {
      final container = makeContainer(_TrackingHierarchyRepository());
      addTearDown(container.dispose);

      final args = (
        level: MapLevel.city,
        scopeId: 'city-1',
        userId: 'user-1',
      );

      final p1 = hierarchyScopeProvider(args);
      final p2 = hierarchyScopeProvider(args);

      expect(p1, equals(p2));
    });

    test('different args return different provider instances', () {
      final container = makeContainer(_TrackingHierarchyRepository());
      addTearDown(container.dispose);

      final p1 = hierarchyScopeProvider((
        level: MapLevel.city,
        scopeId: 'city-1',
        userId: 'user-1',
      ));
      final p2 = hierarchyScopeProvider((
        level: MapLevel.city,
        scopeId: 'city-2',
        userId: 'user-1',
      ));

      expect(p1, isNot(equals(p2)));
    });
  });

  group('HierarchyScopeNotifier _load() null scopeId guard', () {
    test(
        'transitions to HierarchyStateError without calling repository when scopeId is null',
        () async {
      final repo = _NeverCalledRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final provider = hierarchyScopeProvider((
        level: MapLevel.world,
        scopeId: null,
        userId: 'user-1',
      ));

      final state = await _waitForNonLoading(container, provider);

      expect(state, isA<HierarchyStateError>());
      expect(repo.called, isFalse);
    });

    test(
        'transitions to HierarchyStateError without calling repository when scopeId is empty',
        () async {
      final repo = _NeverCalledRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final provider = hierarchyScopeProvider((
        level: MapLevel.world,
        scopeId: '',
        userId: 'user-1',
      ));

      final state = await _waitForNonLoading(container, provider);

      expect(state, isA<HierarchyStateError>());
      expect(repo.called, isFalse);
    });
  });

  group('HierarchyScopeNotifier _load() with valid scopeId', () {
    test('transitions to HierarchyStateData when repository returns data',
        () async {
      final repo = _TrackingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final provider = hierarchyScopeProvider((
        level: MapLevel.district,
        scopeId: 'district-1',
        userId: 'user-1',
      ));

      final state = await _waitForNonLoading(container, provider);

      expect(state, isA<HierarchyStateData>());
    });

    test('passes non-empty scopeId unchanged to repository', () async {
      final repo = _TrackingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      container.read(
        hierarchyScopeProvider((
          level: MapLevel.district,
          scopeId: 'district-uuid-1',
          userId: 'user-1',
        )),
      );

      await repo.allCallsCompleted.future;

      expect(repo.scopeIds, ['district-uuid-1', 'district-uuid-1']);
    });

    test('transitions to HierarchyStateError when repository throws', () async {
      final repo = _ThrowingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final provider = hierarchyScopeProvider((
        level: MapLevel.district,
        scopeId: 'district-1',
        userId: 'user-1',
      ));

      final state = await _waitForNonLoading(container, provider);

      expect(state, isA<HierarchyStateError>());
    });
  });
}

class _ThrowingHierarchyRepository implements HierarchyRepository {
  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    throw Exception('db error');
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    throw Exception('db error');
  }
}
