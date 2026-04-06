import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<Item>> fetchItems(String userId) async {
    final response = await _client
        .from('v3_items')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('acquired_at', ascending: false);

    if (response.isEmpty) return [];
    return (response as List)
        .map(
            (json) => ItemDto.fromJson(json as Map<String, dynamic>).toDomain())
        .toList();
  }
}
