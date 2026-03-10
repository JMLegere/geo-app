// Game constants for EarthNova.
// Centralizes all game-balance constants to ensure consistency
// across the codebase and simplify tuning.

// Species / Habitat / IUCN / Item Categories
/// Number of habitat types in the game (from IUCN dataset).
const int kHabitatCount = 7;

/// Number of IUCN status tiers used as rarity tiers.
const int kIucnStatusTiers = 6;

/// Number of continents supported.
const int kContinentCount = 6;

/// Number of item categories (fauna, flora, mineral, fossil, artifact, food, orb).
const int kItemCategoryCount = 7;

// Animal Types & Classes
/// Number of animal types (Mammal, Bird, Fish, Reptile, Bug).
const int kAnimalTypeCount = 5;

/// Number of game-designed animal classes across all types.
const int kAnimalClassCount = 35;

// Climate
/// Number of climate zones.
const int kClimateZoneCount = 4;

/// Maximum absolute latitude for the Tropic climate zone.
const double kTropicMaxLatitude = 23.5;

/// Maximum absolute latitude for the Temperate climate zone.
const double kTemperateMaxLatitude = 55.0;

/// Maximum absolute latitude for the Boreal climate zone.
const double kBorealMaxLatitude = 66.5;

// Food & Orbs
/// Number of food subtypes (critter, fish, fruit, grub, nectar, seed, veg).
const int kFoodTypeCount = 7;

/// Number of orb dimensions (habitat, animalClass, climate).
const int kOrbDimensionCount = 3;

// Encounters
/// Number of species rolled per cell visit.
const int kEncounterSlotsPerCell = 1;

// Fog of War
/// Number of discrete fog states.
const int kFogLevels = 5;

/// Detection radius in meters. Cells within this distance of the player
/// are detected (at minimum `FogState.unexplored`) even if never visited.
const double kDetectionRadiusMeters = 1000.0;

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
/// Minimum map zoom level. Set to 10 to prevent extreme zoom-out which
/// causes rendering issues and is not useful for walking-speed exploration.
const double kMinZoom = 10.0;

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

// Rubber-Band Marker Interpolation
//
// The player marker is decoupled from raw GPS coordinates and smoothly
// interpolated toward the target position at 60fps via a Ticker. The
// invisible "real" GPS position drags the visible marker like a rubber band.

/// Minimum marker speed in meters/second (5 km/h).
/// Prevents the marker from creeping when the player is nearly stationary.
const double kRubberBandMinSpeedMps = 1.389;

/// Speed multiplier applied to the distance between display and target.
/// `speed = max(minSpeed, k * distance)`. At steady state the lag distance
/// equals `playerSpeed / k`. With k = 1/3.6 ≈ 0.278, 100 km/h produces
/// ~100 m of lag, 50 km/h → ~50 m, walking (5 km/h) → ~5 m.
const double kRubberBandSpeedMultiplier = 1.0 / 3.6;

/// Distance threshold in meters below which the marker snaps to the target.
/// Prevents sub-pixel oscillation when effectively arrived.
const double kRubberBandSnapThresholdMeters = 0.5;

// Logging
/// Enable debug logging for GPS updates.
const bool kDebugLogGps = false;

/// Enable debug logging for tile requests.
const bool kDebugLogTiles = false;

/// Enable debug logging for fog state transitions.
const bool kDebugLogFogState = false;

/// Enable debug logging for persistence operations.
const bool kDebugLogPersistence = false;

// Species Stats
/// Minimum stat value (speed, brawn, wit).
const int kStatMin = 1;

/// Maximum stat value (speed, brawn, wit).
const int kStatMax = 100;

/// Range used in `hash[i] % kStatRange + kStatMin` to produce 1–100.
const int kStatRange = 100;

/// Sum that a species' base stats (speed + brawn + wit) must total.
const int kStatBaseSum = 90;

/// Per-instance stat variance (±30 absolute). Instance stat = base ± 30,
/// clamped to [kStatMin, kStatMax].
const int kStatVariance = 30;

