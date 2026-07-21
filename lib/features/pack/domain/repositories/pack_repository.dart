import 'package:earth_nova/core/domain/entities/item.dart';

/// Read-only boundary for the Player's currently active owned Items.
abstract interface class PackRepository {
  Future<List<Item>> fetchActiveItems(
    String userId, {
    String? traceId,
  });
}
