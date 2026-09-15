import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_header.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

class CountryScreen extends ConsumerWidget {
  const CountryScreen({
    super.key,
    this.scopeId,
    this.onLowerLevelTap,
    this.onUpperLevelTap,
  });

  final String? scopeId;
  final VoidCallback? onLowerLevelTap;
  final VoidCallback? onUpperLevelTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);
    final authState = ref.watch(authProvider);
    final userId = authState.status == AuthStatus.authenticated
        ? authState.user!.id
        : '';
    final hierarchyState = ref.watch(
      hierarchyScopeProvider((
        level: MapLevel.country,
        scopeId: scopeId,
        userId: userId,
      )),
    );

    return ObservableScreen(
      screenName: 'country_screen',
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
      HierarchyStateLoading() => const _LoadingHeader(scopeLevel: 'Country'),
      HierarchyStateData(:final scope, :final children) => HierarchyHeader(
        scopeLevel: 'Country',
        scopeName: scope.name,
        scopeCode: _initials(scope.name),
        cellsVisited: scope.cellsVisited,
        cellsTotal: scope.cellsTotal,
        progressPercent: scope.progressPercent,
        rank: scope.rank,
        explorerCount: children.length,
      ),
      HierarchyStateError() => const _LoadingHeader(scopeLevel: 'Country'),
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
        lowerLevelLabel: 'State',
        upperLevelLabel: 'World',
        onLowerLevelTap: onLowerLevelTap,
        onUpperLevelTap: onUpperLevelTap,
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