/// Affix ID for the intrinsic base-stats affix.
const String kIntrinsicAffixId = 'base_stats';

/// Key used in the intrinsic affix values map for weight in grams.
const String kWeightAffixKey = 'weightGrams';

/// Key used in the intrinsic affix values map for size category name.
const String kSizeAffixKey = 'size';

/// Seed prefix for weight rolling. Prepended to instanceSeed before hashing
/// to domain-separate the weight roll from the stat roll.
const String kWeightSeedPrefix = 'weight:';

/// Number of animal size categories.
const int kAnimalSizeCount = 9;

// Instance Badges
/// Badge: first global instance of this species ever caught (shiny foil).
const String kBadgeFirstDiscovery = 'first_discovery';

/// Badge: caught during beta period.
const String kBadgeBeta = 'beta';

/// Badge: among the first 50 catchers of this species (#2–50).
const String kBadgePioneer = 'pioneer';

/// Badge: winning community art selected for this species.
const String kBadgeArtWinner = 'art_winner';

// Write Queue (Phase 3: Server-Authoritative Persistence)
/// Maximum retry attempts before marking a queue entry as stale.
const int kWriteQueueMaxRetries = 5;

/// Age in hours after which unsynced queue entries are considered stale.
const int kWriteQueueStaleAgeHours = 72;

/// Base delay in seconds for exponential backoff between retries.
/// Actual delay = kWriteQueueRetryBaseSeconds * 2^attempts.
const int kWriteQueueRetryBaseSeconds = 2;

/// Maximum batch size when flushing the write queue.
const int kWriteQueueFlushBatchSize = 50;

/// Debounce delay in seconds before auto-flushing the write queue.
/// Batches rapid game events (e.g., 3 discoveries in quick succession)
/// into a single network round-trip.
const int kWriteQueueAutoFlushDelaySeconds = 3;

// Daily Seed (Phase 4: Deterministic Daily Encounters)
/// Grace period in hours for a cached daily seed before discoveries pause.
/// After this duration, the client must refresh the seed from the server.
const int kDailySeedGraceHours = 24;

/// Fallback seed used when Supabase is not configured (offline-only mode).
/// Provides deterministic but non-rotating encounters.
const String kDailySeedOfflineFallback = 'offline_no_rotation';

// Auth & Upgrade
/// Number of collected species that triggers the "save your progress" upgrade prompt.
const int kUpgradePromptThreshold = 5;

/// Minimum seconds after app open before the upgrade prompt can appear.
/// Prevents interrupting early exploration.
const int kUpgradePromptDelaySeconds = 120;

/// Application version string displayed in Settings.
const String kAppVersion = '0.1.0';

// Step-based Exploration
/// Minimum steps granted per day since last login during step hydration.
///
/// On login, the actual pedometer delta is compared against
/// `daysSinceLastSession × kMinDailyStepGrant` and the larger value wins.
/// This guarantees progress even when the pedometer is unavailable (web) or
/// the device was stationary.
const int kMinDailyStepGrant = 1000;

/// Step cost for remotely exploring a frontier cell via the cell info sheet.
///
/// Spending this many steps calls [FogStateResolver.visitCellRemotely], which
/// marks the cell as visited and triggers species discoveries via the
/// [DiscoveryService] subscription.
const int kStepCostPerCell = 1000;

/// Build timestamp injected via `--dart-define=BUILD_TIMESTAMP=...` at build
/// time. Falls back to 'dev' for local development runs.
const String kBuildTimestamp = String.fromEnvironment(
  'BUILD_TIMESTAMP',
  defaultValue: 'dev',
);

// Web Platform Movement (5x slower than current, since web has no pedometer)
/// Step distance in meters for web keyboard/D-pad movement per tick.
/// 5x reduction from original 10.0 to match realistic walking speed (~4 m/s).
const double kWebKeyboardStepMeters = 2.0;

/// Tick interval in milliseconds for web keyboard/D-pad movement.
/// 5x increase from original 100ms to slow down movement cadence.
const int kWebKeyboardTickIntervalMs = 500;
