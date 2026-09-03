import 'package:earth_nova/app/sync/application/identification_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Composition-root supplied durable Identification synchronization boundary.
final identificationSyncServiceProvider = Provider<IdentificationSyncService?>(
  (_) => null,
);
