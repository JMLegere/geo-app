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
const List<double> kFogDensityValues = [1.0, 0.75, 0.5, 0.25, 0.0];

// Seasons
/// Number of seasons in the game.
const int kSeasons = 2;

/// Season names.
const List<String> kSeasonNames = ['summer', 'winter'];

// Map & Location
/// Minimum map zoom level.
const double kMinZoom = 12.0;

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

// Persistence & Sync
/// Maximum number of events in the sync queue.
const int kMaxSyncQueueSize = 1000;

/// Maximum number of sync retry attempts.
const int kMaxSyncRetries = 5;

/// Initial sync retry delay (milliseconds).
const int kInitialSyncRetryDelayMs = 1000;

/// Maximum sync retry delay (milliseconds).
const int kMaxSyncRetryDelayMs = 30000;

// Camera
/// Camera follow distance (meters).
const double kCameraFollowDistance = 50.0;

/// Camera zoom animation duration (milliseconds).
const int kCameraZoomDurationMs = 300;

// Logging
/// Enable debug logging for GPS updates.
const bool kDebugLogGps = true;

/// Enable debug logging for tile requests.
const bool kDebugLogTiles = true;

/// Enable debug logging for fog state transitions.
const bool kDebugLogFogState = true;

/// Enable debug logging for persistence operations.
const bool kDebugLogPersistence = true;

/// Enable debug logging for sync events.
const bool kDebugLogSync = true;
