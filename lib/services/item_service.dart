import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/models/item.dart';

/// Abstract item service — decouples pack logic from Supabase.
abstract class ItemService {
  /// Fetch all active items for a user, ordered by acquired_at DESC.
  Future<List<Item>> fetchItems(String userId);
}

/// Production implementation that queries Supabase v3_items table.
class SupabaseItemService implements ItemService {
  SupabaseItemService({required SupabaseClient client}) : _client = client;

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
        .map((json) => Item.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

/// In-memory item service for testing — no Supabase dependency.
class MockItemService implements ItemService {
  MockItemService({this.items = const [], this.shouldThrow = false});

  final List<Item> items;
  final bool shouldThrow;

  @override
  Future<List<Item>> fetchItems(String userId) async {
    if (shouldThrow) throw Exception('Mock fetch error');
    return items;
  }
}
