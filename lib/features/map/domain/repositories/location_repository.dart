import 'package:earth_nova/features/map/domain/entities/location_state.dart';

abstract class LocationRepository {
  Stream<LocationState> get positionStream;
  Future<LocationState> getCurrentPosition();
  Future<bool> requestPermission();
}
