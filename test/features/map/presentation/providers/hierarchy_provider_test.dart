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

void main() {
  ProviderContainer makeContainer(_TrackingHierarchyRepository repo) {
    return ProviderContainer(
      overrides: [
        hierarchyRepositoryProvider.overrideWithValue(repo),
        hierarchyObservabilityProvider.overrideWithValue(
          _TestObservabilityService(),
        ),
      ],
    );
  }

  group('HierarchyScopeNotifier scopeId normalization', () {
    test('normalizes empty scopeId to null before repository calls', () async {
      final repo = _TrackingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      container.read(
        hierarchyScopeProvider(
          level: MapLevel.city,
          scopeId: '',
          userId: 'user-1',
        ),
      );

      await repo.allCallsCompleted.future;

      expect(repo.scopeIds, [null, null]);
    });

    test('keeps null scopeId as null', () async {
      final repo = _TrackingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      container.read(
        hierarchyScopeProvider(
          level: MapLevel.country,
          scopeId: null,
          userId: 'user-1',
        ),
      );

      await repo.allCallsCompleted.future;

      expect(repo.scopeIds, [null, null]);
    });

    test('keeps non-empty scopeId unchanged', () async {
      final repo = _TrackingHierarchyRepository();
      final container = makeContainer(repo);
      addTearDown(container.dispose);

      container.read(
        hierarchyScopeProvider(
          level: MapLevel.district,
          scopeId: 'district-uuid-1',
          userId: 'user-1',
        ),
      );

      await repo.allCallsCompleted.future;

      expect(repo.scopeIds, ['district-uuid-1', 'district-uuid-1']);
    });
  });
}
