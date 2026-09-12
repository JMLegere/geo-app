import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';

/// A presentation read of one committed Item Property Value.
///
/// This does not replace the exact durable [PropertyValue] contract because the
/// Pack snapshot intentionally does not retain its full Item Knowledge binding.
final class ItemRecordedProperty {
  factory ItemRecordedProperty({
    required int ordinal,
    required String propertyKey,
    required String propertyLabel,
    required PropertyValueResolution resolution,
    String? valueLabel,
  }) {
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'must not be negative');
    }
    final normalizedKey = _nonBlank(propertyKey, 'propertyKey');
    return ItemRecordedProperty._(
      ordinal: ordinal,
      propertyKey: normalizedKey,
      propertyLabel: _nonBlank(propertyLabel, 'propertyLabel'),
      resolution: resolution,
      valueLabel: valueLabel?.trim().isEmpty ?? true
          ? null
          : valueLabel?.trim(),
    );
  }

  const ItemRecordedProperty._({
    required this.ordinal,
    required this.propertyKey,
    required this.propertyLabel,
    required this.resolution,
    required this.valueLabel,
  });

  final int ordinal;
  final String propertyKey;
  final String propertyLabel;
  final PropertyValueResolution resolution;
  final String? valueLabel;

  String get valueText => switch (resolution) {
    SelectedPropertyValue(:final valueId) => valueLabel ?? valueId,
    NoPropertyValue() => 'None',
  };
}

String _nonBlank(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return normalized;
}
