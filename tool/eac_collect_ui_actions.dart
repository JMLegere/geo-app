import 'dart:convert';
import 'dart:io';

// EarthNova collector: scans app Flutter/Dart source for action-bearing design
// controls. A resolved action ID maps the control to a product action.
// `actionId: null` is an explicit non-product-action decision.

void main() {
  final playerActions = _loadPlayerActions();
  final controls = <Map<String, String>>[];

  for (final file
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    if (file.path.startsWith('lib/shared/design/')) continue;
    if (file.path == 'lib/shared/product/product_action_surface.dart') continue;

    final source = file.readAsStringSync();
    controls.addAll(
      _collectWidgetActionEvidence(
        source: source,
        sourcePath: file.path,
        component: 'EarthActionButton',
        role: 'button',
        playerActions: playerActions,
      ),
    );
    controls.addAll(
      _collectWidgetActionEvidence(
        source: source,
        sourcePath: file.path,
        component: 'ProductActionSurface',
        role: 'button',
        playerActions: playerActions,
      ),
    );
    controls.addAll(
      _collectLoggedPlayerActionEvidence(
        source: source,
        sourcePath: file.path,
        playerActions: playerActions,
      ),
    );
  }

  final output = File('artifacts/eac/ui-actions.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'controls': controls
      })}\n');
}

List<Map<String, String>> _collectWidgetActionEvidence({
  required String source,
  required String sourcePath,
  required String component,
  required String role,
  required Map<String, String> playerActions,
}) {
  final rows = <Map<String, String>>[];
  final matches = RegExp(
    '$component\\s*\\([\\s\\S]*?actionId:\\s*([^,\\n)]+)',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    final actionId = _resolveActionId(match.group(1)!, playerActions);
    if (actionId == null) continue;
    rows.add({
      'component': component,
      'actionId': actionId,
      'source': sourcePath,
      'role': role,
    });
  }

  return rows;
}

List<Map<String, String>> _collectLoggedPlayerActionEvidence({
  required String source,
  required String sourcePath,
  required Map<String, String> playerActions,
}) {
  final rows = <Map<String, String>>[];
  final matches = RegExp(
    r'''playerActionId:\s*PlayerActions\.([A-Za-z0-9_]+)''',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    final actionId = playerActions[match.group(1)];
    if (actionId == null) continue;
    rows.add({
      'component': 'ProductActionSurface',
      'actionId': actionId,
      'source': sourcePath,
      'role': 'button',
    });
  }

  return rows;
}

String? _resolveActionId(String expression, Map<String, String> playerActions) {
  final normalized = expression.trim();
  if (normalized == 'null') return null;

  final literal = RegExp(r'''^['\"]([^'\"]+)['\"]$''').firstMatch(normalized);
  if (literal != null) return literal.group(1);

  final playerAction =
      RegExp(r'^PlayerActions\.([A-Za-z0-9_]+)$').firstMatch(normalized);
  if (playerAction != null) {
    return playerActions[playerAction.group(1)];
  }

  return null;
}

Map<String, String> _loadPlayerActions() {
  final source =
      File('lib/shared/product/player_actions.dart').readAsStringSync();
  final actions = <String, String>{};
  final matches = RegExp(
    r'''static const PlayerActionId\s+([A-Za-z0-9_]+)\s*=\s*['\"]([^'\"]+)['\"]''',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    actions[match.group(1)!] = match.group(2)!;
  }

  return actions;
}
