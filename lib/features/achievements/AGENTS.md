# Achievements Feature

Achievement tracking with toast notifications. Full feature: models/, providers/, services/, screens/, widgets/.

## Architecture

- `AchievementService` — Pure Dart class, no Riverpod. `evaluate(AchievementContext)` returns list of newly unlocked achievements.
- `AchievementNotifier` — reads playerProvider, inventoryProvider, restorationProvider, speciesServiceProvider. Calls `checkAchievements()` after state changes.
- `AchievementNotificationNotifier` — manages toast queue (separate from main state).

## Dual Notifier Pattern

Two providers cooperate:
1. `achievementProvider` — NotifierProvider<AchievementNotifier, AchievementsState>. Tracks all achievements, their progress, unlock status.
2. `achievementNotificationProvider` — NotifierProvider<AchievementNotificationNotifier, AchievementNotificationState>. Manages toast queue display/dismiss cycle.

This separation prevents UI toast state from polluting domain achievement state.

## Evaluation Flow

1. Game state changes (species collected, cell explored, streak updated)
2. Feature that changed state calls `achievementProvider.notifier.checkAchievements()`
3. AchievementNotifier builds AchievementContext from current state (reads 4 providers)
4. AchievementService.evaluate(context) returns newly unlocked achievements
5. If any new → updates state + pushes to notification queue
6. AchievementNotificationOverlay (widget) displays stacked toasts

## Service Pattern

AchievementService is a pure function container:
- Takes AchievementContext (snapshot of game state)
- Returns List<Achievement> (newly unlocked)
- Stateless — no side effects, no persistence, no Riverpod
- Testable with plain Dart unit tests

## Gotchas

- Achievement checks are PULL-based (explicit call), not reactive. Nothing auto-evaluates on state change.
- AchievementContext is built at check time by reading 4 providers — stale data is possible if providers haven't updated yet
- Toast queue is FIFO — achievements display in unlock order
- Achievement definitions are hardcoded in service (no external config or JSON)
- Hub feature: imports from discovery/, restoration/ — cannot be tested in isolation without those features

## Testing

- Service tests: pure unit tests with mock AchievementContext
- Provider tests: ProviderContainer + hand-written mocks for dependencies
- Widget tests: testWidgets() with MaterialApp wrapper
- No mockito/mocktail — all mocks are hand-written

## Integration Points

| Feature | Dependency | Why |
|---------|-----------|-----|
| discovery/ | DiscoveryEvent model | Achievement context includes recent discoveries |
| restoration/ | Restoration progress | Tracks restoration-based achievements |
| inventory/ | Item instance state | Tracks collection milestones |
| player/ | Player profile | Tracks exploration/streak achievements |

## File Structure

```
achievements/
├── models/
│   ├── achievement.dart              # Achievement definition
│   ├── achievement_context.dart      # Snapshot of game state for evaluation
│   └── achievements_state.dart       # Notifier state (unlocked, progress)
├── providers/
│   ├── achievement_provider.dart     # Main state notifier
│   └── achievement_notification_provider.dart  # Toast queue notifier
├── services/
│   └── achievement_service.dart      # Pure evaluation logic
├── screens/
│   └── achievements_screen.dart      # Full-page achievement list
└── widgets/
    └── achievement_notification_overlay.dart  # Toast display
```
