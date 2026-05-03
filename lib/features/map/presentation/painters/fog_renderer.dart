import 'dart:ui';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class FogRenderer {
  FogRenderer._();

  static const double _kRenderDistanceKm = 2.0;

  static Color fillColor(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => _presentFillColor(),
      CellRelationship.explored => _exploredFillColor(),
      CellRelationship.frontier => _frontierFillColor(),
      CellRelationship.unknown => _unknownFillColor(),
    };
  }

  static Color strokeColor(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => _presentStrokeColor(),
      CellRelationship.explored => _exploredStrokeColor(),
      CellRelationship.frontier => _frontierStrokeColor(),
      CellRelationship.unknown => _unknownStrokeColor(),
    };
  }

  static bool animatesFog(CellState state) {
    return state.relationship == CellRelationship.frontier;
  }

  static bool shouldRender(CellState state) {
    if (state.contents == CellContents.hasLoot) return true;
    return state.relationship != CellRelationship.frontier ||
        isWithinRenderDistance(2.0);
  }

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
    return const Color(0x66D8C49A);
  }

  static Color _frontierFillColor() {
    return const Color(0xB3000000);
  }

  static Color _unknownFillColor() {
    return const Color(0xE6000000);
  }

  static Color _presentStrokeColor() {
    return const Color(0xF2FFFFFF);
  }

  static Color _exploredStrokeColor() {
    return const Color(0x99F1DEC0);
  }

  static Color _frontierStrokeColor() {
    return const Color(0xCCFFFFFF);
  }

  static Color _unknownStrokeColor() {
    return const Color(0x66FFFFFF);
  }
}
