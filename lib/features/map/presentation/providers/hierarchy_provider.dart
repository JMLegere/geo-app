import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';

final hierarchyObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final hierarchyRepositoryProvider = Provider<HierarchyRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class HierarchyState {
  const HierarchyState();
}

class HierarchyStateLoading extends HierarchyState {
  const HierarchyStateLoading();
}

class HierarchyStateData extends HierarchyState {
  const HierarchyStateData({
    required this.scope,
    required this.children,
  });

  final HierarchyProgressSummary scope;
  final List<HierarchyProgressSummary> children;
}

class HierarchyStateError extends HierarchyState {
  const HierarchyStateError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Notifier — used by hierarchy screens
// ---------------------------------------------------------------------------

class HierarchyScopeNotifier extends ObservableNotifier<HierarchyState> {
  HierarchyScopeNotifier({
    required MapLevel level,
    required String? scopeId,
    required String userId,
  })  : _level = level,
        _scopeId = _normalizeScopeId(scopeId),
        _userId = userId;

  final MapLevel _level;
  final String? _scopeId;
  final String _userId;

  static String? _normalizeScopeId(String? scopeId) {
    final trimmed = scopeId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  ObservabilityService get obs => ref.watch(hierarchyObservabilityProvider);

  @override
  String get category => 'hierarchy';

  @override
  HierarchyState build() {
    _load();
    return const HierarchyStateLoading();
  }

  Future<void> _load() async {
    final repo = ref.read(hierarchyRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.getScopeSummary(
          userId: _userId,
          level: _level,
          scopeId: _scopeId,
        ),
        repo.getChildSummaries(
          userId: _userId,
          level: _level,
          scopeId: _scopeId,
        ),
      ]);

      final scope = results[0] as HierarchyProgressSummary;
      final children = results[1] as List<HierarchyProgressSummary>;

      transition(
        HierarchyStateData(scope: scope, children: children),
        'hierarchy.loaded',
        data: {
          'level': _level.name,
          'scopeId': _scopeId,
          'cellsVisited': scope.cellsVisited,
          'rank': scope.rank,
        },
      );
    } catch (e, st) {
      obs.logError(e, st, event: 'hierarchy.load_error');
      transition(HierarchyStateError(e.toString()), 'hierarchy.error');
    }
  }
}

// ---------------------------------------------------------------------------
// Provider factory — creates a scoped provider for a given level + scopeId
// ---------------------------------------------------------------------------

NotifierProvider<HierarchyScopeNotifier, HierarchyState>
    hierarchyScopeProvider({
  required MapLevel level,
  required String? scopeId,
  required String userId,
}) {
  return NotifierProvider<HierarchyScopeNotifier, HierarchyState>(
    () => HierarchyScopeNotifier(
      level: level,
      scopeId: scopeId,
      userId: userId,
    ),
  );
}
