import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ObservableInteractionTrace start(
    ObservabilityService observability,
    String action,
  ) => ObservableInteractionTrace.start(
    observability: observability,
    interaction: action,
    surface: 'test.surface',
    readinessState: 'usable',
    screenName: 'test_screen',
    widgetName: 'test_surface',
    actionType: action,
  );

  test('uses one root span and stops at the first transition', () {
    final observability = ObservabilityService(sessionId: 'interaction-test');
    final interaction = start(observability, PlayerActions.openPack);

    interaction.complete(transition: 'pack_visible');
    interaction.complete(transition: 'later_transition');

    expect(observability.pendingSpanRecords, hasLength(1));
    final span = observability.pendingSpanRecords.single;
    expect(span['parent_span_id'], isNull);
    expect(
      (span['attributes'] as Map<String, dynamic>)['transition'],
      'pack_visible',
    );
    expect(
      observability.pendingLogRecords.where(
        (record) => record['event_name'] == 'interaction.transition',
      ),
      hasLength(1),
    );
  });

  test('propagates the interaction root to operation children', () {
    final observability = ObservabilityService(sessionId: 'interaction-test');
    final interaction = start(observability, PlayerActions.examinePackItem);
    final operation = observability.startSpan(
      'operation.examine_pack_item',
      parent: interaction.context,
    );

    observability.endSpan(operation, statusCode: TelemetrySpanStatus.ok);
    interaction.complete(transition: 'item_examined');

    final operationSpan = observability.pendingSpanRecords.first;
    expect(operationSpan['trace_id'], interaction.context.traceId);
    expect(operationSpan['parent_span_id'], interaction.context.spanId);
  });

  test('emits only low-cardinality interaction completion attributes', () {
    final observability = ObservabilityService(
      sessionId: 'interaction-test',
      serviceVersion: '1.2.3',
      deploymentEnvironment: 'test',
      platform: 'web',
    );
    final interaction = start(observability, PlayerActions.inspectMapCell);

    interaction.complete(transition: 'cell_sheet_visible');

    final attributes =
        observability.pendingSpanRecords.single['attributes']
            as Map<String, dynamic>;
    expect(
      attributes,
      containsPair('interaction', PlayerActions.inspectMapCell),
    );
    expect(attributes, containsPair('surface', 'test.surface'));
    expect(attributes, containsPair('transition', 'cell_sheet_visible'));
    expect(attributes, containsPair('readiness_state', 'usable'));
    expect(attributes, containsPair('platform', 'web'));
    expect(attributes, containsPair('app_version', '1.2.3'));
    expect(attributes, containsPair('deployment_environment', 'test'));
    expect(attributes['latency_ms'], isA<int>());
    expect(attributes, containsPair('outcome', 'success'));
  });

  test('supports every currently wired named primary interaction', () {
    final observability = ObservabilityService(sessionId: 'interaction-test');
    const actions = [
      PlayerActions.openMap,
      PlayerActions.inspectMapCell,
      PlayerActions.openPack,
      PlayerActions.inspectPackFind,
      PlayerActions.examinePackItem,
      PlayerActions.resolvePresentEncounter,
    ];

    for (final action in actions) {
      start(observability, action).complete(transition: 'local_state_visible');
    }

    expect(observability.pendingSpanRecords, hasLength(actions.length));
  });
}
