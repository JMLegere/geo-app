// ignore_for_file: avoid_print

import 'dart:ui';
import 'dart:io';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/diagnostics/map_render_diagnostics_service.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/features/map/presentation/rendering/cell_tessellation_render_model.dart';
import 'package:earth_nova/features/map/presentation/providers/map_fetch_coverage_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('benchmark: map render telemetry explains visual artifacts', () {
    final cellsWithStates = _badScreenshotLikeScene();
    final telemetry = const MapRenderDiagnosticsService().summarize(
      cellsWithStates: cellsWithStates,
      viewportSize: const Size(390, 844),
      project: _projectToFixtureViewport,
      markerScreenPosition: const Offset(195, 422),
      currentCellId: 'present',
      visitedCellCount: 4,
      markerIsRing: false,
      markerGapDistanceMeters: 0,
    );

    final renderableEntries = [
      for (final entry in cellsWithStates)
        if (FogRenderer.shouldRender(entry.state) &&
            entry.cell.hasRenderableGeometry)
          entry,
    ];
    final renderModel = CellTessellationRenderModel.build(
      cellsWithStates: renderableEntries,
      project: _projectToFixtureViewport,
    );

    final missingKeys = _missingRequiredTelemetryKeys(telemetry);
    final unresolvedHypotheses = _unresolvedHypotheses(telemetry);
    final styleGapCount = _missingKeysWithPrefix(missingKeys, 'style_').length;
    final renderModelGapCount =
        _missingKeysWithPrefix(missingKeys, 'render_model_').length;
    final projectionGapCount =
        _missingKeysWithPrefix(missingKeys, 'projection_').length;
    final markerGapCount =
        _missingKeysWithPrefix(missingKeys, 'marker_').length;
    final edgeClipDiagnosticGapCount = _edgeClipDiagnosticKeys
        .where((key) => !telemetry.containsKey(key))
        .length;
    final unknownBackdropGapCount = _unknownBackdropDiagnosticKeys
        .where((key) => !telemetry.containsKey(key))
        .length;
    final fogHardness = _fogHardnessScore(telemetry);
    final unknownBackdropHardness = _unknownBackdropHardnessScore(telemetry);
    final unknownCoverageGapCount = _unknownCoverageDiagnosticKeys
        .where((key) => !telemetry.containsKey(key))
        .length;
    final fetchSelection = _fetchSelectionScore();

    final coverageSource = _coverageSourceScore();
    final assignmentSource = _assignmentSourceScore();
    final coverageBufferParam = _coverageBufferParamScore();
    final stagingDropDiagnostics = _stagingDropDiagnosticScore();
    final previewDiagnostics = _previewDiagnosticsScore();
    final focusedPreview = _focusedPreviewScore();
    final latticePreviewSource = _latticePreviewSourceScore();
    final latticeDecode = _latticeDecodeScore();
    final coverageTelemetry = const MapRenderDiagnosticsService().summarize(
      cellsWithStates: [
        for (final entry in _coverageFixtureScene())
          if (entry.distanceMeters <= MapFetchCoveragePolicy.fetchRadiusMeters)
            (cell: entry.cell, state: entry.state),
      ],
      viewportSize: const Size(390, 844),
      project: _projectCoverageFixtureViewport,
      markerScreenPosition: const Offset(195, 422),
      currentCellId: 'coverage-present',
      visitedCellCount: 1,
      markerIsRing: false,
      markerGapDistanceMeters: 0,
    );
    final coverageShortfall = _coverageShortfallScore(coverageTelemetry);
    expect(telemetry['render_cell_count'], cellsWithStates.length);
    expect(renderModel.fillPaths, isNotEmpty);
    expect(renderModel.boundaryEdges, isNotEmpty);

    print('ASI observed_keys=${telemetry.keys.join(',')}');
    print('ASI missing_keys=${missingKeys.join(',')}');
    print('ASI unresolved_hypotheses=${unresolvedHypotheses.join(',')}');
    print('ASI truth_fill_path_count=${renderModel.fillPaths.length}');
    print('ASI truth_boundary_edge_count=${renderModel.boundaryEdges.length}');
    print(
      'ASI truth_frontier_fill_alpha='
      '${FogRenderer.fillColor(_frontierState).a.toStringAsFixed(3)}',
    );
    print('ASI fog_hardness_breakdown=${fogHardness.breakdown}');
    print(
      'ASI unknown_backdrop_hardness_breakdown='
      '${unknownBackdropHardness.breakdown}',
    );
    print(
      'ASI coverage_shortfall_breakdown=${coverageShortfall.breakdown}',
    );
    print('ASI fetch_selection_breakdown=${fetchSelection.breakdown}');
    print('ASI coverage_source_breakdown=${coverageSource.breakdown}');
    print('ASI assignment_source_breakdown=${assignmentSource.breakdown}');
    print(
      'ASI staging_drop_diagnostics_breakdown='
      '${stagingDropDiagnostics.breakdown}',
    );
    print('ASI preview_diagnostics_breakdown=${previewDiagnostics.breakdown}');
    print('ASI focused_preview_breakdown=${focusedPreview.breakdown}');
    print(
      'ASI lattice_preview_source_breakdown='
      '${latticePreviewSource.breakdown}',
    );
    print('ASI lattice_decode_breakdown=${latticeDecode.breakdown}');
    print(
      'ASI coverage_buffer_param_breakdown=${coverageBufferParam.breakdown}',
    );
    print('METRIC telemetry_gap_count=${missingKeys.length}');
    print('METRIC unresolved_hypothesis_count=${unresolvedHypotheses.length}');
    print('METRIC style_gap_count=$styleGapCount');
    print('METRIC render_model_gap_count=$renderModelGapCount');
    print('METRIC projection_gap_count=$projectionGapCount');
    print('METRIC marker_gap_count=$markerGapCount');
    print('METRIC coverage_source_gap_count=${coverageSource.score}');
    print('METRIC assignment_source_gap_count=${assignmentSource.score}');
    print(
      'METRIC staging_drop_diagnostic_gap_count='
      '${stagingDropDiagnostics.score}',
    );
    print('METRIC preview_diagnostics_gap_count=${previewDiagnostics.score}');
    print('METRIC focused_preview_gap_count=${focusedPreview.score}');
    print(
      'METRIC lattice_preview_source_gap_count='
      '${latticePreviewSource.score}',
    );
    print('METRIC lattice_decode_gap_count=${latticeDecode.score}');
    print(
      'METRIC coverage_buffer_param_gap_count=${coverageBufferParam.score}',
    );
    print('METRIC fog_hardness_score=${fogHardness.score}');
    print('METRIC frontier_alpha_excess=${fogHardness.frontierAlphaExcess}');
    print('METRIC explored_alpha_excess=${fogHardness.exploredAlphaExcess}');
    print('METRIC antialias_penalty=${fogHardness.antialiasPenalty}');
    print('METRIC edge_clip_diagnostic_gap_count=$edgeClipDiagnosticGapCount');
    print('METRIC unknown_backdrop_gap_count=$unknownBackdropGapCount');
    print(
      'METRIC unknown_backdrop_hardness_score='
      '${unknownBackdropHardness.score}',
    );
    print(
      'METRIC unknown_alpha_excess='
      '${unknownBackdropHardness.unknownAlphaExcess}',
    );
    print(
      'METRIC unknown_frontier_delta_excess='
      '${unknownBackdropHardness.unknownFrontierDeltaExcess}',
    );
    print('METRIC unknown_coverage_gap_count=$unknownCoverageGapCount');
    print(
      'METRIC fetch_coverage_shortfall_score=${coverageShortfall.score}',
    );
    print(
      'METRIC coverage_unknown_visible_excess='
      '${coverageShortfall.unknownVisibleExcess}',
    );
    print(
      'METRIC coverage_unknown_left_edge_excess='
      '${coverageShortfall.unknownLeftEdgeExcess}',
    );
    print('METRIC fetch_selection_gap_count=${fetchSelection.score}');
  });
}

