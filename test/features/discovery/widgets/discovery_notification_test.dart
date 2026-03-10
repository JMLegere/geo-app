import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/discovery/widgets/discovery_notification.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiscoveryEvent _makeEvent({
  String displayName = 'Red Fox',
  String scientificName = 'Vulpes vulpes',
  IucnStatus rarity = IucnStatus.leastConcern,
  bool isNew = true,
}) {
  return DiscoveryEvent(
    item: FaunaDefinition(
      id: 'fauna_${scientificName.toLowerCase().replaceAll(' ', '_')}',
      displayName: displayName,
      scientificName: scientificName,
      taxonomicClass: 'Mammalia',
      continents: [Continent.northAmerica],
      habitats: [Habitat.forest],
      rarity: rarity,
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
          .showDiscovery(_makeEvent(displayName: 'Red Fox'));
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
            _makeEvent(rarity: IucnStatus.leastConcern),
          );
      await tester.pump();

      expect(find.text('LC'), findsOneWidget);
    });

    testWidgets('shows rarity badge label for CR status', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(rarity: IucnStatus.criticallyEndangered),
          );
      await tester.pump();

      expect(find.text('CR'), findsOneWidget);
    });

    testWidgets('shows rarity badge label for EN status', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(rarity: IucnStatus.endangered),
          );
      await tester.pump();

      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('shows correct rarity badge color for LC (white)',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(rarity: IucnStatus.leastConcern),
          );
      await tester.pump();

      // Find the rarity badge Container by looking for white color decoration.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final badgeContainer = containers.firstWhere(
        (c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == const Color(0xFFFFFFFF);
          }
          return false;
        },
        orElse: () => throw StateError('No white LC badge found'),
      );
      expect(badgeContainer, isNotNull);
    });

    testWidgets('shows correct rarity badge color for EX (amber)',
        (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(
            _makeEvent(rarity: IucnStatus.extinct),
          );
      await tester.pump();

      final containers = tester.widgetList<Container>(find.byType(Container));
      final badgeContainer = containers.firstWhere(
        (c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == const Color(0xFFFFC107);
          }
          return false;
        },
        orElse: () => throw StateError('No amber EX badge found'),
      );
      expect(badgeContainer, isNotNull);
    });

    testWidgets('auto-dismisses after 3 seconds', (tester) async {
      final container = await _pumpOverlay(tester);

      container.read(discoveryProvider.notifier).showDiscovery(_makeEvent());
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
          .showDiscovery(_makeEvent(displayName: 'Red Fox'));
      await tester.pump();
      expect(find.text('Red Fox'), findsOneWidget);

      container.read(discoveryProvider.notifier).dismissNotification();
      // Allow the reverse animation to complete.
      await tester.pumpAndSettle();

      expect(find.text('Red Fox'), findsNothing);
    });

    testWidgets('stacks multiple notifications visually', (tester) async {
      final container = await _pumpOverlay(tester);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(
          _makeEvent(displayName: 'Red Fox', scientificName: 'Vulpes vulpes'));
      notifier.showDiscovery(
          _makeEvent(displayName: 'Gray Wolf', scientificName: 'Canis lupus'));
      notifier.showDiscovery(_makeEvent(
          displayName: 'Brown Bear', scientificName: 'Ursus arctos'));
      await tester.pump();

      // All three species names should be rendered in the stack.
      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Gray Wolf'), findsOneWidget);
      expect(find.text('Brown Bear'), findsOneWidget);
    });

    testWidgets('dismissing top card shows next card', (tester) async {
      final container = await _pumpOverlay(tester);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(
          _makeEvent(displayName: 'Red Fox', scientificName: 'Vulpes vulpes'));
      notifier.showDiscovery(
          _makeEvent(displayName: 'Gray Wolf', scientificName: 'Canis lupus'));
      await tester.pump();

      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Gray Wolf'), findsOneWidget);

      // Dismiss the top card (Red Fox).
      notifier.dismissNotification();
      await tester.pump();

      expect(find.text('Red Fox'), findsNothing);
      expect(find.text('Gray Wolf'), findsOneWidget);
    });

    testWidgets('auto-dismiss cycles through queued notifications',
        (tester) async {
      final container = await _pumpOverlay(tester);

      final notifier = container.read(discoveryProvider.notifier);
      notifier.showDiscovery(
          _makeEvent(displayName: 'Red Fox', scientificName: 'Vulpes vulpes'));
      notifier.showDiscovery(
          _makeEvent(displayName: 'Gray Wolf', scientificName: 'Canis lupus'));
      await tester.pump();

      // First auto-dismiss after 3s removes Red Fox.
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      expect(
        container.read(discoveryProvider).currentNotification?.item.displayName,
        equals('Gray Wolf'),
      );

      // Second auto-dismiss after another 3s removes Gray Wolf.
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      expect(
        container.read(discoveryProvider).hasActiveNotification,
        isFalse,
      );
    });
  });
}
