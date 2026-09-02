import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

const _shellAssets = <String>[
  'shell/map-selected-390x844.png',
  'shell/map-selected-1440x900.png',
  'shell/pack-selected-390x844.png',
  'shell/pack-selected-1440x900.png',
  'shell/keyboard-focus-390x844.png',
  'shell/keyboard-focus-1440x900.png',
];

void main() {
  group('Phase seven shell fixtures', () {
    test('declares the final six shell assets', () {
      expect(_shellAssets, hasLength(6));
      expect(_shellAssets.toSet(), hasLength(6));
      expect(_shellAssets, everyElement(startsWith('shell/')));
    });

    for (final viewport in const [
      (size: phaseSevenMobileSize, suffix: '390x844'),
      (size: phaseSevenDesktopSize, suffix: '1440x900'),
    ]) {
      testWidgets(
        'captures shell/map-selected-${viewport.suffix}.png',
        (tester) => _captureShell(
          tester,
          size: viewport.size,
          name: 'shell/map-selected-${viewport.suffix}.png',
          prepare: (tester) async {
            expect(
              find.byKey(const Key('tab-shell-nav-selected-map')),
              findsOneWidget,
            );
          },
        ),
        skip: !phaseSevenCaptureEnabled,
      );

      testWidgets(
        'captures shell/pack-selected-${viewport.suffix}.png',
        (tester) => _captureShell(
          tester,
          size: viewport.size,
          name: 'shell/pack-selected-${viewport.suffix}.png',
          prepare: (tester) async {
            await tester.tap(find.byKey(const Key('tab-shell-nav-item-pack')));
            await tester.pump();
            expect(
              find.byKey(const Key('tab-shell-nav-selected-pack')),
              findsOneWidget,
            );
          },
        ),
        skip: !phaseSevenCaptureEnabled,
      );

      testWidgets(
        'captures shell/keyboard-focus-${viewport.suffix}.png',
        (tester) => _captureShell(
          tester,
          size: viewport.size,
          name: 'shell/keyboard-focus-${viewport.suffix}.png',
          prepare: _focusShellNavigation,
        ),
        skip: !phaseSevenCaptureEnabled,
      );
    }
  });
}

Future<void> _captureShell(
  WidgetTester tester, {
  required Size size,
  required String name,
  Future<void> Function(WidgetTester tester)? prepare,
}) {
  return capturePhaseSevenFixture(
    tester,
    size: size,
    name: name,
    child: _shell(),
    prepare: (tester) async {
      expect(find.byType(TabShell), findsOneWidget);
      expect(
        find.byKey(const Key('tab-shell-bottom-navigation')),
        findsOneWidget,
      );
      await prepare?.call(tester);
    },
  );
}

Widget _shell() {
  final observability = ObservabilityService(sessionId: 'phase-seven-shell');
  return ProviderScope(
    overrides: [
      wakeLockRepositoryProvider.overrideWithValue(_FakeWakeLockRepository()),
      wakeLockObservabilityProvider.overrideWithValue(observability),
      appObservabilityProvider.overrideWithValue(observability),
      navigationScreenTransitionLoggerProvider.overrideWithValue(
        NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
      ),
      debugModeProvider.overrideWith(_FalseDebugMode.new),
      locationProvider.overrideWith(_LoadingLocationNotifier.new),
      authProvider.overrideWith(_LoadingAuthNotifier.new),
      livingWorldRepositoryProvider.overrideWithValue(
        _FakeLivingWorldRepository(),
      ),
      pendingEncounterProvider.overrideWith(_NoPendingEncounterNotifier.new),
      itemsProvider.overrideWith(_LoadedItemsNotifier.new),
    ],
    child: const TabShell(),
  );
}

Future<void> _focusShellNavigation(WidgetTester tester) async {
  final navButtons = [
    find.byKey(const Key('tab-shell-nav-button-map')),
    find.byKey(const Key('tab-shell-nav-button-pack')),
  ];

  for (var index = 0; index < navButtons.length; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_hasFocusedShellNavigation(tester, navButtons)) break;
  }

  expect(_hasFocusedShellNavigation(tester, navButtons), isTrue);
}

bool _hasFocusedShellNavigation(WidgetTester tester, List<Finder> navButtons) {
  final focusContext = tester.binding.focusManager.primaryFocus?.context;
  if (focusContext == null) return false;

  final navElements = navButtons.map(tester.element).toSet();
  var belongsToShellNavigation = navElements.contains(focusContext);
  focusContext.visitAncestorElements((element) {
    belongsToShellNavigation =
        belongsToShellNavigation || navElements.contains(element);
    return !belongsToShellNavigation;
  });
  return belongsToShellNavigation;
}

class _FakeWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

class _FalseDebugMode extends DebugModeNotifier {
  @override
  bool build() => false;
}

class _LoadingLocationNotifier extends LocationNotifier {
  @override
  LocationProviderState build() => const LocationProviderLoading();
}

class _LoadedItemsNotifier extends ItemsNotifier {
  @override
  ItemsState build() => const ItemsState(hasLoaded: true);

  @override
  Future<void> fetchItems() async {}
}

class _LoadingAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.loading();
}

class _NoPendingEncounterNotifier extends PendingEncounterNotifier {
  @override
  PendingEncounterState build() => const PendingEncounterNone();
}

class _FakeLivingWorldRepository implements LivingWorldRepository {
  @override
  Future<TownProjection> readTown(String playerId, {required String traceId}) =>
      Future.error(UnimplementedError());

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) => Future.error(UnimplementedError());
}
