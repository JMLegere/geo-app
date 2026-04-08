import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/observability/observability_service.dart';

final observableUseCaseProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});
