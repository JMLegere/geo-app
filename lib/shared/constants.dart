// Game constants for Fog of World.
// Centralizes all game-balance constants to ensure consistency
// across the codebase and simplify tuning.

// Species / Habitat / IUCN
/// Number of habitat types in the game (from IUCN dataset).
const int kHabitatCount = 7;

/// Number of IUCN status tiers used as rarity tiers.
const int kIucnStatusTiers = 6;

/// Number of continents supported.
const int kContinentCount = 6;

// Fog of War
/// Number of discrete fog states.
const int kFogLevels = 5;

/// Detection radius in meters. Cells within this distance of the player
/// are detected (at minimum `FogState.unexplored`) even if never visited.
const double kDetectionRadiusMeters = 50000.0;

/// Fog density values for each state.
/// Index 0 = Undetected (fully opaque), Index 4 = Observed (fully transparent).
const List<double> kFogDensityValues = [1.0, 0.95, 0.75, 0.5, 0.0];

// Seasons
/// Number of seasons in the game.
const int kSeasons = 2;

/// Season names.
const List<String> kSeasonNames = ['summer', 'winter'];

// Default Map Position (Fredericton, NB, Canada)
/// Default map center latitude.
const double kDefaultMapLat = 45.9636;

/// Default map center longitude.
const double kDefaultMapLon = -66.6431;

// Lazy Voronoi Cell Grid (infinite world)
//
// Tuned for walking-speed exploration (5 km/h ≈ 83 m/min):
// - Median cell diameter ~180m → ~2 min between discoveries (dopamine sweet spot)
// - High jitter creates 100–280m range → variable ratio reinforcement schedule
// - GPS accuracy (50m) well below min cell size → no false crossings
/// Grid step in degrees for lazy Voronoi seed placement (≈ 180m at 45° lat).
const double kVoronoiGridStep = 0.002;

/// Jitter factor (0.0–1.0). Higher = more variable cell sizes = stronger
/// variable-ratio reinforcement (the most addictive reward schedule).
const double kVoronoiJitterFactor = 0.75;

/// Global seed for deterministic Voronoi cell placement.
const int kVoronoiGlobalSeed = 42;

/// Grid radius for local Delaunay triangulation (radius=3 → 7×7 = 49 seeds).
const int kVoronoiNeighborRadius = 3;

// Legacy Voronoi Cell Grid (fixed bounding box — used by VoronoiCellService)
/// Voronoi grid minimum latitude.
const double kVoronoiMinLat = 37.5;

/// Voronoi grid maximum latitude.
const double kVoronoiMaxLat = 38.0;

/// Voronoi grid minimum longitude.
const double kVoronoiMinLon = -122.7;

/// Voronoi grid maximum longitude.
const double kVoronoiMaxLon = -122.2;

/// Voronoi grid row count.
const int kVoronoiGridRows = 40;

/// Voronoi grid column count.
const int kVoronoiGridCols = 40;

/// Voronoi grid seed for deterministic cell placement.
const int kVoronoiSeed = 42;

// Map & Location
/// Minimum map zoom level.
const double kMinZoom = 14.0;

/// Maximum map zoom level.
const double kMaxZoom = 18.0;

/// Default map zoom level.
const double kDefaultZoom = 15.0;

/// GPS accuracy threshold (meters). If accuracy exceeds this, fall back to simulation.
const double kGpsAccuracyThreshold = 50.0;

/// GPS update frequency (Hz).
const double kGpsUpdateFrequency = 1.0;

// Cells & Tiles
/// Maximum number of cells per tile.
const int kMaxCellsPerTile = 100;

/// Tile prefetch radius (in tiles).
const int kTilePrefetchRadius = 1;

// Camera
/// Camera follow distance (meters).
const double kCameraFollowDistance = 50.0;

/// Camera zoom animation duration (milliseconds).
const int kCameraZoomDurationMs = 300;

// Logging
/// Enable debug logging for GPS updates.
const bool kDebugLogGps = false;

/// Enable debug logging for tile requests.
const bool kDebugLogTiles = false;

/// Enable debug logging for fog state transitions.
const bool kDebugLogFogState = false;

/// Enable debug logging for persistence operations.
const bool kDebugLogPersistence = false;


