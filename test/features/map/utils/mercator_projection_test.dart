import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/map/utils/mercator_projection.dart';

void main() {
  group('MercatorProjection', () {
    const viewportSize = Size(400, 800);
    const zoom = 13.0;

    // San Francisco reference coordinate.
    const sfLat = 37.7749;
    const sfLon = -122.4194;

    // -------------------------------------------------------------------------
    // geoToScreen
    // -------------------------------------------------------------------------

    test('geoToScreen: camera center maps exactly to viewport center', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final result = MercatorProjection.geoToScreen(
        lat: cameraLat,
        lon: cameraLon,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(result.dx, closeTo(viewportSize.width / 2, 0.001));
      expect(result.dy, closeTo(viewportSize.height / 2, 0.001));
    });

    test('geoToScreen: known coordinate (San Francisco, zoom 13) produces reasonable screen offset', () {
      // Camera centred on SF; SF itself should land near viewport center.
      final result = MercatorProjection.geoToScreen(
        lat: sfLat,
        lon: sfLon,
        cameraLat: sfLat,
        cameraLon: sfLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      // SF at camera center must map to viewport center.
      expect(result.dx, closeTo(viewportSize.width / 2, 0.001));
      expect(result.dy, closeTo(viewportSize.height / 2, 0.001));
    });

    test('geoToScreen: point east of camera center has greater screen X', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final eastPoint = MercatorProjection.geoToScreen(
        lat: cameraLat,
        lon: cameraLon + 0.1, // 0.1° east
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(eastPoint.dx, greaterThan(viewportSize.width / 2));
      expect(eastPoint.dy, closeTo(viewportSize.height / 2, 1.0));
    });

    test('geoToScreen: point north of camera center has lower screen Y', () {
      // Screen Y increases downward, so a northern point has SMALLER Y.
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final northPoint = MercatorProjection.geoToScreen(
        lat: cameraLat + 0.1, // 0.1° north
        lon: cameraLon,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(northPoint.dy, lessThan(viewportSize.height / 2));
      expect(northPoint.dx, closeTo(viewportSize.width / 2, 1.0));
    });

    test('geoToScreen: point west of camera has smaller screen X', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final westPoint = MercatorProjection.geoToScreen(
        lat: cameraLat,
        lon: cameraLon - 0.1, // 0.1° west
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(westPoint.dx, lessThan(viewportSize.width / 2));
    });

    test('geoToScreen: point south of camera has greater screen Y', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final southPoint = MercatorProjection.geoToScreen(
        lat: cameraLat - 0.1, // 0.1° south
        lon: cameraLon,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(southPoint.dy, greaterThan(viewportSize.height / 2));
    });

    // -------------------------------------------------------------------------
    // screenToGeo
    // -------------------------------------------------------------------------

    test('screenToGeo: viewport center maps to camera position', () {
      const cameraLat = 37.7749;
      const cameraLon = -122.4194;

      final geo = MercatorProjection.screenToGeo(
        screenPoint: Offset(viewportSize.width / 2, viewportSize.height / 2),
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(geo.lat, closeTo(cameraLat, 0.0001));
      expect(geo.lon, closeTo(cameraLon, 0.0001));
    });

    test('screenToGeo: round-trip geoToScreen → screenToGeo returns original coords', () {
      const lat = 48.8566; // Paris
      const lon = 2.3522;
      const cameraLat = 48.8566;
      const cameraLon = 2.3522;

      final screen = MercatorProjection.geoToScreen(
        lat: lat,
        lon: lon,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      final geo = MercatorProjection.screenToGeo(
        screenPoint: screen,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(geo.lat, closeTo(lat, 0.0001));
      expect(geo.lon, closeTo(lon, 0.0001));
    });

    test('screenToGeo: round-trip with off-center point', () {
      const cameraLat = 51.5074; // London
      const cameraLon = -0.1278;
      const targetLat = 51.5150;
      const targetLon = -0.1050;

      final screen = MercatorProjection.geoToScreen(
        lat: targetLat,
        lon: targetLon,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      final geo = MercatorProjection.screenToGeo(
        screenPoint: screen,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(geo.lat, closeTo(targetLat, 0.0001));
      expect(geo.lon, closeTo(targetLon, 0.0001));
    });

    // -------------------------------------------------------------------------
    // visibleBounds
    // -------------------------------------------------------------------------

    test('visibleBounds: contains the camera center', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final bounds = MercatorProjection.visibleBounds(
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(bounds.minLat, lessThanOrEqualTo(cameraLat));
      expect(bounds.maxLat, greaterThanOrEqualTo(cameraLat));
      expect(bounds.minLon, lessThanOrEqualTo(cameraLon));
      expect(bounds.maxLon, greaterThanOrEqualTo(cameraLon));
    });

    test('visibleBounds: higher zoom produces smaller bounds', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final lowZoomBounds = MercatorProjection.visibleBounds(
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: 10.0,
        viewportSize: viewportSize,
      );

      final highZoomBounds = MercatorProjection.visibleBounds(
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: 16.0,
        viewportSize: viewportSize,
      );

      final lowLatSpan = lowZoomBounds.maxLat - lowZoomBounds.minLat;
      final highLatSpan = highZoomBounds.maxLat - highZoomBounds.minLat;

      expect(highLatSpan, lessThan(lowLatSpan));

      final lowLonSpan = lowZoomBounds.maxLon - lowZoomBounds.minLon;
      final highLonSpan = highZoomBounds.maxLon - highZoomBounds.minLon;

      expect(highLonSpan, lessThan(lowLonSpan));
    });

    test('visibleBounds: minLat < maxLat and minLon < maxLon', () {
      final bounds = MercatorProjection.visibleBounds(
        cameraLat: 37.7749,
        cameraLon: -122.4194,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(bounds.minLat, lessThan(bounds.maxLat));
      expect(bounds.minLon, lessThan(bounds.maxLon));
    });

    // -------------------------------------------------------------------------
    // Mercator limit clamping
    // -------------------------------------------------------------------------

    test('Mercator limit: latitude > 85.051129° is clamped and does not produce NaN/infinity', () {
      const cameraLat = 0.0;
      const cameraLon = 0.0;

      // Latitudes beyond the Mercator limit.
      for (final extremeLat in [85.1, 89.0, 90.0, 180.0]) {
        final result = MercatorProjection.geoToScreen(
          lat: extremeLat,
          lon: 0.0,
          cameraLat: cameraLat,
          cameraLon: cameraLon,
          zoom: zoom,
          viewportSize: viewportSize,
        );

        expect(result.dx.isFinite, isTrue,
            reason: 'screenX should be finite for lat=$extremeLat');
        expect(result.dy.isFinite, isTrue,
            reason: 'screenY should be finite for lat=$extremeLat');
      }
    });

    test('Mercator limit: latitude < -85.051129° is clamped and does not produce NaN/infinity', () {
      const cameraLat = 0.0;
      const cameraLon = 0.0;

      for (final extremeLat in [-85.1, -89.0, -90.0, -180.0]) {
        final result = MercatorProjection.geoToScreen(
          lat: extremeLat,
          lon: 0.0,
          cameraLat: cameraLat,
          cameraLon: cameraLon,
          zoom: zoom,
          viewportSize: viewportSize,
        );

        expect(result.dx.isFinite, isTrue,
            reason: 'screenX should be finite for lat=$extremeLat');
        expect(result.dy.isFinite, isTrue,
            reason: 'screenY should be finite for lat=$extremeLat');
      }
    });

    test('Mercator limit: same projected Y for 90° and 85.051129°', () {
      // Both should clamp to the same Mercator limit coordinate.
      const cameraLat = 0.0;
      const cameraLon = 0.0;

      final at85 = MercatorProjection.geoToScreen(
        lat: MercatorProjection.kMercatorMaxLat,
        lon: 0.0,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      final at90 = MercatorProjection.geoToScreen(
        lat: 90.0,
        lon: 0.0,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(at90.dy, closeTo(at85.dy, 0.001));
    });

    // -------------------------------------------------------------------------
    // Zoom-level consistency
    // -------------------------------------------------------------------------

    test('world doubles in size per zoom level', () {
      // At any fixed lat/lon offset, the screen pixel distance should double
      // for each +1 zoom level.
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final offset = MercatorProjection.geoToScreen(
        lat: cameraLat,
        lon: cameraLon + 0.01,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: 12.0,
        viewportSize: viewportSize,
      );

      final offsetZoom13 = MercatorProjection.geoToScreen(
        lat: cameraLat,
        lon: cameraLon + 0.01,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: 13.0,
        viewportSize: viewportSize,
      );

      // Pixel distance from center at zoom 13 should be ~2× zoom 12.
      final dist12 = (offset.dx - viewportSize.width / 2).abs();
      final dist13 = (offsetZoom13.dx - viewportSize.width / 2).abs();

      expect(dist13, closeTo(dist12 * 2, dist12 * 0.01));
    });

    // -------------------------------------------------------------------------
    // Longitude wrapping and edge cases
    // -------------------------------------------------------------------------

    test('geoToScreen produces finite values for extreme but valid coordinates', () {
      // Validate a range of real-world coordinates.
      final coords = [
        (lat: -33.8688, lon: 151.2093), // Sydney
        (lat: 35.6762, lon: 139.6503),  // Tokyo
        (lat: -1.2921, lon: 36.8219),   // Nairobi
        (lat: 55.7558, lon: 37.6173),   // Moscow
        (lat: -22.9068, lon: -43.1729), // Rio de Janeiro
      ];

      for (final coord in coords) {
        final result = MercatorProjection.geoToScreen(
          lat: coord.lat,
          lon: coord.lon,
          cameraLat: coord.lat,
          cameraLon: coord.lon,
          zoom: zoom,
          viewportSize: viewportSize,
        );

        expect(result.dx.isFinite, isTrue,
            reason: 'screenX finite for ${coord.lat}, ${coord.lon}');
        expect(result.dy.isFinite, isTrue,
            reason: 'screenY finite for ${coord.lat}, ${coord.lon}');
        // Camera center should map to viewport center.
        expect(result.dx, closeTo(viewportSize.width / 2, 0.01));
        expect(result.dy, closeTo(viewportSize.height / 2, 0.01));
      }
    });

    test('screenToGeo: top-left corner (0,0) has greater lat and lesser lon than viewport center', () {
      const cameraLat = 40.0;
      const cameraLon = -74.0;

      final topLeft = MercatorProjection.screenToGeo(
        screenPoint: Offset.zero,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      // Top-left → higher lat (north), smaller lon (west).
      expect(topLeft.lat, greaterThan(cameraLat));
      expect(topLeft.lon, lessThan(cameraLon));
    });

    test('visibleBounds: consistent with screenToGeo corner projections', () {
      const cameraLat = 48.8566;
      const cameraLon = 2.3522;

      final bounds = MercatorProjection.visibleBounds(
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      final topLeft = MercatorProjection.screenToGeo(
        screenPoint: Offset.zero,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom,
        viewportSize: viewportSize,
      );

      expect(bounds.maxLat, closeTo(topLeft.lat, 0.0001));
      expect(bounds.minLon, closeTo(topLeft.lon, 0.0001));
    });

    // Sanity check: the Mercator lat formula uses the identity
    // ln((1+sin)/(1-sin))/2 = ln(tan + sec), verify they produce same output.
    test('lat formula produces correct northern offset at zoom 13', () {
      const cameraLat = 0.0;
      const cameraLon = 0.0;
      const zoom13 = 13.0;

      // 1° north should produce a screen offset above center (negative dy from center).
      final northPoint = MercatorProjection.geoToScreen(
        lat: 1.0,
        lon: 0.0,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom13,
        viewportSize: viewportSize,
      );

      // At zoom 13, 1° ≈ 111 km ≈ many hundreds of pixels at typical zoom.
      // Just verify it's above center.
      final dyFromCenter = northPoint.dy - viewportSize.height / 2;
      expect(dyFromCenter, lessThan(0)); // above center = negative dy

      // At equator, 1° lat and 1° lon should produce similar pixel offsets.
      final eastPoint = MercatorProjection.geoToScreen(
        lat: 0.0,
        lon: 1.0,
        cameraLat: cameraLat,
        cameraLon: cameraLon,
        zoom: zoom13,
        viewportSize: viewportSize,
      );

      final dxFromCenter = eastPoint.dx - viewportSize.width / 2;
      // At equator, lat and lon degrees are roughly equal distance.
      // The pixel offsets should be similar in magnitude.
      expect(dxFromCenter.abs(), closeTo(dyFromCenter.abs(), dxFromCenter.abs() * 0.05));
    });
  });
}
