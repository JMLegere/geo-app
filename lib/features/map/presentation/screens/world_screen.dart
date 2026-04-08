import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_header.dart';
import 'package:earth_nova/features/map/presentation/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = hierarchyScopeProvider(
      level: MapLevel.world,
      scopeId: null,
      userId: '',
    );
    final hierarchyState = ref.watch(provider);

    return ColoredBox(
      color: AppTheme.surface,
      child: Column(
        children: [
          _buildHeader(hierarchyState),
          Expanded(child: _buildMap(hierarchyState)),
          _buildPinchHint(),
        ],
      ),
    );
  }

  Widget _buildHeader(HierarchyState state) {
    return switch (state) {
      HierarchyStateLoading() => const _LoadingHeader(),
      HierarchyStateData(:final scope, :final children) => HierarchyHeader(
          scopeLevel: 'WORLD',
          scopeName: scope.name,
          scopeCode: '🌍',
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
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: PinchHint(
        lowerLevelLabel: 'Country',
        upperLevelLabel: null,
      ),
    );
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader();

  @override
  Widget build(BuildContext context) {
    return const HierarchyHeader(
      scopeLevel: 'WORLD',
      scopeName: '—',
      scopeCode: '🌍',
      cellsVisited: 0,
      cellsTotal: 0,
      progressPercent: 0,
      rank: 0,
      explorerCount: 0,
    );
  }
}
