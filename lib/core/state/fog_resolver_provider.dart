import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';

/// Provides the global [FogStateResolver] instance.
///
/// Depends on [cellServiceProvider] for cell geometry. Disposed automatically
/// when the provider is invalidated (closes the internal stream controller).
final fogResolverProvider = Provider<FogStateResolver>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final resolver = FogStateResolver(cellService);
  ref.onDispose(() => resolver.dispose());
  return resolver;
});