const _presentState = CellState(
  relationship: CellRelationship.present,
  contents: CellContents.empty,
);
const _exploredState = CellState(
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);
const _frontierState = CellState(
  relationship: CellRelationship.frontier,
  contents: CellContents.empty,
);

List<({Cell cell, CellState state})> _badScreenshotLikeScene() => [
      (cell: _organicCell('present', 0.0000, 0.0000), state: _presentState),
      (
        cell: _organicCell('explored-west', 0.0007, -0.0014),
        state: _exploredState
      ),
      (
        cell: _organicCell('explored-south', -0.0012, -0.0001),
        state: _exploredState
      ),
      (
        cell: _organicCell('explored-east', 0.0002, 0.0014),
        state: _exploredState
      ),
      for (var i = 0; i < 18; i++)
        (
          cell: _organicCell(
            'frontier-$i',
            ((i ~/ 6) - 1) * 0.0023,
            ((i % 6) - 2.5) * 0.0020,
          ),
          state: _frontierState,
        ),
    ];

Cell _organicCell(String id, double latOffset, double lngOffset) => Cell(
      id: id,
      habitats: const [],
      polygons: [
        [
          [
            (lat: 45.96360 + latOffset, lng: -66.64310 + lngOffset),
            (lat: 45.96420 + latOffset, lng: -66.64230 + lngOffset),
            (lat: 45.96395 + latOffset, lng: -66.64125 + lngOffset),
            (lat: 45.96310 + latOffset, lng: -66.64105 + lngOffset),
            (lat: 45.96240 + latOffset, lng: -66.64190 + lngOffset),
            (lat: 45.96265 + latOffset, lng: -66.64300 + lngOffset),
            (lat: 45.96360 + latOffset, lng: -66.64310 + lngOffset),
          ],
        ],
      ],
      districtId: 'downtown',
      cityId: 'fredericton',
      stateId: 'nb',
      countryId: 'ca',
      geometrySourceVersion: 'organic-voronoi-beta-v1',
      geometryGenerationMode: 'db-deterministic-jittered-centroid-voronoi',
      centroidDatasetVersion: 'benchmark-fixture-v1',
      geometryContract: 'true-voronoi-clipped-to-lattice-coverage',
    );

