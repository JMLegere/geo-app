import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';

/// Mock-only bridge while Encounter acquisition still owns [ItemRepository].
///
/// Production composition uses the dedicated Supabase Pack repository instead,
/// so Pack reads cannot share the legacy mutable Item repository.
final class LegacyItemRepositoryPackAdapter implements PackRepository {
  const LegacyItemRepositoryPackAdapter(this._legacyRepository);

  final ItemRepository _legacyRepository;

  @override
  Future<List<Item>> fetchActiveItems(
    String userId, {
    String? traceId,
  }) =>
      _legacyRepository.fetchItems(userId, traceId: traceId);
}
