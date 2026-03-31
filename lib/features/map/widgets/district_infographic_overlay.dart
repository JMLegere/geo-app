import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/models/hierarchy.dart';
import 'package:earth_nova/core/state/detection_zone_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/features/map/models/district_infographic_data.dart';
import 'package:earth_nova/features/map/widgets/district_infographic_painter.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Full-screen district infographic overlay.
///
/// Shows a dark background with explored cell polygons, district boundary,
/// player marker, and exploration stats. Built as a Stack overlay on top
/// of the map — map stays alive underneath (gameplay not paused).
///
/// Dismissed via the back button or pinch-in gesture.
class DistrictInfographicOverlay extends ConsumerStatefulWidget {
  const DistrictInfographicOverlay({
    required this.onDismiss,
    required this.districtDataMap,
    required this.cellService,
    this.onNavigateUp,
    this.onCloseGestureUpdate,
    this.onCloseGestureEnd,
    super.key,
  });

  final VoidCallback onDismiss;

  /// Called when the user pinch-outs to navigate up to city level.
  final VoidCallback? onNavigateUp;

  /// Called on each scale update during a close gesture (pinch-spread on overlay).
  final void Function(double scale)? onCloseGestureUpdate;

  /// Called when the close gesture ends. Reports scale velocity (units/sec).
  final void Function(double scaleVelocity)? onCloseGestureEnd;

  /// Cached district data map from map_screen (already loaded).
  final Map<String, HDistrict> districtDataMap;

  /// Cell service for looking up cell boundaries.
  final CellService cellService;

  @override
  ConsumerState<DistrictInfographicOverlay> createState() =>
      _DistrictInfographicOverlayState();
}

