import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/domain/fog/fog_resolver.dart';
import 'package:earth_nova/models/fog_state.dart';
import 'package:earth_nova/providers/cell_provider.dart';

// ---------------------------------------------------------------------------
// Resolver provider (domain — feeds GameEngine)
// ---------------------------------------------------------------------------

/// The [FogStateResolver] used by [GameEngine] for fog computation.
///
/// Exposed as a provider so [engine_provider] can inject it into [GameEngine]
/// and [fog_provider] can call [loadVisitedCells] at hydration time.
final fogResolverProvider = Provider<FogStateResolver>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final resolver = FogStateResolver(cellService);
  ref.onDispose(resolver.dispose);
  return resolver;
});

// ---------------------------------------------------------------------------
// Fog map state (UI — rendered fog overlay)
// ---------------------------------------------------------------------------

/// UI fog map: cellId → [FogState] pushed by engine events.
///
/// Updated by [engine_provider] when it receives `fog_changed` events.
/// Map screen reads this to render the fog overlay.
final fogProvider =
    NotifierProvider<FogNotifier, Map<String, FogState>>(FogNotifier.new);

class FogNotifier extends Notifier<Map<String, FogState>> {
  @override
  Map<String, FogState> build() => const {};

  /// Merge a batch of fog state changes into the map.
  void updateFog(Map<String, FogState> updates) {
    state = {...state, ...updates};
  }

  /// Replace the entire fog map.
  void replaceAll(Map<String, FogState> fogMap) =>
      state = Map.unmodifiable(fogMap);

  /// Reset fog map (e.g., on sign-out).
  void clear() => state = const {};
}

// ---------------------------------------------------------------------------
// Convenience: expose cell service via fog_provider for use in resolvers
// ---------------------------------------------------------------------------
// (CellService is already accessible via cellServiceProvider — no re-export needed.)
