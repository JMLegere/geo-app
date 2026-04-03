# domain/fog/

Fog-of-war state resolution. FogState is COMPUTED from player position + visit history — never stored.

Key: `onLocationUpdate()` stream uses `sync: true`. Detection radius = `kDetectionRadiusMeters` (1000m).

See /AGENTS.md for project-wide rules.
