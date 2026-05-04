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

  static double seamGlowStrokeWidth(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => 3.0,
      CellRelationship.explored => 2.0,
      CellRelationship.frontier => 0.0,
      CellRelationship.unknown => 0.0,
    };
  }

  static double seamStrokeWidth(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => 1.1,
      CellRelationship.explored => 0.8,
      CellRelationship.frontier => 0.0,
      CellRelationship.unknown => 0.0,
    };
  }

  static double seamGlowBlurSigma(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => 2.4,
      CellRelationship.explored => 1.8,
      CellRelationship.frontier => 0.0,
      CellRelationship.unknown => 0.0,
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
    return const Color(0xA6000000);
  }

  static Color _unknownFillColor() {
    return const Color(0xD9000000);
  }

  static Color _presentStrokeColor() {
    return const Color(0xF2FFFFFF);
  }

  static Color _exploredStrokeColor() {
    return const Color(0x99F1DEC0);
  }

  static Color _frontierStrokeColor() {
    return const Color(0x00000000);
  }

  static Color _unknownStrokeColor() {
    return const Color(0x00000000);
  }
}
