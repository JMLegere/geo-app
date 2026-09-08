import 'dart:async';

import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/app/readiness/app_readiness_gate.dart';
import 'package:earth_nova/app/readiness/client_working_set.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/app/save/data/sembast_local_save_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('AppReadinessNotifier', () {
    test(
      'hydrates immediately, refreshes in background, and purges on sign out',
      () async {
        final store = _FakeWorkingSetStore(
          _memoryStore(),
          snapshot: _snapshot(),
        );
        final refresh = Completer<bool>();
        final map = _FakeMapNotifier(refresh: refresh.future);
        final items = _FakeItemsNotifier();
        final container = _container(store: store, map: map, items: items);
        addTearDown(container.dispose);
        _readyMapSurface(container);

        await container.read(appReadinessProvider.notifier).start('user-1');

        expect(
          container.read(appReadinessProvider).phase,
          AppReadinessPhase.syncing,
        );
        expect(container.read(appReadinessProvider).permitsInput, isTrue);
        expect(map.hydrateCalls, 1);
        expect(items.hydrateCalls, 1);

        refresh.complete(true);
        await _drain();
        expect(
          container.read(appReadinessProvider).phase,
          AppReadinessPhase.usable,
        );
        expect(store.saved, 1);
        expect(
          container
              .read(appObservabilityProvider)
              .pendingLogRecords
              .map((record) => record['event_name']),
          containsAll([
            'app.readiness.started',
            'app.readiness.snapshot_hydrated',
            'app.readiness.usable',
            'app.readiness.refresh_completed',
          ]),
        );

        expect(
          await container.read(appReadinessProvider.notifier).purge('user-1'),
          isTrue,
        );
        expect(store.purged, ['user-1']);
        expect(
          container.read(appReadinessProvider).phase,
          AppReadinessPhase.hydrating,
        );
      },
    );

    test(
      'keeps a valid snapshot usable when background Map refresh fails',
      () async {
        final store = _FakeWorkingSetStore(
          _memoryStore(),
          snapshot: _snapshot(),
        );
        final map = _FakeMapNotifier(refresh: Future.value(false));
        final items = _FakeItemsNotifier();
        final container = _container(store: store, map: map, items: items);
        addTearDown(container.dispose);
        _readyMapSurface(container);

        await container.read(appReadinessProvider.notifier).start('user-1');
        await _drain();

        final state = container.read(appReadinessProvider);
        expect(state.phase, AppReadinessPhase.degraded);
        expect(state.permitsInput, isTrue);
        expect(store.saved, 0);
        expect(map.hydrateCalls, 2);
        expect(items.hydrateCalls, 2);
      },
    );

    test('skips persistence for legacy and unknown environments', () async {
      for (final environment in ['beta', 'production', 'unknown']) {
        final store = _FakeWorkingSetStore(
          _memoryStore(),
          snapshot: _snapshot(environment: environment),
        );
        final container = _container(
          store: store,
          map: _FakeMapNotifier(
            initial: const MapStateError('Map unavailable'),
            refresh: Future.value(false),
          ),
          items: _FakeItemsNotifier(),
          environment: environment,
        );

        await container.read(appReadinessProvider.notifier).start('user-1');
        expect(store.loadCalls, 0);
        expect(
          await container.read(appReadinessProvider.notifier).purge('user-1'),
          isTrue,
        );
        expect(store.saved, 0);
        expect(store.purged, ['user-1']);
        container.dispose();
      }
    });

    test('persists working sets only in local and prod environments', () async {
      for (final environment in ['local', 'prod']) {
        final store = _FakeWorkingSetStore(
          _memoryStore(),
          snapshot: _snapshot(environment: environment),
        );
        final container = _container(
          store: store,
          map: _FakeMapNotifier(refresh: Future.value(true)),
          items: _FakeItemsNotifier(),
          environment: environment,
        );
        _readyMapSurface(container);

        await container.read(appReadinessProvider.notifier).start('user-1');
        await _drain();
        expect(store.loadCalls, 1);
        expect(store.saved, 1);
        expect(
          await container.read(appReadinessProvider.notifier).purge('user-1'),
          isTrue,
        );
        expect(store.purged, ['user-1']);
        container.dispose();
      }
    });

    test('blocks sign out when the player snapshot cannot be purged', () async {
      final store = _FakeWorkingSetStore(_memoryStore(), throwOnPurge: true);
      final container = _container(
        store: store,
        map: _FakeMapNotifier(refresh: Future.value(false)),
        items: _FakeItemsNotifier(),
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appReadinessProvider.notifier).purge('user-1'),
        isFalse,
      );
      expect(
        container.read(appReadinessProvider).errorMessage,
        "Couldn't safely clear this device. Try again.",
      );
    });

    test('blocks cacheless entry when required data cannot load', () async {
      final store = _FakeWorkingSetStore(_memoryStore());
      final container = _container(
        store: store,
        map: _FakeMapNotifier(
          initial: const MapStateError('Map unavailable'),
          refresh: Future.value(false),
        ),
        items: _FakeItemsNotifier(),
      );
      addTearDown(container.dispose);

      await container.read(appReadinessProvider.notifier).start('user-1');

      final state = container.read(appReadinessProvider);
      expect(state.phase, AppReadinessPhase.failed);
      expect(state.permitsInput, isFalse);
      expect(state.errorMessage, 'Map unavailable');
    });
  });

  group('AppReadinessGate', () {
    testWidgets('starts the real notifier after the first widget build', (
      tester,
    ) async {
      final store = _FakeWorkingSetStore(_memoryStore());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientWorkingSetStoreProvider.overrideWithValue(store),
            mapProvider.overrideWith(
              () => _FakeMapNotifier(
                initial: const MapStateError('Map unavailable'),
                refresh: Future.value(false),
              ),
            ),
            itemsProvider.overrideWith(() => _FakeItemsNotifier()),
            appReadinessEnvironmentProvider.overrideWithValue('local'),
            appObservabilityProvider.overrideWithValue(
              ObservabilityService(sessionId: 'gate-lifecycle-test'),
            ),
          ],
          child: const ShadApp(
            home: AppReadinessGate(
              userId: 'user-1',
              child: Text('Map mounted'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Map unavailable'), findsOneWidget);
    });

    testWidgets('reveals real checkpoint details only after 250ms', (
      tester,
    ) async {
      final readiness = _StaticReadinessNotifier(
        const AppReadinessState.initial(),
      );
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appReadinessProvider.overrideWith(() => readiness)],
          child: const ShadApp(
            home: AppReadinessGate(
              userId: 'user-1',
              child: Text('Map mounted'),
            ),
          ),
        ),
      );

      expect(find.text('Preparing your expedition'), findsOneWidget);
      expect(find.byType(ShadProgress), findsOneWidget);
      final progress = tester.getSemantics(
        find.byKey(const Key('readiness-progress')),
      );
      expect(progress.label, 'Readiness progress');
      expect(progress.value, '0 of 3 checkpoints complete');
      expect(progress.flagsCollection.isLiveRegion, isTrue);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byKey(const Key('readiness-input-gate')),
            )
            .absorbing,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 249));
      expect(find.text('Saved expedition'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Saved expedition'), findsOneWidget);
      expect(find.text('Pack'), findsOneWidget);
      expect(find.text('Map surface'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(3));
      semantics.dispose();
    });

    testWidgets('failure offers Retry and Sign out instead of progress', (
      tester,
    ) async {
      final events = <String>[];
      final readiness = _StaticReadinessNotifier(
        const AppReadinessState(
          phase: AppReadinessPhase.failed,
          completedCheckpoints: {},
          errorMessage: "Couldn't safely clear this device. Try again.",
        ),
        onPurge: () => events.add('purge'),
      );
      final auth = _StaticAuthNotifier(events);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appReadinessProvider.overrideWith(() => readiness),
            authProvider.overrideWith(() => auth),
          ],
          child: const ShadApp(
            home: AppReadinessGate(
              userId: 'user-1',
              child: Text('Map mounted'),
            ),
          ),
        ),
      );

      expect(
        find.text("Couldn't safely clear this device. Try again."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(AppButton), findsNWidgets(2));
      expect(find.byType(ShadProgress), findsNothing);

      await tester.tap(find.text('Retry'));
      expect(readiness.retryCalls, 1);
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(events, ['purge', 'sign_out']);
    });

    testWidgets('degraded entry keeps the app visible with a status banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appReadinessProvider.overrideWith(
              () => _StaticReadinessNotifier(
                const AppReadinessState(
                  phase: AppReadinessPhase.degraded,
                  completedCheckpoints: AppReadinessState.requiredCheckpoints,
                ),
              ),
            ),
          ],
          child: const ShadApp(
            home: AppReadinessGate(
              userId: 'user-1',
              child: Text('Map mounted'),
            ),
          ),
        ),
      );

      expect(find.text('Map mounted'), findsOneWidget);
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Using your latest saved expedition'), findsOneWidget);
      expect(find.text('Preparing your expedition'), findsNothing);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byKey(const Key('readiness-input-gate')),
            )
            .absorbing,
        isFalse,
      );
    });

    testWidgets('syncing keeps the app visible with an informative notice', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appReadinessProvider.overrideWith(
              () => _StaticReadinessNotifier(
                const AppReadinessState(
                  phase: AppReadinessPhase.syncing,
                  completedCheckpoints: AppReadinessState.requiredCheckpoints,
                ),
              ),
            ),
          ],
          child: const ShadApp(
            home: AppReadinessGate(
              userId: 'user-1',
              child: Text('Map mounted'),
            ),
          ),
        ),
      );

      expect(find.text('Map mounted'), findsOneWidget);
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Syncing expedition'), findsOneWidget);
      expect(
        tester
            .widget<AbsorbPointer>(
              find.byKey(const Key('readiness-input-gate')),
            )
            .absorbing,
        isFalse,
      );
    });

    testWidgets(
      'whole-save conflict keeps gameplay visible and offers branches',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appReadinessProvider.overrideWith(
                () => _StaticReadinessNotifier(
                  const AppReadinessState(
                    phase: AppReadinessPhase.conflict,
                    completedCheckpoints: AppReadinessState.requiredCheckpoints,
                    errorMessage:
                        'This device and the cloud both have progress.',
                  ),
                ),
              ),
            ],
            child: const ShadApp(
              home: AppReadinessGate(
                userId: 'user-1',
                child: Text('Map mounted'),
              ),
            ),
          ),
        );

        expect(find.text('Map mounted'), findsOneWidget);
        expect(find.text('Choose your expedition'), findsOneWidget);
        expect(find.text('Use this device'), findsOneWidget);
        expect(find.text('Use cloud save'), findsOneWidget);
        expect(
          tester
              .widget<AbsorbPointer>(
                find.byKey(const Key('readiness-input-gate')),
              )
              .absorbing,
          isFalse,
        );
        await expectLater(
          find.byType(AppReadinessGate),
          matchesGoldenFile('goldens/whole_save_conflict.png'),
        );
      },
    );
  });
}

