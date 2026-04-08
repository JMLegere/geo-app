import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_header.dart';
import 'package:earth_nova/features/map/presentation/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class CityScreen extends ConsumerWidget {
  const CityScreen({super.key, this.scopeId});

  final String? scopeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = hierarchyScopeProvider(
      level: MapLevel.city,
      scopeId: scopeId,
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
      HierarchyStateLoading() => const _LoadingHeader(scopeLevel: 'CITY'),
      HierarchyStateData(:final scope, :final children) => HierarchyHeader(
          scopeLevel: 'CITY',
          scopeName: scope.name,
          scopeCode: _initials(scope.name),
          cellsVisited: scope.cellsVisited,
          cellsTotal: scope.cellsTotal,
          progressPercent: scope.progressPercent,
          rank: scope.rank,
          explorerCount: children.length,
        ),
      HierarchyStateError() => const _LoadingHeader(scopeLevel: 'CITY'),
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
        lowerLevelLabel: 'District',
        upperLevelLabel: 'Province',
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }
}

class _LoadingHeader extends StatelessWidget {
  const _LoadingHeader({required this.scopeLevel});

  final String scopeLevel;

  @override
  Widget build(BuildContext context) {
    return HierarchyHeader(
      scopeLevel: scopeLevel,
      scopeName: '—',
      scopeCode: '—',
      cellsVisited: 0,
      cellsTotal: 0,
      progressPercent: 0,
      rank: 0,
      explorerCount: 0,
    );
  }
}
