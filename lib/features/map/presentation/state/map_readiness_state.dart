class MapReadinessState {
  const MapReadinessState({
    required this.locationReady,
    required this.mapCreated,
    required this.styleLoaded,
    required this.baseMapSettled,
    required this.cellsFetched,
    required this.overlayFramePainted,
    this.bootstrapTimedOut = false,
    this.baseMapSettledSource,
  });

  const MapReadinessState.initial()
      : locationReady = false,
        mapCreated = false,
        styleLoaded = false,
        baseMapSettled = false,
        cellsFetched = false,
        overlayFramePainted = false,
        bootstrapTimedOut = false,
        baseMapSettledSource = null;

  final bool locationReady;
  final bool mapCreated;
  final bool styleLoaded;
  final bool baseMapSettled;
  final bool cellsFetched;
  final bool overlayFramePainted;
  final bool bootstrapTimedOut;
  final String? baseMapSettledSource;

  bool get isSteadyStateReady =>
      locationReady &&
      mapCreated &&
      styleLoaded &&
      baseMapSettled &&
      cellsFetched &&
      overlayFramePainted;

  List<String> get waitingFor => [
        if (!locationReady) 'location',
        if (!mapCreated) 'map_created',
        if (!styleLoaded) 'style_loaded',
        if (!baseMapSettled) 'base_map_settled',
        if (!cellsFetched) 'cells_fetched',
        if (!overlayFramePainted) 'overlay_frame_painted',
      ];

  MapReadinessState copyWith({
    bool? locationReady,
    bool? mapCreated,
    bool? styleLoaded,
    bool? baseMapSettled,
    bool? cellsFetched,
    bool? overlayFramePainted,
    bool? bootstrapTimedOut,
    String? baseMapSettledSource,
  }) {
    return MapReadinessState(
      locationReady: locationReady ?? this.locationReady,
      mapCreated: mapCreated ?? this.mapCreated,
      styleLoaded: styleLoaded ?? this.styleLoaded,
      baseMapSettled: baseMapSettled ?? this.baseMapSettled,
      cellsFetched: cellsFetched ?? this.cellsFetched,
      overlayFramePainted: overlayFramePainted ?? this.overlayFramePainted,
      bootstrapTimedOut: bootstrapTimedOut ?? this.bootstrapTimedOut,
      baseMapSettledSource: baseMapSettledSource ?? this.baseMapSettledSource,
    );
  }

  Map<String, dynamic> toLogData() => {
        'location_ready': locationReady,
        'map_created': mapCreated,
        'style_loaded': styleLoaded,
        'base_map_settled': baseMapSettled,
        'base_map_settled_source': baseMapSettledSource,
        'cells_fetched': cellsFetched,
        'overlay_frame_painted': overlayFramePainted,
        'steady_state_ready': isSteadyStateReady,
        'bootstrap_timed_out': bootstrapTimedOut,
        'waiting_for': waitingFor,
      };
}