class _DistrictInfographicOverlayState
    extends ConsumerState<DistrictInfographicOverlay>
    with TickerProviderStateMixin {
  DistrictInfographicData? _data;
  bool _isDismissing = false;

  // Scale velocity tracking for close gesture.
  double _prevScale = 1.0;
  int _prevScaleTimeMs = 0;
  double _scaleVelocity = 0.0;

  // Player marker pulse (2s loop = Durations.markerPulse).
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Designer-specified colors.
  static const _screenBg = Color(0xFF050C15);
  static const _progressTrack = Color(0xFF1A2D40);
  static const _progressStart = Color(0xFF006D77);
  static const _progressEnd = Color(0xFF83C5BE);
  static const _heroPct = Color(0xFF83C5BE);
  static const _statValue = Color(0xFFE0E1DD);
  static const _statLabel = Color(0xFFADB5BD);
  static const _dividerColor = Color(0x803D5060); // 0.5 opacity
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Durations.markerPulse,
    )..repeat();
    _pulseAnim = _pulseCtrl;

    _buildSnapshot();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    DistrictInfographicPainter.clearCache();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    HapticFeedback.mediumImpact();
    debugPrint('[DistrictInfographic] dismissed');
    widget.onDismiss();
  }

  void _buildSnapshot() {
    final detectionZone = ref.read(detectionZoneServiceProvider);
    final districtId = detectionZone.currentDistrictId;
    if (districtId == null) {
      debugPrint('[DistrictInfographic] abort: no districtId');
      return;
    }

    final fogResolver = ref.read(fogResolverProvider);
    final loc = ref.read(locationProvider);
    final itemsState = ref.read(itemsProvider);

    // Get district data for name + geometry.
    final district = widget.districtDataMap[districtId];
    final districtName = district?.name ?? 'District';
    final geometryJson = district?.boundaryJson;

    // Get all cells attributed to this district.
    final attribution = detectionZone.cellDistrictAttribution;
    final allCellIds = attribution.entries
        .where((e) => e.value == districtId)
        .map((e) => e.key)
        .toList();

    // Intersect with visited cells to get explored cells.
    final allCellIdSet = allCellIds.toSet();
    final exploredCellIds =
        fogResolver.visitedCellIds.intersection(allCellIdSet);

    // Pre-compute cell boundaries for explored cells only.
    final exploredCellBoundaries = <String, List<Geographic>>{};
    for (final cellId in exploredCellIds) {
      try {
        final boundary = widget.cellService.getCellBoundary(cellId);
        if (boundary.length >= 3) {
          exploredCellBoundaries[cellId] = boundary;
        }
      } catch (_) {
        // Skip cells with boundary computation errors.
      }
    }

    // Parse district boundary.
    final boundaryRings =
        DistrictInfographicData.parseBoundaryRings(geometryJson);

    // Compute bounding box from all cell centers (more reliable than boundary).
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final cellId in allCellIds) {
      try {
        final center = widget.cellService.getCellCenter(cellId);
        if (center.lat < minLat) minLat = center.lat;
        if (center.lat > maxLat) maxLat = center.lat;
        if (center.lon < minLon) minLon = center.lon;
        if (center.lon > maxLon) maxLon = center.lon;
      } catch (_) {
        // Skip cells with center computation errors.
      }
    }

    // Fallback if no cells computed a valid bbox.
    if (minLat > maxLat || minLon > maxLon) {
      if (loc.currentPosition != null) {
        minLat = loc.currentPosition!.lat - 0.01;
        maxLat = loc.currentPosition!.lat + 0.01;
        minLon = loc.currentPosition!.lon - 0.01;
        maxLon = loc.currentPosition!.lon + 0.01;
      } else {
        return; // No data to show.
      }
    }

    // Prevent degenerate bounding box (single cell → zero range → no rendering).
    if ((maxLat - minLat) < 0.0001) {
      minLat -= 0.005;
      maxLat += 0.005;
    }
    if ((maxLon - minLon) < 0.0001) {
      minLon -= 0.005;
      maxLon += 0.005;
    }

    _data = DistrictInfographicData(
      districtName: districtName,
      districtId: districtId,
      boundaryRings: boundaryRings,
      allCellIds: allCellIds,
      exploredCellIds: exploredCellIds,
      exploredCellBoundaries: exploredCellBoundaries,
      playerLat: loc.currentPosition?.lat ?? (minLat + maxLat) / 2,
      playerLon: loc.currentPosition?.lon ?? (minLon + maxLon) / 2,
      totalSpeciesFound: itemsState.uniqueDefinitionIds.length,
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );

    debugPrint('[DistrictInfographic] open: district=$districtName '
        'cells=${allCellIds.length} explored=${exploredCellIds.length} '
        'boundaries=${exploredCellBoundaries.length} '
        'species=${itemsState.uniqueDefinitionIds.length}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final data = _data;

    return GestureDetector(
      onScaleStart: (details) {
        _prevScale = 1.0;
        _prevScaleTimeMs = DateTime.now().millisecondsSinceEpoch;
        _scaleVelocity = 0.0;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          // Compute scale velocity.
          final now = DateTime.now().millisecondsSinceEpoch;
          final dt = (now - _prevScaleTimeMs) / 1000.0;
          if (dt > 0 && _prevScaleTimeMs > 0) {
            _scaleVelocity = (details.scale - _prevScale) / dt;
          }
          _prevScale = details.scale;
          _prevScaleTimeMs = now;

          // Report close gesture (spreading = scale > 1.0).
          if (details.scale > 1.0) {
            widget.onCloseGestureUpdate?.call(details.scale);
          }

          // Navigate up on extreme squeeze (scale < 0.5).
          if (details.scale < 0.5 && widget.onNavigateUp != null) {
            widget.onNavigateUp!();
          }
        }
      },
      onScaleEnd: (_) {
        widget.onCloseGestureEnd?.call(_scaleVelocity);
        _prevScale = 1.0;
        _prevScaleTimeMs = 0;
        _scaleVelocity = 0.0;
      },
      child: Container(
        color: _screenBg,
        child: data == null
            ? _buildNoData(context)
            : SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, theme, data),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => CustomPaint(
                            painter: DistrictInfographicPainter(
                              data: data,
                              pulseProgress: _pulseAnim.value,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                    _buildStatsBar(context, theme, data),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNoData(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: const Center(
        child: Text(
          'District data not available',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    TextTheme theme,
    DistrictInfographicData data,
  ) {
    // Build breadcrumb from district data if available.
    final district = widget.districtDataMap[data.districtId];
    final breadcrumb = district != null ? 'DISTRICT · ${data.districtId}' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Frosted-glass back button.
          _FrostedButton(
            icon: Icons.arrow_back,
            onTap: _dismiss,
          ),
          Spacing.gapHSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.districtName,
                  style: theme.headlineSmall?.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (breadcrumb.isNotEmpty)
                  Text(
                    breadcrumb,
                    style: theme.bodySmall?.copyWith(
                      color: _statLabel,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(
    BuildContext context,
    TextTheme theme,
    DistrictInfographicData data,
  ) {
    final exploredCount = data.exploredCellIds.length;
    final pct = (data.explorationPercent * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Exploration label + hero percentage.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EXPLORATION',
                style: theme.labelSmall?.copyWith(
                  color: _statLabel,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: _heroPct,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Gradient progress bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  // Track.
                  Container(color: _progressTrack),
                  // Fill.
                  FractionallySizedBox(
                    widthFactor: data.explorationPercent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_progressStart, _progressEnd],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Stat pills row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatPill(
                icon: '🗺',
                value: exploredCount.toString(),
                label: 'CELLS',
                valueStyle: theme.bodyMedium?.copyWith(
                  color: _statValue,
                  fontWeight: FontWeight.w700,
                ),
                labelStyle: theme.labelSmall?.copyWith(
                  color: _statLabel,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: _dividerColor,
              ),
              _StatPill(
                icon: '🔬',
                value: data.totalSpeciesFound.toString(),
                label: 'SPECIES',
                valueStyle: theme.bodyMedium?.copyWith(
                  color: _statValue,
                  fontWeight: FontWeight.w700,
                ),
                labelStyle: theme.labelSmall?.copyWith(
                  color: _statLabel,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

/// Frosted-glass icon button (back button in header).
class _FrostedButton extends StatelessWidget {
  const _FrostedButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

/// Stat pill: emoji icon + numeric value + label.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.valueStyle,
    this.labelStyle,
  });

  final String icon;
  final String value;
  final String label;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: valueStyle),
        Text(label, style: labelStyle),
      ],
    );
  }
}
