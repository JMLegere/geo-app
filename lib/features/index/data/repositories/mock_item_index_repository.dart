import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';

/// In-memory read model used only when Supabase bootstrap is unavailable.
final class MockItemIndexRepository implements ItemIndexRepository {
  const MockItemIndexRepository([this._entries = const []]);

  final List<IndexEntry> _entries;

  @override
  Future<List<IndexEntry>> fetchIndex({String? traceId}) async =>
      List<IndexEntry>.unmodifiable(_entries);
}
