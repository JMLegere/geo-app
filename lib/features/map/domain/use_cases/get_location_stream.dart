import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

class GetLocationStream {
  const GetLocationStream(this._repository);
  final LocationRepository _repository;

  Stream<LocationState> call() => _repository.positionStream;
}
