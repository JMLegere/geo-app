import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/item_recorded_property.dart';

/// Read-only presentation access to an identified Item's committed properties.
abstract interface class ItemPropertyValueRepository {
  Future<List<ItemRecordedProperty>> fetchForIdentifiedItem(Item item);
}
