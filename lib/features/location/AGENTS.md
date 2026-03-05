# Location Feature

GPS, keyboard simulation, and filtering services. Pure services with no Riverpod providers — lifecycle managed by map_screen.dart.

## Architecture

3 location modes, all implement the same stream contract:
- `GpsLocationService` — Real device GPS via geolocator package
- `KeyboardLocationSimulator` — WASD/arrow key movement for desktop testing  
- `MockLocationService` — Fixed position for unit tests

`LocationFilter` sits downstream: deduplicates, accuracy-gates (kGpsAccuracyThreshold = 50m), rate-limits.

## Stream Contract

All services expose:
- `start()` / `stop()` — lifecycle control
- `filteredLocationStream` → `Stream<({Geographic position, double accuracy})>`
- `rawLocationStream` → unfiltered (for debugging)

**CRITICAL**: Subscribe to streams BEFORE calling `start()`. Broadcast streams lose events if subscriber registers after start. This was a real bug (player marker invisible on load).

## Service Selection

Currently hardcoded in `location_service_provider.dart` based on platform:
- Web → KeyboardLocationSimulator (no GPS API)
- Mobile/Desktop → GpsLocationService with LocationFilter

No runtime switching. Mode set at provider creation.

## Keyboard Simulator

- WASD + arrow keys, 10m per step
- Long-press: periodic timer at 100ms intervals
- Calculates lat/lon delta using Haversine (respects current latitude for longitude scaling)
- Initial position: kDefaultMapLat/Lon (Fredericton, NB)
- DPadControls widget provides on-screen equivalent for mobile web

## Gotchas

- `start()` is async but does NOT await first GPS fix — returns immediately
- `GpsLocationService` requests permission on first `start()` call, not at construction
- Filter passes through the FIRST update unthrottled (so UI shows something immediately)
- `dispose()` must be called — stream subscriptions leak otherwise
- On web, geolocator stub returns empty stream — keyboard sim is the only real source
- LocationNotifier (in core/state/) connects to the stream via `connectToStream()` — core does NOT depend on features/

## Testing

- `MockLocationService` for unit tests — fixed position, no streams
- Keyboard sim for manual testing on desktop/web
- Real GPS testing requires physical device or emulator with location mocking

## Dependencies

- `geolocator` — GPS access (platform-specific implementations)
- `geobase` — Geographic type (lat/lon wrapper)
- `shared/constants.dart` — kGpsAccuracyThreshold, kDefaultMapLat/Lon

## File Map

```
services/
├── gps_location_service.dart       # Real GPS via geolocator
├── keyboard_location_simulator.dart # WASD/arrow key movement
├── location_filter.dart            # Accuracy gate + dedup + rate limit
├── location_service_provider.dart  # Platform-based service selection
└── mock_location_service.dart      # Fixed position for tests

widgets/
└── dpad_controls.dart              # On-screen WASD for mobile web
```

## Future Work

- Runtime mode switching (GPS ↔ keyboard)
- Replay mode (GPX track playback)
- Geofencing / zone triggers
