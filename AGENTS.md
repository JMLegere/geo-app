# Agent Guidance

- Default to debugging for root cause: when a feature misbehaves, add targeted logs first, capture exact inputs/outputs, and apply a 5-why analysis before changing logic.
- Prefer minimal, high-signal logs: include URLs (masked keys), status codes, key config flags, and derived values (e.g., speeds, zooms); avoid noisy per-frame spam unless explicitly needed.
- Respect free-tier constraints: if a paid API fails, fall back to free alternatives and log the attempted endpoint, why it failed, and what fallback was used.
- When changing defaults, surface the actual runtime values in a one-time startup log so inspector overrides don’t mask the change.
- Keep changes reversible: guard new behaviors with toggles and default to non-destructive fallbacks.
