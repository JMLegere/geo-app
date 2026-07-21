import 'package:earth_nova/core/domain/rules/condition.dart';
import 'package:flutter_test/flutter_test.dart';

final class _TestContext {
  const _TestContext({required this.isMember, required this.hasVisited});

  final bool isMember;
  final bool hasVisited;
}

final class _IsMemberCondition extends Condition<_TestContext> {
  const _IsMemberCondition();

  @override
  bool evaluate(_TestContext context) => context.isMember;
}

final class _HasVisitedCondition extends Condition<_TestContext> {
  const _HasVisitedCondition();

  @override
  bool evaluate(_TestContext context) => context.hasVisited;
}

void main() {
  const member = _TestContext(isMember: true, hasVisited: false);
  const visitor = _TestContext(isMember: false, hasVisited: true);

  group('Condition eligibility', () {
    test('treats an absent condition as eligible', () {
      expect(isEligible<_TestContext>(null, member), isTrue);
    });

    test('evaluates feature-owned typed leaves against their typed context',
        () {
      const condition = _IsMemberCondition();

      expect(condition.evaluate(member), isTrue);
      expect(condition.evaluate(visitor), isFalse);
    });
  });

  group('Condition composition', () {
    test('evaluates recursive All, Any, and Not conditions', () {
      final condition = AllCondition<_TestContext>([
        const _IsMemberCondition(),
        AnyCondition<_TestContext>([
          NotCondition<_TestContext>(const _HasVisitedCondition()),
          const _HasVisitedCondition(),
        ]),
      ]);

      expect(condition.evaluate(member), isTrue);
      expect(condition.evaluate(visitor), isFalse);
    });

    test('short-circuits All and Any evaluation', () {
      final all = AllCondition<_TestContext>([
        const _IsMemberCondition(),
        _ThrowsIfEvaluatedCondition(),
      ]);
      final any = AnyCondition<_TestContext>([
        const _IsMemberCondition(),
        _ThrowsIfEvaluatedCondition(),
      ]);

      expect(all.evaluate(visitor), isFalse);
      expect(any.evaluate(member), isTrue);
    });
  });

  group('Condition structure', () {
    test('rejects empty All and Any nodes', () {
      expect(
        () => AllCondition<_TestContext>(const []),
        throwsArgumentError,
      );
      expect(
        () => AnyCondition<_TestContext>(const []),
        throwsArgumentError,
      );
    });

    test('defensively makes child collections read-only', () {
      final source = <Condition<_TestContext>>[const _IsMemberCondition()];
      final condition = AllCondition<_TestContext>(source);
      source.add(const _HasVisitedCondition());

      expect(condition.conditions, hasLength(1));
      expect(
        () => condition.conditions.add(const _HasVisitedCondition()),
        throwsUnsupportedError,
      );
    });
  });
}

final class _ThrowsIfEvaluatedCondition extends Condition<_TestContext> {
  @override
  bool evaluate(_TestContext context) =>
      throw StateError('This condition should have been short-circuited.');
}
