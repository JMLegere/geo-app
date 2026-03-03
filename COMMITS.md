# Commit Convention

Format: `<emoji> <type>(<scope>): <description>`

One logical change per commit. Message focuses on **why**, not **what**.

---

## Types

Non-feat types use a fixed emoji regardless of scope:

| Emoji | Type | When |
|-------|------|------|
| 🐛 | fix | Bug fix |
| 🔧 | chore | Config, tooling, maintenance |
| ♻️ | refactor | Code restructuring (no behavior change) |
| 📝 | docs | Documentation only |
| ✅ | test | Adding or updating tests |
| 🚀 | ci | CI/CD or deployment changes |
| ⏱️ | perf | Performance improvement |

---

## feat Scopes

Each `feat` scope has a **unique emoji**. Use the scope's emoji when the commit type is `feat`.

### Core Layer (`lib/core/`)

| Emoji | Scope | Directory | Domain |
|-------|-------|-----------|--------|
| 🎬 | init | — | Project scaffolding, Flutter create output |
| 🧱 | models | `core/models/` | Domain models (species, cells, fog, seasons) |
| 🗃️ | db | `core/database/`, `supabase/` | Drift schema, Supabase migrations |
| 💾 | persistence | `core/persistence/` | SQLite repositories, data access |
| 🔮 | state | `core/state/` | Riverpod providers, state management |
| 🔷 | cells | `core/cells/` | Cell system (Voronoi, H3, caching) |
| 🌫️ | fog | `core/fog/` | Fog of war, visibility computation |
| 🧬 | species | `core/species/` | Species data, IUCN loader, loot table |

### Feature Layer (`lib/features/`)

| Emoji | Scope | Directory | Domain |
|-------|-------|-----------|--------|
| 🗺️ | map | `features/map/` | MapLibre rendering, fog overlay, camera |
| 🔐 | auth | `features/auth/` | Authentication, login/signup, guest mode |
| 📍 | location | `features/location/` | GPS service, simulation, Kalman filter |
| 🌿 | biome | `features/biome/` | Habitat classification, ESA mapping |
| 🔍 | discovery | `features/discovery/` | Species discovery mechanic |
| 🌡️ | seasonal | `features/seasonal/` | Seasonal species availability |
| 📓 | journal | `features/journal/` | Collection journal, species catalog |
| 🌱 | restoration | `features/restoration/` | Habitat restoration system |
| 🏛️ | sanctuary | `features/sanctuary/` | Sanctuary gallery, habitat sections |
| 🔥 | caretaking | `features/caretaking/` | Daily visit streaks |
| ☁️ | sync | `features/sync/` | Cloud sync, offline-first |
| 🏆 | achievements | `features/achievements/` | Achievement and milestone system |
| 🔬 | spike | `features/spikes/` | Research spikes, prototypes |

---

## Examples

```
🎬 feat(init): scaffold Flutter project with multiplatform targets
🧱 feat(models): add core domain models with unit tests
🗃️ feat(db): add Drift database schema with generated code
🗺️ feat(map): add map screen with fog overlay and layered architecture
🔐 feat(auth): add auth system with mock backend and guest mode
🐛 fix(fog): correct detection radius calculation at high latitudes
🔧 chore: update dependencies to latest stable versions
♻️ refactor(species): extract loot table into dedicated service
📝 docs: add MapLibre comparison and rendering research
✅ test: add offline mode verification integration suite
```

---

## Rules

1. **One logical change per commit.** Split by concern, not by file count.
2. **Test files go with implementation.** Never separate a feature from its tests.
3. **feat commits use the scope emoji.** Non-feat commits use the type emoji.
4. **Message body (optional)** explains the "why" in 1-2 sentences.
5. **Footer**: `Ultraworked with [Sisyphus](https://github.com/code-yeongyu/oh-my-opencode)`
6. **Trailer**: `Co-authored-by: Sisyphus <clio-agent@sisyphuslabs.ai>`

---

## Adding New Scopes

When a new feature area is introduced:

1. Choose a unique emoji not already in use
2. Add it to the appropriate table above (Core or Feature layer)
3. Use it consistently for all `feat` commits in that scope
