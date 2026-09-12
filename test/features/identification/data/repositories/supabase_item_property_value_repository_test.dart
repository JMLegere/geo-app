import 'dart:convert';

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/repositories/supabase_item_property_value_repository.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

const _versionId = '11111111-1111-4111-8111-111111111111';

void main() {
  group('SupabaseItemPropertyValueRepository', () {
    test(
      'returns exact identified Item values in exact-version order',
      () async {
        final repository = SupabaseItemPropertyValueRepository(
          client: null,
          rowsQuery: (_) async => [
            _row(
              ordinal: 1,
              propertyKey: 'temperament',
              propertyLabel: 'Temperament',
              resolvedValueId: 'calm',
              valueLabel: 'Calm',
            ),
            _row(
              ordinal: 0,
              propertyKey: 'size',
              propertyLabel: 'Size',
              resolutionKind: 'none',
            ),
          ],
        );

        final properties = await repository.fetchForIdentifiedItem(_item());

        expect(properties.map((property) => property.propertyKey), [
          'size',
          'temperament',
        ]);
        expect(properties.first.propertyLabel, 'Size');
        expect(properties.first.resolution, isA<NoPropertyValue>());
        expect(properties.first.valueText, 'None');
        expect(properties.last.propertyLabel, 'Temperament');
        expect(properties.last.resolution, isA<SelectedPropertyValue>());
        expect(properties.last.valueText, 'Calm');
      },
    );

    test('keeps missing metadata truthful as the authoritative IDs', () async {
      final repository = SupabaseItemPropertyValueRepository(
        client: null,
        rowsQuery: (_) async => [
          _row(
            ordinal: 0,
            propertyKey: 'surface_pattern',
            resolvedValueId: 'banded',
          ),
        ],
      );

      final property = (await repository.fetchForIdentifiedItem(
        _item(),
      )).single;

      expect(property.propertyLabel, 'surface_pattern');
      expect(property.valueText, 'banded');
    });

    test('rejects nonidentified Item detail without issuing a read', () async {
      var reads = 0;
      final repository = SupabaseItemPropertyValueRepository(
        client: null,
        rowsQuery: (_) async {
          reads++;
          return const [];
        },
      );
      final item = _item().copyWith(
        identificationState: ItemIdentificationState.unidentified,
      );

      await expectLater(
        () => repository.fetchForIdentifiedItem(item),
        throwsStateError,
      );
      expect(reads, 0);
    });

    test('rejects rows that do not retain the Item exact binding', () async {
      final repository = SupabaseItemPropertyValueRepository(
        client: null,
        rowsQuery: (_) async => [
          {
            ..._row(ordinal: 0, propertyKey: 'size', resolvedValueId: 'small'),
            'base_item_version_id': '22222222-2222-4222-8222-222222222222',
          },
        ],
      );

      await expectLater(
        () => repository.fetchForIdentifiedItem(_item()),
        throwsStateError,
      );
    });
    test(
      'uses owner-bound exact-version queries and canonical metadata',
      () async {
        final requests = <http.Request>[];
        final repository = _httpRepository((request) async {
          requests.add(request);
          return switch (request.url.path) {
            '/rest/v1/v3_item_property_values' => _json([
              _storedValue(propertyKey: 'temperament', valueId: 'calm'),
              _storedValue(propertyKey: 'size', resolutionKind: 'none'),
            ]),
            '/rest/v1/v3_base_item_version_variable_properties' => _json([
              {'variable_property_id': 'size', 'ordinal': 0},
              {'variable_property_id': 'temperament', 'ordinal': 1},
            ]),
            '/rest/v1/v3_variable_properties' => _json([
              {'id': 'size', 'display_name': 'Size'},
              {'id': 'temperament', 'display_name': 'Temperament'},
            ]),
            '/rest/v1/v3_property_values' => _json([
              {'id': 'calm', 'display_name': 'Calm'},
            ]),
            _ => http.Response('unexpected endpoint', 404),
          };
        });

        final properties = await repository.fetchForIdentifiedItem(_item());

        expect(properties.map((property) => property.propertyKey), [
          'size',
          'temperament',
        ]);
        expect(properties.first.valueText, 'None');
        expect(properties.last.valueText, 'Calm');
        expect(requests.map((request) => request.url.path), [
          '/rest/v1/v3_item_property_values',
          '/rest/v1/v3_base_item_version_variable_properties',
          '/rest/v1/v3_variable_properties',
          '/rest/v1/v3_property_values',
        ]);
        final ownerQuery = requests.first.url.queryParameters;
        expect(ownerQuery['item_id'], 'eq.item-1');
        expect(ownerQuery['base_item_id'], 'eq.fauna:river-otter');
        expect(ownerQuery['base_item_version_id'], 'eq.$_versionId');
        expect(ownerQuery.containsKey('user_id'), isFalse);
        final assignmentQuery = requests[1].url.queryParameters;
        expect(assignmentQuery['base_item_version_id'], 'eq.$_versionId');
        expect(
          assignmentQuery['variable_property_id'],
          contains('temperament'),
        );
        expect(assignmentQuery['variable_property_id'], contains('size'));
        expect(requests[2].url.queryParameters['id'], contains('temperament'));
        expect(requests[3].url.queryParameters['id'], contains('calm'));
      },
    );

    test('accepts an empty owner result without metadata reads', () async {
      final requests = <http.Request>[];
      final repository = _httpRepository((request) async {
        requests.add(request);
        return _json([]);
      });

      expect(await repository.fetchForIdentifiedItem(_item()), isEmpty);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/v3_item_property_values');
    });

    test(
      'falls back to committed IDs when metadata labels are absent',
      () async {
        final repository = _httpRepository((request) async {
          return switch (request.url.path) {
            '/rest/v1/v3_item_property_values' => _json([
              _storedValue(propertyKey: 'surface_pattern', valueId: 'banded'),
            ]),
            '/rest/v1/v3_base_item_version_variable_properties' => _json([
              {'variable_property_id': 'surface_pattern', 'ordinal': 0},
            ]),
            '/rest/v1/v3_variable_properties' => _json([]),
            '/rest/v1/v3_property_values' => _json([]),
            _ => http.Response('unexpected endpoint', 404),
          };
        });

        final property = (await repository.fetchForIdentifiedItem(
          _item(),
        )).single;

        expect(property.propertyLabel, 'surface_pattern');
        expect(property.valueText, 'banded');
      },
    );

    test(
      'rejects incomplete exact-version ordinals before metadata reads',
      () async {
        var requests = 0;
        final repository = _httpRepository((request) async {
          requests++;
          return switch (request.url.path) {
            '/rest/v1/v3_item_property_values' => _json([
              _storedValue(propertyKey: 'size', valueId: 'small'),
              _storedValue(propertyKey: 'temperament', valueId: 'calm'),
            ]),
            '/rest/v1/v3_base_item_version_variable_properties' => _json([
              {'variable_property_id': 'size', 'ordinal': 0},
            ]),
            _ => http.Response('unexpected endpoint', 404),
          };
        });

        await expectLater(
          () => repository.fetchForIdentifiedItem(_item()),
          throwsStateError,
        );
        expect(requests, 2);
      },
    );

    test(
      'rejects duplicate exact-version ordinals from the HTTP response',
      () async {
        final repository = _httpRepository((request) async {
          return switch (request.url.path) {
            '/rest/v1/v3_item_property_values' => _json([
              _storedValue(propertyKey: 'size', valueId: 'small'),
              _storedValue(propertyKey: 'temperament', valueId: 'calm'),
            ]),
            '/rest/v1/v3_base_item_version_variable_properties' => _json([
              {'variable_property_id': 'size', 'ordinal': 0},
              {'variable_property_id': 'temperament', 'ordinal': 0},
            ]),
            '/rest/v1/v3_variable_properties' => _json([
              {'id': 'size', 'display_name': 'Size'},
              {'id': 'temperament', 'display_name': 'Temperament'},
            ]),
            '/rest/v1/v3_property_values' => _json([
              {'id': 'small', 'display_name': 'Small'},
              {'id': 'calm', 'display_name': 'Calm'},
            ]),
            _ => http.Response('unexpected endpoint', 404),
          };
        });

        await expectLater(
          () => repository.fetchForIdentifiedItem(_item()),
          throwsStateError,
        );
      },
    );

    test('rejects an invalid table response and transports failures', () async {
      final invalidResponse = _httpRepository((_) async => _json({}));
      await expectLater(
        () => invalidResponse.fetchForIdentifiedItem(_item()),
        throwsA(isA<TypeError>()),
      );

      var requests = 0;
      final offline = _httpRepository((_) async {
        requests++;
        throw StateError('offline');
      });
      await expectLater(
        () => offline.fetchForIdentifiedItem(_item()),
        throwsStateError,
      );
      expect(requests, 1);
    });

    test('rejects Unknown Items without issuing an HTTP query', () async {
      var requests = 0;
      final repository = _httpRepository((_) async {
        requests++;
        return _json([]);
      });

      await expectLater(
        () => repository.fetchForIdentifiedItem(
          _item().copyWith(
            identificationState: ItemIdentificationState.unidentified,
          ),
        ),
        throwsStateError,
      );
      expect(requests, 0);
    });
  });
}

