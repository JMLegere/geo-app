import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'long filter labels wrap at larger text without losing touch targets',
    (tester) async {
      await tester.pumpWidget(
        ShadApp(
          theme: AppDesignTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 120,
                child: AppToggleChip(
                  label: 'Invertebrates',
                  selected: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ShadButton)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('filter count belongs to its control', (tester) async {
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: AppIconButton(
            label: 'Filters',
            icon: Icons.tune,
            badgeCount: 2,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      find.descendant(of: find.byType(AppIconButton), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('search edits and clear are immediate controlled changes', (
    tester,
  ) async {
    var query = '';
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => AppSearchField(
              query: query,
              hint: 'Search Pack...',
              onChanged: (value) => update(() => query = value),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Mint');
    await tester.pump();
    expect(query, 'Mint');
    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();
    expect(query, '');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
    );
  });

  testWidgets(
    'choice menu applies one selection and closes without submission',
    (tester) async {
      var selection = 0;
      await tester.pumpWidget(
        ShadApp(
          theme: AppDesignTheme.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => AppChoiceMenu<int>(
                label: 'Sort',
                value: selection,
                choices: const [
                  AppChoice(value: 0, label: 'Recent'),
                  AppChoice(value: 1, label: 'Name'),
                ],
                onChanged: (value) => update(() => selection = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(selection, 1);
      expect(find.text('Recent'), findsNothing);
    },
  );
}
