# core/state

Riverpod v3 global state providers. 21 providers total.

**Key providers:** `tabIndexProvider`, `fogProvider`, `locationProvider`, `playerProvider`, `seasonProvider`, `gameCoordinatorProvider`, `appDatabaseProvider`, `cellServiceProvider`, `fogResolverProvider`, `dailySeedServiceProvider`, `zoneReadyProvider`, `playerLocatedProvider`.

**Key rules:**
- All mutable state uses `NotifierProvider<T, S>` — never `StateNotifier`, never `ChangeNotifier`.
- Notifiers extend `Notifier<T>`, override `build()` for initialization.
- No `.family` or `.autoDispose` — all providers are global singletons.
- `gameCoordinatorProvider` is a justified exception to core→features dependency rule — it wires core services to feature-layer callbacks.
- `locationProvider.connectToStream()` is called by feature-layer (core does NOT import features/).
- Infrastructure providers (`cellServiceProvider`, `fogResolverProvider`) use `Provider<T>`, not Notifier.

See /lib/core/AGENTS.md for full provider list and dependency graph.
