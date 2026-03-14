import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/location_node_repository_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/features/sync/services/admin_boundary_service.dart';

/// Singleton [AdminBoundaryService] for fetching admin boundary polygons
/// from the `resolve-admin-boundaries` Supabase Edge Function and caching
/// them in local SQLite via [LocationNodeRepository].
///
/// Returns `null` when Supabase is not configured (no credentials supplied).
final adminBoundaryServiceProvider = Provider<AdminBoundaryService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;

  final locationNodeRepo = ref.watch(locationNodeRepositoryProvider);

  return AdminBoundaryService(
    client: client,
    repository: locationNodeRepo,
  );
});
