import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class FetchItems {
  const FetchItems(this._repository);
  final ItemRepository _repository;

  Future<List<Item>> call(String userId) => _repository.fetchItems(userId);
}
