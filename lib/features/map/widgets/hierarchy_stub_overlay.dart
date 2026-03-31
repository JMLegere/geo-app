import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/exploration_stats_provider.dart';
import 'package:earth_nova/core/state/hierarchy_repository_provider.dart';
import 'package:earth_nova/features/map/models/hierarchy_level.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Hierarchy screen for levels above district.
///
/// Loads sub-regions from [HierarchyRepository] and displays them in a
/// scrollable list with exploration stats. Falls back to "No data" when
/// tables are empty.
class HierarchyStubOverlay extends ConsumerStatefulWidget {
  const HierarchyStubOverlay({
    required this.level,
    required this.onNavigate,
    required this.onDismiss,
    super.key,
  });

  final HierarchyLevel level;

  /// Called when the user wants to navigate to a different level.
  /// Pass null to return to the map.
  final void Function(HierarchyLevel?) onNavigate;

  /// Called when dismissing (animation complete).
  final VoidCallback onDismiss;

  @override
  ConsumerState<HierarchyStubOverlay> createState() =>
      _HierarchyStubOverlayState();
}

class _HierarchyStubOverlayState extends ConsumerState<HierarchyStubOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  bool _isDismissing = false;

  // Loaded sub-regions
  List<_SubRegion> _subRegions = [];
  String _regionName = '';
  bool _isLoading = true;

  // Same colors as district infographic for visual consistency.
  static const _screenBg = Color(0xFF050C15);
  static const _cardBg = Color(0xFF0D1B2A);
  static const _heroPct = Color(0xFF83C5BE);
  static const _tealDark = Color(0xFF006D77);
  static const _statLabel = Color(0xFFADB5BD);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: Durations.slow,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: AppCurves.fadeIn);
    _fadeCtrl.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(hierarchyRepositoryProvider);
    final stats = ref.read(explorationStatsProvider).asData?.value ?? const {};

    List<_SubRegion> regions = [];
    String name = widget.level.label;

    try {
      switch (widget.level) {
        case HierarchyLevel.world:
          final countries = await repo.getAllCountries();
          name = 'Earth';
          regions = countries
              .map((c) => _SubRegion(
                    id: c.id,
                    name: c.name,
                    subtitle: c.continent,
                    stats: stats[c.id],
                  ))
              .toList();
        case HierarchyLevel.country:
          final countries = await repo.getAllCountries();
          if (countries.isNotEmpty) {
            final country = countries.first;
            name = country.name;
            final states = await repo.getStatesForCountry(country.id);
            regions = states
                .map((s) => _SubRegion(
                      id: s.id,
                      name: s.name,
                      stats: stats[s.id],
                    ))
                .toList();
          }
        case HierarchyLevel.state:
          final countries = await repo.getAllCountries();
          if (countries.isNotEmpty) {
            final states = await repo.getStatesForCountry(countries.first.id);
            if (states.isNotEmpty) {
              final state = states.first;
              name = state.name;
              final cities = await repo.getCitiesForState(state.id);
              regions = cities
                  .map((c) => _SubRegion(
                        id: c.id,
                        name: c.name,
                        subtitle: '${c.cellsTotal ?? 0} cells',
                        stats: stats[c.id],
                      ))
                  .toList();
            }
          }
        case HierarchyLevel.city:
          final countries = await repo.getAllCountries();
          if (countries.isNotEmpty) {
            final states = await repo.getStatesForCountry(countries.first.id);
            if (states.isNotEmpty) {
              final cities = await repo.getCitiesForState(states.first.id);
              if (cities.isNotEmpty) {
                final city = cities.first;
                name = city.name;
                final districts = await repo.getDistrictsForCity(city.id);
                regions = districts
                    .map((d) => _SubRegion(
                          id: d.id,
                          name: d.name,
                          subtitle: '${d.cellsTotal ?? 0} cells',
                          stats: stats[d.id],
                        ))
                    .toList();
              }
            }
          }
        case HierarchyLevel.district:
          break; // District uses DistrictInfographicOverlay, not this widget
      }
    } catch (e) {
      debugPrint('[Hierarchy] failed to load data: $e');
    }

    if (mounted) {
      setState(() {
        _subRegions = regions;
        _regionName = name;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _navigateDown() {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.mediumImpact();
    _fadeCtrl.reverse().then((_) {
      if (mounted) widget.onNavigate(widget.level.below);
    });
  }

  void _navigateUp() {
    final above = widget.level.above;
    if (above == null || _isDismissing) return;
    HapticFeedback.mediumImpact();
    widget.onNavigate(above);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onScaleUpdate: (details) {
          // Pinch in → navigate down
          if (details.scale > kInfographicPinchInThreshold) {
            _navigateDown();
          }
          // Pinch out → navigate up (only if not at top)
          if (details.pointerCount >= 2 &&
              details.scale < kInfographicPinchOutThreshold &&
              widget.level.above != null) {
            _navigateUp();
          }
        },
        child: Container(
          color: _screenBg,
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _navigateDown,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: Radii.borderXl,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                      Spacing.gapHSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _regionName,
                              style: theme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              '${widget.level.label.toUpperCase()} VIEW · ${_subRegions.length} regions',
                              style: theme.bodySmall?.copyWith(
                                color: _statLabel,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _heroPct),
                        )
                      : _subRegions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🗺',
                                    style: TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: Spacing.lg),
                                  const Text(
                                    'No data available',
                                    style: TextStyle(
                                      color: _statLabel,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.sm),
                                  Text(
                                    'Hierarchy data will appear after sync',
                                    style: TextStyle(
                                      color: _statLabel.withValues(alpha: 0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              itemCount: _subRegions.length,
                              itemBuilder: (context, index) {
                                final region = _subRegions[index];
                                final pct = region.stats?.percent ?? 0.0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: Radii.borderLg,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Exploration indicator dot
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: pct > 0
                                              ? Color.lerp(
                                                  _tealDark, _heroPct, pct)
                                              : _statLabel.withValues(
                                                  alpha: 0.3),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              region.name,
                                              style: theme.bodyLarge?.copyWith(
                                                  color: Colors.white),
                                            ),
                                            if (region.subtitle != null)
                                              Text(
                                                region.subtitle!,
                                                style: theme.bodySmall
                                                    ?.copyWith(
                                                        color: _statLabel),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Exploration percentage
                                      Text(
                                        pct > 0
                                            ? '${(pct * 100).toStringAsFixed(0)}%'
                                            : '—',
                                        style: theme.bodyMedium?.copyWith(
                                          color:
                                              pct > 0 ? _heroPct : _statLabel,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal sub-region data for the list view.
class _SubRegion {
  final String id;
  final String name;
  final String? subtitle;
  final ExplorationStats? stats;

  const _SubRegion({
    required this.id,
    required this.name,
    this.subtitle,
    this.stats,
  });
}