Offset _projectToFixtureViewport(GeoCoord coord) {
  const centerLat = 45.9636;
  const centerLng = -66.6431;
  const pixelsPerDegree = 90000.0;
  return Offset(
    195 + ((coord.lng - centerLng) * pixelsPerDegree),
    422 - ((coord.lat - centerLat) * pixelsPerDegree),
  );
}

List<({Cell cell, CellState state, double distanceMeters})>
    _coverageFixtureScene() => [
          (
            cell: _screenRectCell('coverage-present', 60, 260, 260, 600),
            state: _presentState,
            distanceMeters: 0,
          ),
          (
            cell: _screenRectCell('coverage-top', 60, 0, 390, 260),
            state: _frontierState,
            distanceMeters: 1800,
          ),
          (
            cell: _screenRectCell('coverage-right', 260, 260, 390, 844),
            state: _frontierState,
            distanceMeters: 1800,
          ),
          (
            cell: _screenRectCell('coverage-bottom', 60, 600, 260, 844),
            state: _frontierState,
            distanceMeters: 1800,
          ),
          (
            cell: _screenRectCell('coverage-left', 0, 0, 60, 844),
            state: _frontierState,
            distanceMeters: 2200,
          ),
        ];

Cell _screenRectCell(
  String id,
  double left,
  double top,
  double right,
  double bottom,
) =>
    Cell(
      id: id,
      habitats: const [],
      polygons: [
        [
          [
            (lat: top, lng: left),
            (lat: top, lng: right),
            (lat: bottom, lng: right),
            (lat: bottom, lng: left),
            (lat: top, lng: left),
          ],
        ],
      ],
      districtId: 'coverage',
      cityId: 'coverage',
      stateId: 'coverage',
      countryId: 'coverage',
    );

Offset _projectCoverageFixtureViewport(GeoCoord coord) =>
    Offset(coord.lng, coord.lat);

