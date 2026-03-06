# Navigation Feature — Agent Guidance

4-tab bottom navigation shell. Root widget after auth.

## Directory Structure

```
features/navigation/
├── providers/
│   └── tab_index_provider.dart   # Tab selection state + SharedPreferences persistence
└── screens/
    ├── tab_shell.dart            # IndexedStack + BottomNavigationBar
    └── town_placeholder_screen.dart  # "Coming Soon" EmptyStateWidget
```

## Tab Layout

| Index | Label | Screen | Icon |
|-------|-------|--------|------|
| 0 | Map | MapScreen | `Icons.explore` |
| 1 | Home | SanctuaryScreen | `Icons.home` |
| 2 | Town | TownPlaceholderScreen | `Icons.people` |
| 3 | Pack | PackScreen | `Icons.backpack` |

## Key Architecture Decisions

1. **IndexedStack keep-alive** — All 4 children are mounted simultaneously. Only the active tab is painted. MapScreen's GPS stream, fog state, and 60fps Ticker persist across tab switches.

2. **BottomNavigationBar (M2)** — Uses stock Material 2 BottomNavigationBar, styled by existing `BottomNavigationBarThemeData` in `app_theme.dart`. No custom tab bar.

3. **Tab persistence** — `TabIndexNotifier` saves selected index to SharedPreferences (key: `'selected_tab_index'`). Follows `onboarding_provider.dart` pattern: async load in `build()`, guard with `ref.mounted`.

4. **Web MapVisibility** — `ref.listen(tabIndexProvider, ...)` in TabShell calls `MapVisibility.hideMapContainer()` / `revealMapContainer()` when switching away from/back to Map tab. On native, MapVisibility is a no-op.

## Gotchas

- **MapScreen Ticker runs in background** — When on non-Map tabs, the 60fps RubberBand Ticker continues. Optimization deferred to v2.
- **Discovery/achievement toasts stay in MapScreen** — Notifications fire in MapScreen's overlay. They're invisible on non-Map tabs. Migrating to shell-level is v2.
- **Scaffold insets** — TabShell's `Scaffold(bottomNavigationBar: ...)` automatically insets the body by nav bar height. No manual offset needed for MapScreen bottom widgets.

## Known Limitations

- Gear/settings icon not implemented (deferred to v2)
- Keyboard DPad scoping — arrow keys may drive map movement from non-Map tabs
- Town tab is placeholder only — no NPC data or interaction
