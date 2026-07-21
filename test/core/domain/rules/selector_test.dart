import 'package:earth_nova/core/domain/rules/condition.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Context {
  const _Context(this.permits);

  final bool permits;
}

final class _PermitsCondition extends Condition<_Context> {
  const _PermitsCondition();

  @override
  bool evaluate(_Context context) => context.permits;
}

void main() {
  const permitted = _Context(true);
  const blocked = _Context(false);

  group('Selector structure', () {
    test('requires a non-empty unique set of stable candidate IDs', () {
      expect(
        () => Selector<String, _Context>(candidates: const []),
        throwsArgumentError,
      );
      expect(
        () => Selector<String, _Context>(
          candidates: [
            SelectorCandidate.value(id: 'same', value: 'one', weight: 1),
            SelectorCandidate.value(id: 'same', value: 'two', weight: 1),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SelectorCandidate<String, _Context>.value(
          id: '  ',
          value: 'value',
          weight: 1,
        ),
        throwsArgumentError,
      );
    });

    test('defensively makes candidate collections immutable', () {
      final source = <SelectorCandidate<String, _Context>>[
        SelectorCandidate.value(id: 'one', value: 'one', weight: 1),
      ];
      final selector = Selector<String, _Context>(candidates: source);
      source.add(
        SelectorCandidate.value(id: 'two', value: 'two', weight: 1),
      );

      expect(selector.candidates, hasLength(1));
      expect(
        () => selector.candidates.add(
          SelectorCandidate.value(id: 'three', value: 'three', weight: 1),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('Selector weights', () {
    test('requires positive finite relative weights', () {
      expect(
        () => SelectorCandidate<String, _Context>.value(
          id: 'zero',
          value: 'zero',
          weight: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => SelectorCandidate<String, _Context>.value(
          id: 'negative',
          value: 'negative',
          weight: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SelectorCandidate<String, _Context>.value(
          id: 'infinite',
          value: 'infinite',
          weight: double.infinity,
        ),
        throwsArgumentError,
      );
      expect(
        () => SelectorCandidate<String, _Context>.value(
          id: 'nan',
          value: 'nan',
          weight: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Selector resolution', () {
    test('filters conditions before calculating weighted selection', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.value(
            id: 'excluded',
            value: 'excluded',
            weight: 100,
            condition: _PermitsCondition(),
          ),
          SelectorCandidate.value(id: 'low', value: 'low', weight: 1),
          SelectorCandidate.value(id: 'high', value: 'high', weight: 3),
        ],
      );

      expect(
        selector.resolve(blocked, () => 0.5),
        const SelectedValue<String>('high'),
      );
    });

    test('uses the injected normalized roll at deterministic boundaries', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.value(id: 'first', value: 'first', weight: 1),
          SelectorCandidate.value(id: 'second', value: 'second', weight: 3),
        ],
      );

      expect(
        selector.resolve(permitted, () => 0),
        const SelectedValue<String>('first'),
      );
      expect(
        selector.resolve(permitted, () => 0.25),
        const SelectedValue<String>('second'),
      );
      expect(
        selector.resolve(permitted, () => 0.999999),
        const SelectedValue<String>('second'),
      );
    });

    test(
        'selects the final candidate when floating-point subtraction leaves a zero residual',
        () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.value(
            id: 'first',
            value: 'first',
            weight: 6.07921287862e-15,
          ),
          SelectorCandidate.value(
            id: 'second',
            value: 'second',
            weight: 4.20062197344e-11,
          ),
          SelectorCandidate.value(id: 'last', value: 'last', weight: 1),
        ],
      );

      expect(
        selector.resolve(permitted, () => 0.9999999999999999),
        const SelectedValue<String>('last'),
      );
    });

    test('rejects rolls outside the normalized half-open interval', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.value(id: 'value', value: 'value', weight: 1),
        ],
      );

      expect(
        () => selector.resolve(permitted, () => -0.00001),
        throwsArgumentError,
      );
      expect(
        () => selector.resolve(permitted, () => 1),
        throwsArgumentError,
      );
    });

    test('returns an explicit None outcome when its candidate is selected', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.none(id: 'none', weight: 2),
          SelectorCandidate.value(id: 'value', value: 'value', weight: 1),
        ],
      );

      expect(selector.resolve(permitted, () => 0), isA<SelectedNone<String>>());
    });

    test('resolves the selected candidate without discarding its identity', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.none(id: 'candidate:none', weight: 1),
          SelectorCandidate.value(
            id: 'candidate:value',
            value: 'selected',
            weight: 1,
          ),
        ],
      );

      final candidate = selector.resolveCandidate(permitted, () => 0.75);

      expect(candidate.id, 'candidate:value');
      expect(candidate.result, const SelectedValue<String>('selected'));
    });

    test('fails without reading a roll when no candidates are eligible', () {
      final selector = Selector<String, _Context>(
        candidates: [
          SelectorCandidate.value(
            id: 'blocked',
            value: 'blocked',
            weight: 1,
            condition: _PermitsCondition(),
          ),
        ],
      );
      var rollWasRequested = false;

      expect(
        () => selector.resolve(blocked, () {
          rollWasRequested = true;
          return 0;
        }),
        throwsStateError,
      );
      expect(rollWasRequested, isFalse);
    });
  });
}