List<String> _missingRequiredTelemetryKeys(Map<String, dynamic> telemetry) {
  const requiredKeys = [
    // Data/geometry discriminates organic cell payloads from square fallback data.
    'render_cell_count',
    'render_present_cell_count',
    'render_explored_cell_count',
    'render_frontier_cell_count',
    'render_rectangular_cell_count',
    'render_axis_aligned_edge_ratio',
    'render_shape_warnings',

    // Fog-state context explains why only small islands are revealed.
    'state_current_cell_id',
    'state_visited_cell_count',
    'state_present_cell_ids_sample',
    'state_explored_cell_ids_sample',
    'state_frontier_cell_ids_sample',

    // Style/compositing explains harsh wedges, darkness, seams, and antialiasing.
    'style_present_fill_alpha',
    'style_explored_fill_alpha',
    'style_frontier_fill_alpha',
    'style_unknown_fill_alpha',
    'style_present_stroke_alpha',
    'style_explored_stroke_alpha',
    'style_frontier_stroke_alpha',
    'style_overlay_antialias',
    'style_fill_grouping_mode',
    ..._unknownBackdropDiagnosticKeys,

    // Render-model context explains whether Canvas path grouping/seams caused it.
    'render_model_fill_path_count',
    'render_model_fill_relationships',
    'render_model_boundary_edge_count',
    'render_model_present_boundary_edge_count',
    'render_model_explored_boundary_edge_count',
    'render_model_hidden_same_state_boundary_count',

    // Projection/viewport context explains screen-space slabs and edge clipping.
    'projection_viewport_width_px',
    'projection_viewport_height_px',
    'projection_polygon_count',
    'projection_largest_bbox_area_ratio',
    'projection_viewport_edge_crossing_count',
    'projection_axis_aligned_screen_edge_ratio',
    ..._edgeClipDiagnosticKeys,
    ..._unknownCoverageDiagnosticKeys,

    // Marker context explains whether the visible circle is fog or player chrome.
    'marker_screen_x',
    'marker_screen_y',
    'marker_radius_px',
    'marker_ring_radius_px',
    'marker_is_ring',
    'marker_gap_distance_m',
    'marker_visual_mode',
    'marker_overlaps_present_cell',
  ];

  return [
    for (final key in requiredKeys)
      if (!telemetry.containsKey(key)) key,
  ];
}

const _edgeClipDiagnosticKeys = [
  'projection_present_polygon_count',
  'projection_explored_polygon_count',
  'projection_frontier_polygon_count',
  'projection_present_viewport_edge_crossing_count',
  'projection_explored_viewport_edge_crossing_count',
  'projection_frontier_viewport_edge_crossing_count',
  'projection_present_largest_bbox_area_ratio',
  'projection_explored_largest_bbox_area_ratio',
  'projection_frontier_largest_bbox_area_ratio',
];

const _unknownBackdropDiagnosticKeys = [
  'style_uses_unknown_backdrop',
  'style_fill_compositing_mode',
];

const _unknownCoverageDiagnosticKeys = [
  'projection_unknown_visible_ratio',
  'projection_unknown_left_edge_ratio',
  'projection_unknown_top_edge_ratio',
  'projection_unknown_right_edge_ratio',
  'projection_unknown_bottom_edge_ratio',
];

List<String> _unresolvedHypotheses(Map<String, dynamic> telemetry) {
  final hypotheses = <String>[];
  if (!telemetry.containsKey('render_rectangular_cell_count') ||
      !telemetry.containsKey('render_axis_aligned_edge_ratio')) {
    hypotheses.add('geometry_fallback_or_rectangular_payload');
  }
  if (!telemetry.containsKey('style_frontier_fill_alpha') ||
      !telemetry.containsKey('style_overlay_antialias')) {
    hypotheses.add('fog_style_or_compositing');
  }
  if (!telemetry.containsKey('render_model_boundary_edge_count') ||
      !telemetry.containsKey('render_model_fill_relationships')) {
    hypotheses.add('canvas_render_model_or_seams');
  }
  if (!telemetry.containsKey('projection_largest_bbox_area_ratio') ||
      !telemetry.containsKey('projection_viewport_edge_crossing_count')) {
    hypotheses.add('projection_or_viewport_clipping');
  }
  if (!telemetry.containsKey('marker_is_ring') ||
      !telemetry.containsKey('marker_visual_mode') ||
      !telemetry.containsKey('marker_ring_radius_px') ||
      !telemetry.containsKey('marker_overlaps_present_cell')) {
    hypotheses.add('player_marker_circle_artifact');
  }
  return hypotheses;
}

