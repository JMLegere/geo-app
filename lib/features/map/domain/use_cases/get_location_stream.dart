import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

typedef GetLocationStreamInput = ({bool includeMetadata});

class GetLocationStream
    extends ObservableUseCase<GetLocationStreamInput, Stream<LocationState>> {
  GetLocationStream(this._repository, this._obs);

  final LocationRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'get_location_stream';

  @override
  Stream<LocationState> call(GetLocationStreamInput input) {
    return super.call(input) as Stream<LocationState>;
  }

  @override
  Stream<LocationState> execute(
    GetLocationStreamInput input,
    TraceContext context,
  ) {
    return _repository.positionStream;
  }
}
