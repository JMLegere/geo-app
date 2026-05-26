import 'dart:convert';
import 'dart:io';

// EarthNova collector: scans app Flutter/Dart source for action-bearing design
// controls. A resolved action ID maps the control to a product action.
// `actionId: null` is an explicit non-product-action decision.

const _surfaceDesignEntityNames = <String, String>{
  'TabShell': 'PrimaryNavigationShell',
  'MapRootScreen': 'ExplorationMapRoot',
  'MapScreen': 'ExplorationMap',
  'PackScreen': 'PlayerPack',
  'TownScreen': 'TownDirectory',
  'NpcVenueDetailScreen': 'VenueDetail',
  'SettingsScreen': 'PlayerSettings',
  'HierarchyHeader': 'TerritoryHierarchyHeader',
  'CellDetailSheet': 'MapCellDetailSheet',
};

void main() {
  final playerActions = _loadPlayerActions();
  final rows = <_UiActionEvidence>[];

  for (final file
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    if (file.path.startsWith('lib/shared/design/')) continue;
    if (file.path == 'lib/shared/product/product_action_surface.dart') continue;

    final source = file.readAsStringSync();
    final surface = _surfaceNameFor(source: source, sourcePath: file.path);
    final designEntity = _designEntityForSurface(surface);
    rows.addAll(
      _collectWidgetActionEvidence(
        source: source,
        sourcePath: file.path,
        surface: surface,
        designEntity: 'EarthActionButton',
        controlComponent: 'EarthActionButton',
        role: 'button',
        evidenceType: 'explicit-design-control',
        playerActions: playerActions,
      ),
    );
    rows.addAll(
      _collectWidgetActionEvidence(
        source: source,
        sourcePath: file.path,
        surface: surface,
        designEntity: designEntity,
        controlComponent: 'ProductActionSurface',
        role: 'button',
        evidenceType: 'explicit-action-surface',
        playerActions: playerActions,
      ),
    );
    rows.addAll(
      _collectLoggedPlayerActionEvidence(
        source: source,
        sourcePath: file.path,
        surface: surface,
        designEntity: designEntity,
        playerActions: playerActions,
      ),
    );
    rows.addAll(
      _collectStaticNavigationDestinationEvidence(
        source: source,
        sourcePath: file.path,
        surface: surface,
        designEntity: designEntity,
        playerActions: playerActions,
      ),
    );
  }

  final controls =
      _dedupe(rows).map((row) => row.toJson()).toList(growable: false);

  final output = File('artifacts/eac/ui-actions.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'collector': 'earthnova-flutter-dart-static',
        'controls': controls,
      })}\n');
}

List<_UiActionEvidence> _collectWidgetActionEvidence({
  required String source,
  required String sourcePath,
  required String surface,
  required String designEntity,
  required String controlComponent,
  required String role,
  required String evidenceType,
  required Map<String, String> playerActions,
}) {
  final rows = <_UiActionEvidence>[];
  final matches = RegExp(
    '$controlComponent\\s*\\([\\s\\S]*?actionId:\\s*([^,\\n)]+)',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    final actionId = _resolveActionId(match.group(1)!, playerActions);
    if (actionId == null) continue;
    rows.add(_UiActionEvidence(
      component: designEntity,
      controlComponent: controlComponent,
      actionId: actionId,
      source: sourcePath,
      surface: surface,
      role: role,
      evidenceType: evidenceType,
      line: _lineForOffset(source, match.start),
    ));
  }

  return rows;
}

List<_UiActionEvidence> _collectLoggedPlayerActionEvidence({
  required String source,
  required String sourcePath,
  required String surface,
  required String designEntity,
  required Map<String, String> playerActions,
}) {
  final rows = <_UiActionEvidence>[];
  final matches = RegExp(
    r'''playerActionId:\s*PlayerActions\.([A-Za-z0-9_]+)''',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    final actionId = playerActions[match.group(1)];
    if (actionId == null) continue;
    rows.add(_UiActionEvidence(
      component: designEntity,
      controlComponent: 'ObservableInteraction',
      actionId: actionId,
      source: sourcePath,
      surface: surface,
      role: 'button',
      evidenceType: 'observable-player-action',
      line: _lineForOffset(source, match.start),
    ));
  }

  return rows;
}