SupabaseItemPropertyValueRepository _httpRepository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SupabaseItemPropertyValueRepository(
    client: supa.SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
          reasonPhrase: response.reasonPhrase,
        );
      }),
    ),
  );
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _storedValue({
  required String propertyKey,
  String resolutionKind = 'value',
  String? valueId,
}) => {
  'item_id': 'item-1',
  'base_item_id': 'fauna:river-otter',
  'base_item_version_id': _versionId,
  'variable_property_key': propertyKey,
  'resolution_kind': resolutionKind,
  'resolved_value_id': valueId,
};

Item _item() => Item(
  id: 'item-1',
  definitionId: 'fauna:river-otter',
  baseItemId: 'fauna:river-otter',
  baseItemVersionId: _versionId,
  displayName: 'River Otter',
  category: ItemCategory.fauna,
  acquiredAt: DateTime.utc(2026, 9, 11),
  status: ItemStatus.active,
  identificationState: ItemIdentificationState.identified,
);

Map<String, dynamic> _row({
  required int ordinal,
  required String propertyKey,
  String? propertyLabel,
  String resolutionKind = 'value',
  String? resolvedValueId,
  String? valueLabel,
}) => {
  'item_id': 'item-1',
  'base_item_id': 'fauna:river-otter',
  'base_item_version_id': _versionId,
  'ordinal': ordinal,
  'variable_property_key': propertyKey,
  'property_display_name': propertyLabel,
  'resolution_kind': resolutionKind,
  'resolved_value_id': resolvedValueId,
  'value_display_name': valueLabel,
};
