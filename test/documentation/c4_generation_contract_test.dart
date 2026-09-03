import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated C4 set includes distinct current and target containers', () async {
    final check = await Process.run(
      'python3',
      ['scripts/generate_c4_diagrams.py', '--check'],
    );
    expect(check.exitCode, 0, reason: '${check.stdout}\n${check.stderr}');

    final diagrams = Directory('docs/c4')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.mmd'))
        .toList(growable: false);
    expect(diagrams, hasLength(16));

    final current = File('docs/c4/02-container.mmd').readAsStringSync();
    final target = File('docs/c4/02c-container-target.mmd').readAsStringSync();
    expect(current, contains('Local State and Sync'));
    for (final responsibility in const [
      'Player App',
      'Local State and Sync',
      'Identity and Game API',
      'Game World Store',
      'Background World Services',
      'Asset Delivery',
    ]) {
      expect(target, contains(responsibility));
    }
  });
}
