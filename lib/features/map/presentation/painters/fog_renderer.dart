import 'dart:ui';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class FogRenderer {
  FogRenderer._();

  static const double _kRenderDistanceKm = 2.0;

  static Color fillColor(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => _presentFillColor(state.contents),
      CellRelationship.explored => _exploredFillColor(state.contents),
      CellRelationship.nearby => _nearbyFillColor(state.contents),
    };
  }

  static Color strokeColor(CellState state) {
    return switch (state.relationship) {
      CellRelationship.present => _presentStrokeColor(),
      CellRelationship.explored => _exploredStrokeColor(),
      CellRelationship.nearby => _nearbyStrokeColor(),
    };
  }

  static bool shouldRender(CellState state) {
    if (state.contents == CellContents.hasLoot) return true;
    return state.relationship != CellRelationship.nearby ||
        isWithinRenderDistance(2.0);
  }

  static bool isWithinRenderDistance(double? distanceKm) {
    if (distanceKm == null) return false;
    return distanceKm <= _kRenderDistanceKm;
  }

  static Color getHabitatStrokeColor(Cell cell) {
    return cell.blendedColor;
  }

  static Color _presentFillColor(CellContents contents) {
    if (contents == CellContents.hasLoot) {
      return const Color(0xFFE06D77);
    }
    return const Color(0xCC006D77);
  }

  static Color _exploredFillColor(CellContents contents) {
    if (contents == CellContents.hasLoot) {
      return const Color(0xDDE29578);
    }
    return const Color(0x99E29578);
  }

  static Color _nearbyFillColor(CellContents contents) {
    if (contents == CellContents.hasLoot) {
      return const Color(0xFF83C5BE);
    }
    return const Color(0x4083C5BE);
  }

  static Color _presentStrokeColor() {
    return const Color(0xFF006D77);
  }

  static Color _exploredStrokeColor() {
    return const Color(0xAAE29578);
  }

  static Color _nearbyStrokeColor() {
    return const Color(0x5583C5BE);
  }
}