List<String> _missingKeysWithPrefix(List<String> missingKeys, String prefix) =>
    [
      for (final key in missingKeys)
        if (key.startsWith(prefix)) key,
    ];

_FogHardnessScore _fogHardnessScore(Map<String, dynamic> telemetry) {
  final frontierAlpha = telemetry['style_frontier_fill_alpha'] as double;
  final exploredAlpha = telemetry['style_explored_fill_alpha'] as double;
  final antialias = telemetry['style_overlay_antialias'] as bool;
  final frontierAlphaExcess =
      _scaledExcess(value: frontierAlpha, targetMax: 0.32);
  final exploredAlphaExcess =
      _scaledExcess(value: exploredAlpha, targetMax: 0.22);
  final antialiasPenalty = antialias ? 0 : 10;
  return _FogHardnessScore(
    score: frontierAlphaExcess + exploredAlphaExcess + antialiasPenalty,
    frontierAlphaExcess: frontierAlphaExcess,
    exploredAlphaExcess: exploredAlphaExcess,
    antialiasPenalty: antialiasPenalty,
    breakdown:
        'frontier_alpha=$frontierAlpha explored_alpha=$exploredAlpha antialias=$antialias',
  );
}

int _scaledExcess({required double value, required double targetMax}) {
  final excess = value - targetMax;
  return excess <= 0 ? 0 : (excess * 100).round();
}

class _FogHardnessScore {
  const _FogHardnessScore({
    required this.score,
    required this.frontierAlphaExcess,
    required this.exploredAlphaExcess,
    required this.antialiasPenalty,
    required this.breakdown,
  });

  final int score;
  final int frontierAlphaExcess;
  final int exploredAlphaExcess;
  final int antialiasPenalty;
  final String breakdown;
}

_UnknownBackdropHardnessScore _unknownBackdropHardnessScore(
  Map<String, dynamic> telemetry,
) {
  final unknownAlpha = telemetry['style_unknown_fill_alpha'] as double;
  final frontierAlpha = telemetry['style_frontier_fill_alpha'] as double;
  final unknownAlphaExcess =
      _scaledExcess(value: unknownAlpha, targetMax: 0.48);
  final unknownFrontierDeltaExcess = _scaledExcess(
    value: unknownAlpha - frontierAlpha,
    targetMax: 0.18,
  );
  return _UnknownBackdropHardnessScore(
    score: unknownAlphaExcess + unknownFrontierDeltaExcess,
    unknownAlphaExcess: unknownAlphaExcess,
    unknownFrontierDeltaExcess: unknownFrontierDeltaExcess,
    breakdown:
        'unknown_alpha=$unknownAlpha frontier_alpha=$frontierAlpha delta=${unknownAlpha - frontierAlpha}',
  );
}

class _UnknownBackdropHardnessScore {
  const _UnknownBackdropHardnessScore({
    required this.score,
    required this.unknownAlphaExcess,
    required this.unknownFrontierDeltaExcess,
    required this.breakdown,
  });

  final int score;
  final int unknownAlphaExcess;
  final int unknownFrontierDeltaExcess;
  final String breakdown;
}

_CoverageShortfallScore _coverageShortfallScore(
    Map<String, dynamic> telemetry) {
  final unknownVisibleRatio =
      telemetry['projection_unknown_visible_ratio'] as double;
  final unknownLeftEdgeRatio =
      telemetry['projection_unknown_left_edge_ratio'] as double;
  final unknownVisibleExcess =
      _scaledExcess(value: unknownVisibleRatio, targetMax: 0.0);
  final unknownLeftEdgeExcess =
      _scaledExcess(value: unknownLeftEdgeRatio, targetMax: 0.0);
  return _CoverageShortfallScore(
    score: unknownVisibleExcess + unknownLeftEdgeExcess,
    unknownVisibleExcess: unknownVisibleExcess,
    unknownLeftEdgeExcess: unknownLeftEdgeExcess,
    breakdown:
        'unknown_visible=$unknownVisibleRatio unknown_left=$unknownLeftEdgeRatio fetch_radius=${MapFetchCoveragePolicy.fetchRadiusMeters}',
  );
}

