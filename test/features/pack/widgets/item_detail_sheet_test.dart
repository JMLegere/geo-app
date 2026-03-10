import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/features/pack/widgets/item_detail_sheet.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ItemInstance _makeInstance({
  Map<String, dynamic> affixValues = const {},
}) {
  return ItemInstance(
    id: 'inst-1',
    definitionId: 'fauna_vulpes_vulpes',
    displayName: 'Red Fox',
    category: ItemCategory.fauna,
    affixes: [
      Affix(
        id: 'base_stats',
        type: AffixType.intrinsic,
        values: {
          'brawn': 30,
          'wit': 35,
          'speed': 25,
          ...affixValues,
        },
      ),
    ],
    acquiredAt: DateTime(2026, 3, 1),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ItemDetailSheet size and weight', () {
    testWidgets('shows Size row when intrinsic has size', (tester) async {
      final item = _makeInstance(affixValues: {
        kSizeAffixKey: 'small',
      });
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.text('Size'), findsOneWidget);
      expect(find.textContaining('Small'), findsOneWidget);
    });

    testWidgets('shows Weight row when intrinsic has weightGrams',
        (tester) async {
      final item = _makeInstance(affixValues: {
        kSizeAffixKey: 'medium',
        kWeightAffixKey: 87500,
      });
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.text('Weight'), findsOneWidget);
      expect(find.textContaining('87.5 kg'), findsOneWidget);
    });

    testWidgets('hides Size and Weight when intrinsic has neither',
        (tester) async {
      final item = _makeInstance(); // no size/weight keys
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.text('Size'), findsNothing);
      expect(find.text('Weight'), findsNothing);
    });

    testWidgets('formats sub-kilogram weight in grams', (tester) async {
      final item = _makeInstance(affixValues: {
        kSizeAffixKey: 'fine',
        kWeightAffixKey: 42,
      });
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.textContaining('42 g'), findsOneWidget);
    });

    testWidgets('formats tonnage weight in metric tonnes', (tester) async {
      final item = _makeInstance(affixValues: {
        kSizeAffixKey: 'colossal',
        kWeightAffixKey: 150000000, // 150 t
      });
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.textContaining('150 t'), findsOneWidget);
    });

    testWidgets('shows Size without Weight when only size present',
        (tester) async {
      final item = _makeInstance(affixValues: {
        kSizeAffixKey: 'large',
        // no kWeightAffixKey
      });
      await tester.pumpWidget(_wrap(ItemDetailSheet(item: item)));

      expect(find.text('Size'), findsOneWidget);
      expect(find.textContaining('Large'), findsOneWidget);
      expect(find.text('Weight'), findsNothing);
    });
  });
}
