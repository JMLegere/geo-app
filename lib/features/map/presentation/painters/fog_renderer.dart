import 'dart:ui';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class FogRenderer {
  FogRenderer._();

  static const double _kRenderDistanceKm = 2.0;
  static const bool overlayAntiAlias = true;
  static const bool usesUnknownBackdrop = true;
  static const String fillCompositingMode =
      'unknown_backdrop_src_relationship_paths';

  static Color fillColor(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => _presentFillColor(),
      CellKnowledgeState.informed ||
      CellKnowledgeState.explored =>
        _exploredFillColor(),
      CellKnowledgeState.shrouded => _unknownFillColor(),
    };
  }

  static Color strokeColor(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => _presentStrokeColor(),
      CellKnowledgeState.informed ||
      CellKnowledgeState.explored =>
        _exploredStrokeColor(),
      CellKnowledgeState.shrouded => _unknownStrokeColor(),
    };
  }

  static double seamGlowStrokeWidth(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 1.65,
      CellKnowledgeState.informed || CellKnowledgeState.explored => 1.0,
      CellKnowledgeState.shrouded => 0.0,
    };
  }

  static double seamStrokeWidth(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 1.0,
      CellKnowledgeState.informed || CellKnowledgeState.explored => 0.6,
      CellKnowledgeState.shrouded => 0.0,
    };
  }

  static double seamGlowBlurSigma(CellState state) {
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 0.7,
      CellKnowledgeState.informed || CellKnowledgeState.explored => 0.4,
      CellKnowledgeState.shrouded => 0.0,
    };
  }

  static bool animatesFog(CellState _) => false;

  static bool shouldRender(CellState _) => true;

  static bool isWithinRenderDistance(double? distanceKm) {
    if (distanceKm == null) return false;
    return distanceKm <= _kRenderDistanceKm;
  }

  static Color getHabitatStrokeColor(Cell cell) {
    return cell.blendedColor;
  }

  static Color _presentFillColor() {
    return const Color(0x00000000);
  }

  static Color _exploredFillColor() {
    return const Color(0x2ED8C49A);
  }

  static Color _unknownFillColor() {
    return const Color(0xFF000000);
  }

  static Color _presentStrokeColor() {
    return const Color(0xE6FFFFFF);
  }

  static Color _exploredStrokeColor() {
    return const Color(0xCC4A4A4A);
  }

  static Color _unknownStrokeColor() {
    return const Color(0x00000000);
  }
}
