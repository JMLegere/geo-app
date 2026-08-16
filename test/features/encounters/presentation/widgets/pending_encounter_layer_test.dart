import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/encounters/presentation/widgets/pending_encounter_layer.dart';

void main() {
  group('PendingEncounterLayer', () {
    for (final state in <PendingEncounterState>[
      const PendingEncounterNone(),
      const PendingEncounterLoading(),
      const PendingEncounterFailure(),
    ]) {
      testWidgets('renders nothing for $state', (tester) async {
        await _pump(tester, state);

        expect(find.byType(PendingEncounterLayer), findsOneWidget);
        expect(
            find.bySemanticsLabel(RegExp('Pending encounter')), findsNothing);
        expect(find.byType(Card), findsNothing);
        expect(find.byType(Text), findsNothing);
      });
    }

    testWidgets('renders ready encounter as a noninteractive semantic card',
        (tester) async {
      await _pump(tester, PendingEncounterReady(_pendingEncounter()));

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Observe quietly'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Pending encounter: Red Fox. Option: Observe quietly.',
          ),
        ),
        matchesSemantics(
          label: 'Pending encounter: Red Fox. Option: Observe quietly.',
          isButton: false,
          hasTapAction: false,
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}

Future<void> _pump(WidgetTester tester, PendingEncounterState state) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        pendingEncounterProvider.overrideWith(
          () => _TestPendingEncounterNotifier(state),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: PendingEncounterLayer()),
      ),
    ),
  );
}

final class _TestPendingEncounterNotifier extends PendingEncounterNotifier {
  _TestPendingEncounterNotifier(this.value);

  final PendingEncounterState value;

  @override
  PendingEncounterState build() => value;
}

PendingEncounter _pendingEncounter() {
  return PendingEncounter(
    cellId: 'cell-red-fox',
    encounter: EncounterOccurrence(
      id: EncounterId('encounter-red-fox'),
      cellVisitId: CellVisitId('visit-red-fox'),
      cellVisitResolutionId: CellVisitResolutionId('resolution-red-fox'),
      definitionVersion: ExactVersionRef<EncounterContent>(
        stableId: StableContentId<EncounterContent>('encounter:red_fox'),
        versionId: ContentVersionId<EncounterContent>('red-fox-r2'),
        revision: 2,
      ),
      status: EncounterResolutionStatus.pending,
      createdAt: DateTime.utc(2026, 8, 16),
    ),
    definitionDisplayName: 'Red Fox',
    options: [
      PendingEncounterOption(
        id: EncounterOptionId('observe-quietly'),
        ordinal: 0,
        displayName: 'Observe quietly',
      ),
    ],
  );
}
