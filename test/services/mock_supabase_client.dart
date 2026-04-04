import 'package:earth_nova/models/item.dart';

/// Fake Supabase query builder that returns pre-configured data.
///
/// Used by [MockItemService] and any future service tests.
/// Avoids importing `supabase_flutter` in tests entirely.
class FakeSupabaseResponse {
  FakeSupabaseResponse(this._data);
  final List<Map<String, dynamic>> _data;

  List<Map<String, dynamic>> get data => _data;
}

/// Minimal mock of ItemService that doesn't require SupabaseClient.
///
/// Tests that need to verify provider behavior inject this instead
/// of the real ItemService (which needs a live SupabaseClient).
class MockItemService {
  MockItemService({
    this.items = const [],
    this.shouldThrow = false,
    this.errorMessage = 'Network error',
  });

  final List<Item> items;
  final bool shouldThrow;
  final String errorMessage;

  Future<List<Item>> fetchItems(String userId) async {
    if (shouldThrow) throw Exception(errorMessage);
    return items;
  }
}