List<_UiActionEvidence> _collectStaticNavigationDestinationEvidence({
  required String source,
  required String sourcePath,
  required String surface,
  required String designEntity,
  required Map<String, String> playerActions,
}) {
  if (!sourcePath.endsWith('tab_shell.dart')) return const [];

  final rows = <_UiActionEvidence>[];
  final matches = RegExp(
    r'''_BottomNavDestination\s*\([\s\S]*?actionId:\s*PlayerActions\.([A-Za-z0-9_]+)''',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    final actionId = playerActions[match.group(1)];
    if (actionId == null) continue;
    rows.add(_UiActionEvidence(
      component: designEntity,
      controlComponent: '_BottomNavDestination',
      actionId: actionId,
      source: sourcePath,
      surface: surface,
      role: 'navigation-tab',
      evidenceType: 'static-navigation-destination',
      line: _lineForOffset(source, match.start),
    ));
  }

  return rows;
}

List<_UiActionEvidence> _dedupe(List<_UiActionEvidence> rows) {
  final byKey = <String, _UiActionEvidence>{};
  for (final row in rows) {
    byKey.putIfAbsent(row.key, () => row);
  }
  final deduped = byKey.values.toList(growable: false);
  deduped.sort((a, b) {
    final source = a.source.compareTo(b.source);
    if (source != 0) return source;
    final line = a.line.compareTo(b.line);
    if (line != 0) return line;
    final action = a.actionId.compareTo(b.actionId);
    if (action != 0) return action;
    return a.component.compareTo(b.component);
  });
  return deduped;
}

String? _resolveActionId(String expression, Map<String, String> playerActions) {
  final normalized = expression.trim();
  if (normalized == 'null') return null;

  final literal =
      RegExp(r'''^[\'\"]([^\'\"]+)[\'\"]$''').firstMatch(normalized);
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
    r'''static const PlayerActionId\s+([A-Za-z0-9_]+)\s*=\s*[\'\"]([^\'\"]+)[\'\"]''',
    multiLine: true,
  ).allMatches(source);

  for (final match in matches) {
    actions[match.group(1)!] = match.group(2)!;
  }

  return actions;
}

String _surfaceNameFor({required String source, required String sourcePath}) {
  final publicWidget = RegExp(
    r'class\s+([A-Z][A-Za-z0-9]*)\s+extends\s+(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget)',
  ).firstMatch(source);
  if (publicWidget != null) return publicWidget.group(1)!;

  final privateWidget = RegExp(
    r'class\s+(_[A-Z][A-Za-z0-9]*)\s+extends\s+(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget)',
  ).firstMatch(source);
  if (privateWidget != null) return privateWidget.group(1)!;

  return sourcePath.split(Platform.pathSeparator).last.replaceAll('.dart', '');
}

String _designEntityForSurface(String surface) =>
    _surfaceDesignEntityNames[surface] ?? surface;

int _lineForOffset(String source, int offset) {
  var line = 1;
  for (var index = 0; index < offset; index += 1) {
    if (source.codeUnitAt(index) == 10) line += 1;
  }
  return line;
}

class _UiActionEvidence {
  const _UiActionEvidence({
    required this.component,
    required this.controlComponent,
    required this.actionId,
    required this.source,
    required this.surface,
    required this.role,
    required this.evidenceType,
    required this.line,
  });

  final String component;
  final String controlComponent;
  final String actionId;
  final String source;
  final String surface;
  final String role;
  final String evidenceType;
  final int line;

  String get key =>
      '$source:$line:$component:$controlComponent:$actionId:$evidenceType';

  Map<String, Object> toJson() => {
        'component': component,
        'controlComponent': controlComponent,
        'actionId': actionId,
        'source': source,
        'surface': surface,
        'role': role,
        'evidenceType': evidenceType,
        'line': line,
      };
}
