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
    if (state.knowledgeState == CellKnowledgeState.shrouded &&
        state.relationship == CellRelationship.frontier) {
      return _frontierFillColor();
    }
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => _presentFillColor(),
      CellKnowledgeState.informed => _informedFillColor(),
      CellKnowledgeState.explored => _exploredFillColor(),
      CellKnowledgeState.shrouded => _unknownFillColor(),
    };
  }

  static Color strokeColor(CellState state) {
    if (state.knowledgeState == CellKnowledgeState.shrouded &&
        state.relationship == CellRelationship.frontier) {
      return _frontierStrokeColor();
    }
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => _presentStrokeColor(),
      CellKnowledgeState.informed ||
      CellKnowledgeState.explored => _exploredStrokeColor(),
      CellKnowledgeState.shrouded => _unknownStrokeColor(),
    };
  }

  static double seamGlowStrokeWidth(CellState state) {
    if (state.knowledgeState == CellKnowledgeState.shrouded &&
        state.relationship == CellRelationship.frontier) {
      return 0.8;
    }
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 1.65,
      CellKnowledgeState.informed || CellKnowledgeState.explored => 1.0,
      CellKnowledgeState.shrouded => 0.0,
    };
  }

  static double seamStrokeWidth(CellState state) {
    if (state.knowledgeState == CellKnowledgeState.shrouded &&
        state.relationship == CellRelationship.frontier) {
      return 0.8;
    }
    return switch (state.knowledgeState) {
      CellKnowledgeState.present => 1.0,
      CellKnowledgeState.informed || CellKnowledgeState.explored => 0.6,
      CellKnowledgeState.shrouded => 0.0,
    };
  }

  static double seamGlowBlurSigma(CellState state) {
    if (state.knowledgeState == CellKnowledgeState.shrouded &&
        state.relationship == CellRelationship.frontier) {
      return 0.3;
    }
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
    return const Color(0x001B1B1B);
  }

  static Color _informedFillColor() {
    return const Color(0x701B1B1B);
  }

  static Color _exploredFillColor() {
    return const Color(0x381B1B1B);
  }

  static Color _unknownFillColor() {
    return const Color(0xFF1B1B1B);
  }

  static Color _frontierFillColor() {
    return const Color(0xB81B1B1B);
  }

  static const Color categoryCueColor = Color(0xFFE8E8E8);
  static const Color categoryCueUnderlayColor = Color(0xFF1B1B1B);
  static const Color categoryCueOutlineColor = Color(0xFFE8E8E8);

  static Color _presentStrokeColor() {
    return const Color(0xE6E8E8E8);
  }

  static Color _exploredStrokeColor() {
    return const Color(0xB85C5C5C);
  }

  static Color _unknownStrokeColor() {
    return const Color(0x005C5C5C);
  }

  static Color _frontierStrokeColor() {
    return const Color(0x995C5C5C);
  }
}