class _CoverageShortfallScore {
  const _CoverageShortfallScore({
    required this.score,
    required this.unknownVisibleExcess,
    required this.unknownLeftEdgeExcess,
    required this.breakdown,
  });

  final int score;
  final int unknownVisibleExcess;
  final int unknownLeftEdgeExcess;
  final String breakdown;
}

_FetchSelectionScore _fetchSelectionScore() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final target = candidates.reversed.firstWhere(
    (file) =>
        file.readAsStringSync().contains('CREATE FUNCTION fetch_nearby_cells('),
  );
  final sql = target.readAsStringSync();
  final createIndex = sql.lastIndexOf('CREATE FUNCTION fetch_nearby_cells(');
  final functionSql = createIndex >= 0 ? sql.substring(createIndex) : sql;
  final usesCentroidDistance = functionSql.contains(
    'ST_SetSRID(ST_MakePoint(model.centroid_lon, model.centroid_lat), 4326)::geography',
  );
  final usesGeometryDistance = functionSql.contains('geom::geography');
  return _FetchSelectionScore(
    score: usesGeometryDistance ? 0 : 1,
    breakdown:
        'migration=${target.uri.pathSegments.last} centroid_distance=$usesCentroidDistance geometry_distance=$usesGeometryDistance',
  );
}

