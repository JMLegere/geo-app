import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/models/item.dart';

/// Fetches items from Supabase v3_items table.
class ItemService {
  ItemService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Fetch all active items for a user, ordered by acquired_at DESC.
  Future<List<Item>> fetchItems(String userId) async {
    final response = await _client
        .from('v3_items')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('acquired_at', ascending: false);

    if (response.isEmpty) return [];
    return (response as List)
        .map((json) => Item.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
