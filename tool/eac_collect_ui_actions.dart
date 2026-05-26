import 'dart:convert';
import 'dart:io';

// EarthNova collector: scans app Flutter/Dart source for EarthActionButton
// instances with explicit product action IDs and emits generic EAC UI action
// evidence. `actionId: null` is an explicit non-product-action decision.

void main() {
  final controls = <Map<String, String>>[];
  for (final file
      in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    if (file.path.startsWith('lib/shared/design/')) continue;

    final source = file.readAsStringSync();
    final matches = RegExp(
      r'''EarthActionButton\s*\([\s\S]*?actionId:\s*['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(source);
    for (final match in matches) {
      controls.add({
        'component': 'EarthActionButton',
        'actionId': match.group(1)!,
        'source': file.path,
        'role': 'button',
      });
    }
  }

  final output = File('artifacts/eac/ui-actions.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'controls': controls
      })}\n');
}