ProviderContainer _container({
  required _FakeWorkingSetStore store,
  required _FakeMapNotifier map,
  required _FakeItemsNotifier items,
  String environment = 'local',
}) => ProviderContainer(
  overrides: [
    clientWorkingSetStoreProvider.overrideWithValue(store),
    appReadinessEnvironmentProvider.overrideWithValue(environment),
    mapProvider.overrideWith(() => map),
    itemsProvider.overrideWith(() => items),
    appObservabilityProvider.overrideWithValue(
      ObservabilityService(sessionId: 'readiness-test'),
    ),
  ],
);

void _readyMapSurface(ProviderContainer container) {
  final readiness = container.read(mapReadinessProvider.notifier)..start();
  readiness.reportLocationReady(true);
  readiness.reportMapCreated();
  readiness.reportStyleLoaded();
  readiness.reportCellsFetched(true);
  readiness.reportBaseMapSettled(source: 'test');
  readiness.reportOverlayFramePainted();
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

ClientWorkingSet _snapshot({String environment = 'local'}) => ClientWorkingSet(
  environment: environment,
  userId: 'user-1',
  capturedAt: DateTime.utc(2026, 8, 18),
  map: MapStateReady(
    cells: const [],
    visitedCellIds: const {},
    location: LocationState(
      lat: 1,
      lng: 2,
      accuracy: 3,
      timestamp: DateTime.utc(2026, 8, 18),
      isConfident: true,
    ),
  ),
  items: const [],
);

class _FakeWorkingSetStore extends ClientWorkingSetStore {
  _FakeWorkingSetStore(
    super.preferences, {
    this.snapshot,
    this.throwOnPurge = false,
  });

  final ClientWorkingSet? snapshot;
  final bool throwOnPurge;
  int loadCalls = 0;
  int saved = 0;
  final List<String> purged = [];

  @override
  Future<ClientWorkingSet?> load({
    required String environment,
    required String userId,
  }) async {
    loadCalls++;
    return snapshot;
  }

  @override
  Future<bool> save(ClientWorkingSet workingSet) async {
    saved++;
    return true;
  }

  @override
  Future<void> purge({
    required String environment,
    required String userId,
  }) async {
    if (throwOnPurge) throw StateError('storage unavailable');
    purged.add(userId);
  }
}

class _FakeMapNotifier extends MapNotifier {
  _FakeMapNotifier({
    this.initial = const MapStateLoading(),
    required Future<bool> refresh,
  }) : _refreshResult = refresh;

  final MapState initial;
  final Future<bool> _refreshResult;
  int hydrateCalls = 0;

  @override
  MapState build() => initial;

  @override
  void hydrate(MapStateReady ready) {
    hydrateCalls++;
    state = ready;
  }

  @override
  Future<bool> refresh() => _refreshResult;
}

class _FakeItemsNotifier extends ItemsNotifier {
  int hydrateCalls = 0;

  @override
  ItemsState build() => const ItemsState();

  @override
  void hydrate(List<Item> items) {
    hydrateCalls++;
    state = const ItemsState(hasLoaded: true);
  }

  @override
  Future<void> fetchItems() async {}
}

class _StaticReadinessNotifier extends AppReadinessNotifier {
  _StaticReadinessNotifier(this.initial, {this.onPurge});

  final AppReadinessState initial;
  final VoidCallback? onPurge;
  int retryCalls = 0;

  @override
  AppReadinessState build() => initial;

  @override
  Future<void> start(String userId) async {}

  @override
  Future<bool> purge(String userId) async {
    onPurge?.call();
    return true;
  }

  @override
  Future<void> retry() async {
    retryCalls++;
  }
}

class _StaticAuthNotifier extends AuthNotifier {
  _StaticAuthNotifier(this.events);

  final List<String> events;

  @override
  AuthState build() => const AuthState.loading();

  @override
  Future<void> signOut() async {
    events.add('sign_out');
  }
}

SembastLocalSaveStore _memoryStore() => SembastLocalSaveStore(
  databaseFactoryMemory.openDatabase(
    'readiness-${DateTime.now().microsecondsSinceEpoch}',
  ),
);
