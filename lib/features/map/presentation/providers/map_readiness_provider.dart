import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';

const kBaseMapSettledFallbackDelay = Duration(seconds: 5);
const kMapBootstrapTimeout = Duration(seconds: 12);

final mapReadinessProvider =
    NotifierProvider<MapReadinessNotifier, MapReadinessState>(
      MapReadinessNotifier.new,
    );

/// Owns the one-shot Map lifecycle milestones observed by app readiness.
class MapReadinessNotifier extends ObservableNotifier<MapReadinessState> {
  Timer? _baseMapSettledFallbackTimer;
  Timer? _bootstrapTimeoutTimer;
  var _generation = 0;
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);

  @override
  String get category => 'map';

  @override
  MapReadinessState build() {
    ref.onDispose(_cancelTimers);
    return const MapReadinessState.initial();
  }

  void start() {
    _generation++;
    _cancelTimers();
    transition(const MapReadinessState.initial(), 'map.readiness.started');
    final generation = _generation;
    _bootstrapTimeoutTimer = Timer(kMapBootstrapTimeout, () {
      if (generation != _generation || state.isSteadyStateReady) return;
      transition(
        state.copyWith(bootstrapTimedOut: true),
        'map.readiness.timed_out',
      );
    });
  }

  void reset() {
    _generation++;
    _cancelTimers();
    transition(const MapReadinessState.initial(), 'map.readiness.reset');
  }

  bool reportLocationReady(bool isReady) =>
      _update(state.copyWith(locationReady: isReady));

  bool reportMapCreated() => _update(state.copyWith(mapCreated: true));

  bool reportStyleLoaded() {
    final changed = _update(state.copyWith(styleLoaded: true));
    if (changed) _scheduleBaseMapSettledFallback();
    return changed;
  }

  bool reportCellsFetched(bool isFetched) {
    final changed = _update(state.copyWith(cellsFetched: isFetched));
    if (isFetched) _ensureBaseMapSettledFallback();
    return changed;
  }

  bool reportBaseMapSettled({required String source}) {
    if (state.baseMapSettled) return false;
    _baseMapSettledFallbackTimer?.cancel();
    _baseMapSettledFallbackTimer = null;
    _update(state.copyWith(baseMapSettled: true, baseMapSettledSource: source));
    return true;
  }

  bool reportOverlayFramePainted({required bool hasMeaningfulContent}) {
    if (!state.locationReady ||
        !state.mapCreated ||
        !state.styleLoaded ||
        !state.baseMapSettled ||
        !state.cellsFetched ||
        !hasMeaningfulContent ||
        state.overlayFramePainted) {
      return false;
    }
    _update(state.copyWith(overlayFramePainted: true));
    _bootstrapTimeoutTimer?.cancel();
    _bootstrapTimeoutTimer = null;
    return true;
  }

  void resetOverlayForRefetch() {
    if (!state.overlayFramePainted) return;
    _update(state.copyWith(overlayFramePainted: false));
  }

  bool _update(MapReadinessState next) {
    if (_sameMilestones(state, next)) return false;
    transition(next, 'map.readiness.changed', data: next.toLogData());
    return true;
  }

  void _ensureBaseMapSettledFallback() {
    if (state.baseMapSettled ||
        _baseMapSettledFallbackTimer != null ||
        !state.mapCreated ||
        !state.styleLoaded ||
        !state.cellsFetched) {
      return;
    }
    _scheduleBaseMapSettledFallback(source: 'readiness_safety_fallback');
  }

  void _scheduleBaseMapSettledFallback({
    String source = 'style_loaded_fallback',
  }) {
    if (state.baseMapSettled) return;
    _baseMapSettledFallbackTimer?.cancel();
    final generation = _generation;
    _baseMapSettledFallbackTimer = Timer(kBaseMapSettledFallbackDelay, () {
      _baseMapSettledFallbackTimer = null;
      if (generation != _generation) return;
      reportBaseMapSettled(source: source);
    });
  }

  void _cancelTimers() {
    _baseMapSettledFallbackTimer?.cancel();
    _baseMapSettledFallbackTimer = null;
    _bootstrapTimeoutTimer?.cancel();
    _bootstrapTimeoutTimer = null;
  }

  static bool _sameMilestones(
    MapReadinessState current,
    MapReadinessState next,
  ) {
    return current.locationReady == next.locationReady &&
        current.mapCreated == next.mapCreated &&
        current.styleLoaded == next.styleLoaded &&
        current.baseMapSettled == next.baseMapSettled &&
        current.cellsFetched == next.cellsFetched &&
        current.overlayFramePainted == next.overlayFramePainted &&
        current.bootstrapTimedOut == next.bootstrapTimedOut &&
        current.baseMapSettledSource == next.baseMapSettledSource;
  }
}
