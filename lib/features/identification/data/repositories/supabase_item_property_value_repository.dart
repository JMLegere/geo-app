import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/item_recorded_property.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_property_value_repository.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable flattened rows for [SupabaseItemPropertyValueRepository].
typedef ItemPropertyValueRowsQuery =
    Future<List<Map<String, dynamic>>> Function(Item item);

/// Presentation-only reader for an identified Item's committed property values.
final class SupabaseItemPropertyValueRepository
    implements ItemPropertyValueRepository {
  SupabaseItemPropertyValueRepository({
    required SupabaseClient? client,
    ItemPropertyValueRowsQuery? rowsQuery,
  }) : _client = client,
       _rowsQuery = rowsQuery;

  final SupabaseClient? _client;
  final ItemPropertyValueRowsQuery? _rowsQuery;

  @override
  Future<List<ItemRecordedProperty>> fetchForIdentifiedItem(Item item) async {
    _validateItem(item);
    final rows = await _runRowsQuery(item);
    final properties = rows.map((row) => _propertyFromRow(row, item)).toList()
      ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    final ordinals = <int>{};
    for (final property in properties) {
      if (!ordinals.add(property.ordinal)) {
        throw StateError('Item Property Values contain duplicate ordinals.');
      }
    }
    return List.unmodifiable(properties);
  }

  Future<List<Map<String, dynamic>>> _runRowsQuery(Item item) async {
    final query = _rowsQuery;
    if (query != null) return query(item);

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no Item Property Value query is provided.',
      );
    }

    final values = _rows(
      await client
          .from('v3_item_property_values')
          .select(
            'item_id,base_item_id,base_item_version_id,'
            'variable_property_key,resolution_kind,resolved_value_id',
          )
          .eq('item_id', item.id)
          .eq('base_item_id', item.baseItemId!)
          .eq('base_item_version_id', item.baseItemVersionId!),
      'Item Property Value query',
    );
    if (values.isEmpty) return const [];

    final keys = <String>{
      for (final row in values)
        _requiredString(row['variable_property_key'], 'variable_property_key'),
    };
    final assignments = _rows(
      await client
          .from('v3_base_item_version_variable_properties')
          .select('variable_property_id,ordinal')
          .eq('base_item_version_id', item.baseItemVersionId!)
          .inFilter('variable_property_id', keys.toList(growable: false)),
      'Base Item Version Variable Property query',
    );
    final ordinals = _ordinalsFor(keys, assignments);

    final propertyNames = _namesFor(
      keys,
      _rows(
        await client
            .from('v3_variable_properties')
            .select('id,display_name')
            .inFilter('id', keys.toList(growable: false)),
        'Variable Property metadata query',
      ),
      idField: 'id',
    );
    final valueIds = <String>{
      for (final row in values)
        if (row['resolution_kind'] == 'value')
          _requiredString(row['resolved_value_id'], 'resolved_value_id'),
    };
    final valueNames = valueIds.isEmpty
        ? const <String, String>{}
        : _namesFor(
            valueIds,
            _rows(
              await client
                  .from('v3_property_values')
                  .select('id,display_name')
                  .inFilter('id', valueIds.toList(growable: false)),
              'Property Value metadata query',
            ),
            idField: 'id',
          );

    return List.unmodifiable([
      for (final value in values)
        {
          ...value,
          'ordinal':
              ordinals[_requiredString(
                value['variable_property_key'],
                'variable_property_key',
              )],
          'property_display_name':
              propertyNames[_requiredString(
                value['variable_property_key'],
                'variable_property_key',
              )],
          if (value['resolution_kind'] == 'value')
            'value_display_name':
                valueNames[_requiredString(
                  value['resolved_value_id'],
                  'resolved_value_id',
                )],
        },
    ]);
  }
}

void _validateItem(Item item) {
  if (item.identificationState != ItemIdentificationState.identified) {
    throw StateError(
      'Recorded properties are unavailable before identification.',
    );
  }
  _requiredString(item.id, 'item.id');
  _requiredString(item.baseItemId, 'item.baseItemId');
  _requiredString(item.baseItemVersionId, 'item.baseItemVersionId');
}

ItemRecordedProperty _propertyFromRow(Map<String, dynamic> row, Item item) {
  if (_requiredString(row['item_id'], 'item_id') != item.id ||
      _requiredString(row['base_item_id'], 'base_item_id') != item.baseItemId ||
      _requiredString(row['base_item_version_id'], 'base_item_version_id') !=
          item.baseItemVersionId) {
    throw StateError(
      'Item Property Value does not retain the requested binding.',
    );
  }
  final key = _requiredString(
    row['variable_property_key'],
    'variable_property_key',
  );
  final resolution = switch (row['resolution_kind']) {
    'value' => SelectedPropertyValue(
      _requiredString(row['resolved_value_id'], 'resolved_value_id'),
    ),
    'none' when row['resolved_value_id'] == null => const NoPropertyValue(),
    _ => throw StateError(
      'Item Property Value has an invalid resolution shape.',
    ),
  };
  return ItemRecordedProperty(
    ordinal: _requiredOrdinal(row['ordinal']),
    propertyKey: key,
    propertyLabel: _optionalDisplayName(row['property_display_name']) ?? key,
    resolution: resolution,
    valueLabel: _optionalDisplayName(row['value_display_name']),
  );
}

Map<String, int> _ordinalsFor(
  Set<String> requestedKeys,
  List<Map<String, dynamic>> rows,
) {
  final ordinals = <String, int>{};
  for (final row in rows) {
    final key = _requiredString(
      row['variable_property_id'],
      'variable_property_id',
    );
    if (!requestedKeys.contains(key) || ordinals.containsKey(key)) {
      throw StateError('Invalid Base Item Version Variable Property response.');
    }
    ordinals[key] = _requiredOrdinal(row['ordinal']);
  }
  if (ordinals.length != requestedKeys.length) {
    throw StateError(
      'Item Property Values are missing exact-Version ordinals.',
    );
  }
  return ordinals;
}

Map<String, String> _namesFor(
  Set<String> requestedIds,
  List<Map<String, dynamic>> rows, {
  required String idField,
}) {
  final names = <String, String>{};
  final seenIds = <String>{};
  for (final row in rows) {
    final id = _requiredString(row[idField], idField);
    if (!requestedIds.contains(id) || !seenIds.add(id)) {
      throw StateError('Metadata response includes an invalid value.');
    }
    final displayName = _optionalDisplayName(row['display_name']);
    if (displayName != null) names[id] = displayName;
  }
  return names;
}

List<Map<String, dynamic>> _rows(Object? response, String source) {
  if (response is! List) throw StateError('$source must return a list.');
  return List.unmodifiable([
    for (final row in response)
      if (row is Map)
        Map<String, dynamic>.from(row)
      else
        throw StateError('$source contains a non-object row.'),
  ]);
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw StateError('$field must be a non-empty string.');
  }
  return value.trim();
}

int _requiredOrdinal(Object? value) {
  if (value is! int || value < 0) {
    throw StateError('ordinal must be a non-negative integer.');
  }
  return value;
}

String? _optionalDisplayName(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
