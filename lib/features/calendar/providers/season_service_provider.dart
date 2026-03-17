import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/calendar/services/season_service.dart';

/// Provides a singleton [SeasonService].
///
/// [SeasonService] is stateless, so a single instance is shared across the
/// widget tree. Inject this provider into `DiscoveryService` to enable
/// seasonal species filtering.
final seasonServiceProvider = Provider<SeasonService>(
  (_) => const SeasonService(),
);
