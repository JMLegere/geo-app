import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/location_node.dart';

void main() {
  group('LocationNode', () {
    // -------------------------------------------------------------------------
    // Constructor and basic properties
    // -------------------------------------------------------------------------

    test('constructor accepts all required parameters', () {
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: null,
      );

      expect(node.id, 'node-1');
      expect(node.osmId, 123456);
      expect(node.name, 'Test Location');
      expect(node.adminLevel, AdminLevel.country);
      expect(node.parentId, isNull);
      expect(node.colorHex, '#FF0000');
      expect(node.geometryJson, isNull);
    });

    test('constructor accepts geometryJson as non-null string', () {
      const geoJson =
          '{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}';
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      expect(node.geometryJson, geoJson);
    });

    // -------------------------------------------------------------------------
    // copyWith() — geometryJson parameter
    // -------------------------------------------------------------------------

    test('copyWith preserves geometryJson when not specified', () {
      const geoJson = '{"type":"Polygon"}';
      final original = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final copied = original.copyWith(name: 'Updated Name');

      expect(copied.geometryJson, geoJson);
      expect(copied.name, 'Updated Name');
    });

    test('copyWith updates geometryJson when specified', () {
      const oldGeoJson = '{"type":"Polygon"}';
      const newGeoJson = '{"type":"Point"}';
      final original = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: oldGeoJson,
      );

      final copied = original.copyWith(geometryJson: () => newGeoJson);

      expect(copied.geometryJson, newGeoJson);
    });

    test('copyWith can set geometryJson to null', () {
      const geoJson = '{"type":"Polygon"}';
      final original = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final copied = original.copyWith(geometryJson: () => null);

      expect(copied.geometryJson, isNull);
    });

    // -------------------------------------------------------------------------
    // toJson() / fromJson() roundtrip
    // -------------------------------------------------------------------------

    test('toJson includes geometryJson when non-null', () {
      const geoJson =
          '{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}';
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: 'parent-1',
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final json = node.toJson();

      expect(json['id'], 'node-1');
      expect(json['osmId'], 123456);
      expect(json['name'], 'Test Location');
      expect(json['adminLevel'], 'country');
      expect(json['parentId'], 'parent-1');
      expect(json['colorHex'], '#FF0000');
      expect(json['geometryJson'], geoJson);
    });

    test('toJson includes geometryJson as null when null', () {
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: null,
      );

      final json = node.toJson();

      expect(json['geometryJson'], isNull);
    });

    test('fromJson roundtrips with geometryJson non-null', () {
      const geoJson =
          '{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}';
      final original = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: 'parent-1',
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final json = original.toJson();
      final restored = LocationNode.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.osmId, original.osmId);
      expect(restored.name, original.name);
      expect(restored.adminLevel, original.adminLevel);
      expect(restored.parentId, original.parentId);
      expect(restored.colorHex, original.colorHex);
      expect(restored.geometryJson, original.geometryJson);
    });

    test('fromJson roundtrips with geometryJson null', () {
      final original = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: null,
      );

      final json = original.toJson();
      final restored = LocationNode.fromJson(json);

      expect(restored.geometryJson, isNull);
      expect(restored, original);
    });

    test('fromJson handles missing geometryJson key as null', () {
      final json = {
        'id': 'node-1',
        'osmId': 123456,
        'name': 'Test Location',
        'adminLevel': 'country',
        'parentId': null,
        'colorHex': '#FF0000',
        // geometryJson intentionally omitted
      };

      final node = LocationNode.fromJson(json);

      expect(node.geometryJson, isNull);
    });

    // -------------------------------------------------------------------------
    // Equality and hashCode
    // -------------------------------------------------------------------------

    test('operator== includes geometryJson in comparison', () {
      const geoJson = '{"type":"Polygon"}';
      final node1 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final node2 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      expect(node1, node2);
    });

    test('operator== returns false when geometryJson differs', () {
      final node1 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: '{"type":"Polygon"}',
      );

      final node2 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: '{"type":"Point"}',
      );

      expect(node1, isNot(node2));
    });

    test(
      'operator== returns false when one has geometryJson and other is null',
      () {
        final node1 = LocationNode(
          id: 'node-1',
          osmId: 123456,
          name: 'Test Location',
          adminLevel: AdminLevel.country,
          parentId: null,
          colorHex: '#FF0000',
          geometryJson: '{"type":"Polygon"}',
        );

        final node2 = LocationNode(
          id: 'node-1',
          osmId: 123456,
          name: 'Test Location',
          adminLevel: AdminLevel.country,
          parentId: null,
          colorHex: '#FF0000',
          geometryJson: null,
        );

        expect(node1, isNot(node2));
      },
    );

    test('hashCode includes geometryJson', () {
      const geoJson = '{"type":"Polygon"}';
      final node1 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final node2 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      expect(node1.hashCode, node2.hashCode);
    });

    test('hashCode differs when geometryJson differs', () {
      final node1 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: '{"type":"Polygon"}',
      );

      final node2 = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: '{"type":"Point"}',
      );

      expect(node1.hashCode, isNot(node2.hashCode));
    });

    // -------------------------------------------------------------------------
    // toString()
    // -------------------------------------------------------------------------

    test('toString includes geometryJson', () {
      const geoJson = '{"type":"Polygon"}';
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: 'parent-1',
        colorHex: '#FF0000',
        geometryJson: geoJson,
      );

      final str = node.toString();

      expect(str, contains('geometryJson'));
      expect(str, contains('present'));
    });

    test('toString includes null geometryJson', () {
      final node = LocationNode(
        id: 'node-1',
        osmId: 123456,
        name: 'Test Location',
        adminLevel: AdminLevel.country,
        parentId: null,
        colorHex: '#FF0000',
        geometryJson: null,
      );

      final str = node.toString();

      expect(str, contains('geometryJson'));
      expect(str, contains('null'));
    });
  });
}
