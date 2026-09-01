import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_header.dart';
import 'package:earth_nova/features/map/presentation/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key, this.onLowerLevelTap});

  final VoidCallback? onLowerLevelTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.status == AuthStatus.authenticated
        ? authState.user!.id
        : '';
    final hierarchyState = ref.watch(
      hierarchyScopeProvider((
        level: MapLevel.world,
        scopeId: null,
        userId: userId,
      )),
    );

    return ObservableScreen(
      screenName: 'world_screen',
      observability: obs,
      builder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            _buildHeader(hierarchyState),
            Expanded(child: _buildMap(hierarchyState)),
            _buildPinchHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(HierarchyState state) {
    return switch (state) {
      HierarchyStateLoading() => const _LoadingHeader(),
      HierarchyStateData(:final scope, :final children) => HierarchyHeader(
        scopeLevel: 'World',
        scopeName: scope.name,
        scopeCode: 'GLOBAL',
        cellsVisited: scope.cellsVisited,
        cellsTotal: scope.cellsTotal,
        progressPercent: scope.progressPercent,
        rank: scope.rank,
        explorerCount: children.length,
      ),
      HierarchyStateError() => const _LoadingHeader(),
    };
  }

  Widget _buildMap(HierarchyState state) {
    return switch (state) {
      HierarchyStateData(:final children) => HierarchyExplorationMap(
        children: children
            .map(
              (c) => ChildAreaData(
                id: c.id,
                name: c.name,
                cellsVisited: c.cellsVisited,
                cellsTotal: c.cellsTotal,
                progressPercent: c.progressPercent,
              ),
            )
            .toList(),
        playerLat: null,
        playerLng: null,
      ),
      _ => const HierarchyExplorationMap(
        children: [],
        playerLat: null,
        playerLng: null,
      ),
    };
  }

  Widget _buildPinchHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PinchHint(
        lowerLevelLabel: 'Country',
        upperLevelLabel: null,
        onLowerLevelTap: onLowerLevelTap,
      ),
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return const HierarchyHeader(
      scopeLevel: 'World',
      scopeName: '—',
      scopeCode: 'GLOBAL',
      cellsVisited: 0,
      cellsTotal: 0,
      progressPercent: 0,
      rank: 0,
      explorerCount: 0,
    );
  }
}
