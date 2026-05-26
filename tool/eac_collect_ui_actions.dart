import 'dart:convert';
import 'dart:io';

// Starter collector: scans Flutter/Dart source for explicit actionId: '<product-action>'
// on action-bearing design entities and emits generic EAC UI action evidence.
// Customize component detection for your project before relying on this in CI.

void main() {
  final controls = <Map<String, String>>[];
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final source = file.readAsStringSync();
    final matches = RegExp(r'''([A-Z][A-Za-z0-9_]*)\s*\([\s\S]*?actionId:\s*['"]([^'"]+)['"]''', multiLine: true).allMatches(source);
    for (final match in matches) {
      controls.add({
        'component': match.group(1)!,
        'actionId': match.group(2)!,
        'source': file.path,
        'role': 'button',
      });
    }
  }

  final output = File('artifacts/eac/ui-actions.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'controls': controls}) + '\n');
}
