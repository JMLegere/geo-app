class BrowserVisualCapture {
  const BrowserVisualCapture({
    required this.name,
    required this.path,
    required this.reason,
    this.requiresRetainedMarker = true,
    this.viewport = 'wide',
    this.width = 1440,
    this.height = 1000,
  });

  final String name;
  final String path;
  final String reason;
  final bool requiresRetainedMarker;
  final String viewport;
  final int width;
  final int height;
}

final browserVisualCaptures = <BrowserVisualCapture>[
  ..._browserVisualStates,
  for (final capture in _browserVisualStates)
    BrowserVisualCapture(
      name: '${capture.name}--narrow',
      path: capture.path,
      reason: capture.reason,
      requiresRetainedMarker: capture.requiresRetainedMarker,
      viewport: 'narrow',
      width: 390,
      height: 844,
    ),
];

const _browserVisualStates = <BrowserVisualCapture>[
  BrowserVisualCapture(
    name: 'map-root-screen-00-happy-path',
    path: 'product-surfaces/map/maprootscreen/00-happy-path',
    reason: 'MapRootScreen starts at the cell-level MapLibre platform view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-00-happy-path',
    path: 'product-surfaces/map/mapscreen/00-happy-path',
    reason: 'MapScreen is the real retained MapLibre platform view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-dart-renderer-fallback',
    path: 'product-surfaces/map/mapscreen/dart-renderer-fallback',
    reason: 'The fallback still initializes the MapLibre platform view.',
    requiresRetainedMarker: false,
  ),
  BrowserVisualCapture(
    name: 'map-screen-debug-ring',
    path: 'product-surfaces/map/mapscreen/debug-ring',
    reason: 'The debug ring renders over the retained MapLibre view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-error',
    path: 'product-surfaces/map/mapscreen/error',
    reason: 'The error state renders over the retained MapLibre view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-loading',
    path: 'product-surfaces/map/mapscreen/loading',
    reason: 'The loading state renders over the retained MapLibre view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-paused-discovery',
    path: 'product-surfaces/map/mapscreen/paused-discovery',
    reason: 'The paused state renders over the retained MapLibre view.',
  ),
  BrowserVisualCapture(
    name: 'map-screen-refreshing',
    path: 'product-surfaces/map/mapscreen/refreshing',
    reason: 'The refreshing state renders over the retained MapLibre view.',
  ),
];
