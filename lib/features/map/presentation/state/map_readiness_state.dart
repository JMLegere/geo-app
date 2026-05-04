class MapReadinessState {
  const MapReadinessState({
    required this.locationReady,
    required this.mapCreated,
    required this.styleLoaded,
    required this.baseMapSettled,
    required this.cellsFetched,
    required this.overlayFramePainted,
  });

  const MapReadinessState.initial()
      : locationReady = false,
        mapCreated = false,
        styleLoaded = false,
        baseMapSettled = false,
        cellsFetched = false,
        overlayFramePainted = false;

  final bool locationReady;
  final bool mapCreated;
  final bool styleLoaded;
  final bool baseMapSettled;
  final bool cellsFetched;
  final bool overlayFramePainted;

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

  Map<String, dynamic> toLogData() => {
        'location_ready': locationReady,
        'map_created': mapCreated,
        'style_loaded': styleLoaded,
        'base_map_settled': baseMapSettled,
        'cells_fetched': cellsFetched,
        'overlay_frame_painted': overlayFramePainted,
        'steady_state_ready': isSteadyStateReady,
        'waiting_for': waitingFor,
      };
}