class _FetchSelectionScore {
  const _FetchSelectionScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_CoverageSourceScore _coverageSourceScore() {
  final stageFunction = _latestStageFunctionDefinition();
  final functionSql = stageFunction.functionSql;
  final usesBufferedCoverage = functionSql.contains('ST_Buffer(');
  final writesMissingMetadataColumn =
      functionSql.contains('INSERT INTO cell_geometry_versions (') &&
          functionSql.contains('    metadata');
  final writesMissingValidationMessageColumn =
      functionSql.contains('    validation_message');
  final includesStagingRuntimeColumns = functionSql.contains('raw_geometry') &&
      functionSql.contains('parsed_bbox') &&
      functionSql.contains('parsed_area_m2') &&
      functionSql.contains('validation_errors');
  return _CoverageSourceScore(
    score: usesBufferedCoverage &&
            !writesMissingMetadataColumn &&
            !writesMissingValidationMessageColumn &&
            includesStagingRuntimeColumns
        ? 0
        : 1,
    breakdown:
        'migration=${stageFunction.migrationName} buffered_coverage=$usesBufferedCoverage writes_missing_metadata_column=$writesMissingMetadataColumn writes_missing_validation_message_column=$writesMissingValidationMessageColumn includes_staging_runtime_columns=$includesStagingRuntimeColumns',
  );
}

class _CoverageSourceScore {
  const _CoverageSourceScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_AssignmentSourceScore _assignmentSourceScore() {
  final stageFunction = _latestStageFunctionDefinition();
  final functionSql = stageFunction.functionSql;
  final usesContainmentAssignment = functionSql.contains('ST_Covers(');
  return _AssignmentSourceScore(
    score: usesContainmentAssignment ? 0 : 1,
    breakdown:
        'migration=${stageFunction.migrationName} uses_containment_assignment=$usesContainmentAssignment',
  );
}

class _AssignmentSourceScore {
  const _AssignmentSourceScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_CoverageBufferParamScore _coverageBufferParamScore() {
  final stageFunction = _latestStageFunctionDefinition();
  final functionSql = stageFunction.functionSql;
  final exposesBufferParam = functionSql.contains(
    'p_coverage_buffer_meters DOUBLE PRECISION',
  );
  final usesBufferParam = functionSql.contains('p_coverage_buffer_meters');
  return _CoverageBufferParamScore(
    score: exposesBufferParam && usesBufferParam ? 0 : 1,
    breakdown:
        'migration=${stageFunction.migrationName} exposes_buffer_param=$exposesBufferParam uses_buffer_param=$usesBufferParam',
  );
}

class _CoverageBufferParamScore {
  const _CoverageBufferParamScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

({String migrationName, String functionSql}) _latestStageFunctionDefinition() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final target = candidates.reversed.firstWhere(
    (file) =>
        file.readAsStringSync().contains(
              'CREATE OR REPLACE FUNCTION stage_cell_geometry_from_organic_centroids(',
            ) ||
        file.readAsStringSync().contains(
              'CREATE FUNCTION stage_cell_geometry_from_organic_centroids(',
            ),
  );
  final sql = target.readAsStringSync();
  const createOrReplace =
      'CREATE OR REPLACE FUNCTION stage_cell_geometry_from_organic_centroids(';
  const createOnly =
      'CREATE FUNCTION stage_cell_geometry_from_organic_centroids(';
  final createIndex = [
    sql.lastIndexOf(createOrReplace),
    sql.lastIndexOf(createOnly),
  ].reduce((a, b) => a > b ? a : b);
  final functionSql = createIndex >= 0 ? sql.substring(createIndex) : sql;
  return (
    migrationName: target.uri.pathSegments.last,
    functionSql: functionSql,
  );
}

_StagingDropDiagnosticScore _stagingDropDiagnosticScore() {
  final stageFunction = _latestStageFunctionDefinition();
  final functionSql = stageFunction.functionSql;
  final emitsNullReason = functionSql.contains('geometry_null_after_clip');
  final emitsEmptyReason = functionSql.contains('geometry_empty_after_clip');
  final emitsInvalidReason =
      functionSql.contains('geometry_invalid_after_clip');
  final emitsAreaReason =
      functionSql.contains('geometry_nonpositive_area_after_clip');
  final stillSilentlyFilters = functionSql.contains('WHERE geom IS NOT NULL') &&
      functionSql.contains('ST_Area(geom::geography) > 0');
  return _StagingDropDiagnosticScore(
    score: emitsNullReason &&
            emitsEmptyReason &&
            emitsInvalidReason &&
            emitsAreaReason &&
            !stillSilentlyFilters
        ? 0
        : 1,
    breakdown:
        'migration=${stageFunction.migrationName} null=$emitsNullReason empty=$emitsEmptyReason invalid=$emitsInvalidReason area=$emitsAreaReason silent_filter=$stillSilentlyFilters',
  );
}

class _StagingDropDiagnosticScore {
  const _StagingDropDiagnosticScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_PreviewDiagnosticsScore _previewDiagnosticsScore() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final matches = candidates.reversed.where(
    (file) => file.readAsStringSync().contains(
          'CREATE FUNCTION diagnose_stage_cell_geometry_from_organic_centroids(',
        ),
  );
  if (matches.isEmpty) {
    return const _PreviewDiagnosticsScore(
      score: 1,
      breakdown: 'migration=none function_present=false',
    );
  }
  final target = matches.first;
  final sql = target.readAsStringSync();
  final hasReasonCounts = sql.contains('null_geom_count') &&
      sql.contains('empty_geom_count') &&
      sql.contains('invalid_geom_count') &&
      sql.contains('nonpositive_area_count');
  return _PreviewDiagnosticsScore(
    score: hasReasonCounts ? 0 : 1,
    breakdown:
        'migration=${target.uri.pathSegments.last} function_present=true has_reason_counts=$hasReasonCounts',
  );
}

class _PreviewDiagnosticsScore {
  const _PreviewDiagnosticsScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_FocusedPreviewScore _focusedPreviewScore() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final matches = candidates.reversed.where(
    (file) => file.readAsStringSync().contains(
          'CREATE FUNCTION diagnose_stage_cell_geometry_boundary_window(',
        ),
  );
  if (matches.isEmpty) {
    return const _FocusedPreviewScore(
      score: 1,
      breakdown: 'migration=none function_present=false',
    );
  }
  final target = matches.first;
  final sql = target.readAsStringSync();
  final hasFocusParams = sql.contains('p_focus_lat DOUBLE PRECISION') &&
      sql.contains('p_focus_lng DOUBLE PRECISION') &&
      sql.contains('p_focus_radius_meters DOUBLE PRECISION');
  final hasReasonCounts = sql.contains('null_geom_count') &&
      sql.contains('empty_geom_count') &&
      sql.contains('invalid_geom_count') &&
      sql.contains('nonpositive_area_count');
  return _FocusedPreviewScore(
    score: hasFocusParams && hasReasonCounts ? 0 : 1,
    breakdown:
        'migration=${target.uri.pathSegments.last} function_present=true has_focus_params=$hasFocusParams has_reason_counts=$hasReasonCounts',
  );
}

class _FocusedPreviewScore {
  const _FocusedPreviewScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_LatticePreviewSourceScore _latticePreviewSourceScore() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final matches = candidates.reversed.where(
    (file) =>
        file.readAsStringSync().contains(
              'CREATE OR REPLACE FUNCTION diagnose_stage_cell_geometry_boundary_window(',
            ) ||
        file.readAsStringSync().contains(
              'CREATE FUNCTION diagnose_stage_cell_geometry_boundary_window(',
            ),
  );
  if (matches.isEmpty) {
    return const _LatticePreviewSourceScore(
      score: 1,
      breakdown: 'migration=none function_present=false',
    );
  }
  final target = matches.first;
  final sql = target.readAsStringSync();
  final focusStart = sql.indexOf('focus_cells AS (');
  final siteStart = sql.indexOf('site_cells AS (');
  final jitteredStart = sql.indexOf('jittered AS (');
  final focusSql = focusStart >= 0 && siteStart > focusStart
      ? sql.substring(focusStart, siteStart)
      : '';
  final siteSql = siteStart >= 0 && jitteredStart > siteStart
      ? sql.substring(siteStart, jitteredStart)
      : '';
  final focusUsesCellProperties =
      focusSql.contains('FROM lattice_cells lattice');
  final siteUsesCellProperties = siteSql.contains('FROM lattice_cells lattice');
  return _LatticePreviewSourceScore(
    score: focusUsesCellProperties && siteUsesCellProperties ? 0 : 1,
    breakdown:
        'migration=${target.uri.pathSegments.last} focus_uses_cell_properties=$focusUsesCellProperties site_uses_cell_properties=$siteUsesCellProperties',
  );
}

class _LatticePreviewSourceScore {
  const _LatticePreviewSourceScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}

_LatticeDecodeScore _latticeDecodeScore() {
  final migrationsDir = Directory(
    '${Directory.current.path}/supabase/migrations',
  );
  final candidates = migrationsDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final matches = candidates.reversed.where(
    (file) =>
        file.readAsStringSync().contains(
              'CREATE OR REPLACE FUNCTION diagnose_stage_cell_geometry_boundary_window(',
            ) ||
        file.readAsStringSync().contains(
              'CREATE FUNCTION diagnose_stage_cell_geometry_boundary_window(',
            ),
  );
  if (matches.isEmpty) {
    return const _LatticeDecodeScore(
      score: 1,
      breakdown: 'migration=none function_present=false',
    );
  }
  final target = matches.first;
  final sql = target.readAsStringSync();
  final usesLatFromPart2 = sql.contains(
    "split_part(cp.cell_id, '_', 2)::INTEGER / 500.0 AS original_center_lat",
  );
  final usesLngFromPart3 = sql.contains(
    "split_part(cp.cell_id, '_', 3)::INTEGER / 500.0 AS original_center_lng",
  );
  final makePointUsesLngThenLat = sql.contains(
    "ST_MakePoint(\n          split_part(cp.cell_id, '_', 3)::INTEGER / 500.0,\n          split_part(cp.cell_id, '_', 2)::INTEGER / 500.0",
  );
  return _LatticeDecodeScore(
    score:
        usesLatFromPart2 && usesLngFromPart3 && makePointUsesLngThenLat ? 0 : 1,
    breakdown:
        'migration=${target.uri.pathSegments.last} lat_from_part2=$usesLatFromPart2 lng_from_part3=$usesLngFromPart3 point_lng_lat=$makePointUsesLngThenLat',
  );
}

class _LatticeDecodeScore {
  const _LatticeDecodeScore({
    required this.score,
    required this.breakdown,
  });

  final int score;
  final String breakdown;
}
