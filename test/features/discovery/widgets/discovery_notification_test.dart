import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/discovery/widgets/discovery_notification.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiscoveryEvent _makeEvent({
  String commonName = 'Red Fox',
  String scientificName = 'Vulpes vulpes',
  IucnStatus iucnStatus = IucnStatus.leastConcern,
  bool isNew = true,
}) {
  return DiscoveryEvent(
    species: SpeciesRecord(
      commonName: commonName,
      scientificName: scientificName,
      taxonomicClass: 'Mammalia',
      continents: [Continent.northAmerica],
      habitats: [Habitat.forest],
      iucnStatus: iucnStatus,
    ),
    cellId: 'cell_1',
    isNew: isNew,
    timestamp: DateTime(2026, 3, 2),
  );
}

/// Pumps the overlay inside a proper provider scope + material app so
/// BackdropFilter and animations have a valid render tree.
Future<ProviderContainer> _pumpOverlay(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DiscoveryNotificationOverlay(),
        ),
      ),
    ),
  );

  return container;
}

void main() {
  group('DiscoveryNotificationOverlay', () {
    testWidgets('renders without error when no active notification',
        (tester) async {
      final container = await _pumpOverlay(tester);
      expect(
        container.read(discoveryProvider).hasActiveNotification,
        isFalse,
      );
      expect(find.byType(DiscoveryNotificationOverlay), findsOneWidget);
    });

    testWidgets('shows species common name when notification is active',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent(commonName: 'Red Fox'));
      await tester.pump();

      expect(find.text('Red Fox'), findsOneWidget);
    });

    testWidgets('shows species scientific name', (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent(scientificName: 'Vulpes vulpes'));
      await tester.pump();

      expect(find.text('Vulpes vulpes'), findsOneWidget);
    });

    testWidgets('shows "NEW!" text for a new discovery', (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent(isNew: true));
      await tester.pump();

      expect(find.text('NEW!'), findsOneWidget);
    });

    testWidgets('shows "Already collected" text for a duplicate discovery',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent(isNew: false));
      await tester.pump();

      expect(find.text('Already collected'), findsOneWidget);
    });

    testWidgets('shows rarity badge label for LC status', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(iucnStatus: IucnStatus.leastConcern),
          );
      await tester.pump();

      expect(find.text('LC'), findsOneWidget);
    });

    testWidgets('shows rarity badge label for CR status', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(iucnStatus: IucnStatus.criticallyEndangered),
          );
      await tester.pump();

      expect(find.text('CR'), findsOneWidget);
    });

    testWidgets('shows rarity badge label for EN status', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(iucnStatus: IucnStatus.endangered),
          );
      await tester.pump();

      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('shows correct rarity badge color for LC (green)',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(iucnStatus: IucnStatus.leastConcern),
          );
      await tester.pump();

      // Find the rarity badge Container by looking for green color decoration.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final badgeContainer = containers.firstWhere(
        (c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == const Color(0xFF4CAF50);
          }
          return false;
        },
        orElse: () => throw StateError('No green LC badge found'),
      );
      expect(badgeContainer, isNotNull);
    });

    testWidgets('shows correct rarity badge color for EX (black)',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(iucnStatus: IucnStatus.extinct),
          );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final badgeContainer = containers.firstWhere(
        (c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == const Color(0xFF000000);
          }
          return false;
        },
        orElse: () => throw StateError('No black EX badge found'),
      );
      expect(badgeContainer, isNotNull);
    });

    testWidgets('auto-dismisses after 3 seconds', (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent());
      // Pump once to process the state change and trigger the timer.
      await tester.pump();

      // Advance past the auto-dismiss threshold.
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));

      expect(
        container.read(discoveryProvider).hasActiveNotification,
        isFalse,
        reason: 'Notification should be auto-dismissed after 3 s',
      );
    });

    testWidgets('notification disappears when dismissed manually',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container
          .read(discoveryProvider.notifier)
          .showDiscovery(_makeEvent(commonName: 'Red Fox'));
      await tester.pump();
      expect(find.text('Red Fox'), findsOneWidget);

      container.read(discoveryProvider.notifier).dismissNotification();
      // Allow the reverse animation to complete.
      await tester.pumpAndSettle();

      expect(find.text('Red Fox'), findsNothing);
    });
  });
}
