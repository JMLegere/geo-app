import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interaction coverage matrix callbacks are instrumented', () {
    final repoRoot = Directory.current.path;
    final matrixFile =
        File('$repoRoot/docs/observability-interaction-coverage.md');

    expect(matrixFile.existsSync(), isTrue,
        reason:
            'Missing docs/observability-interaction-coverage.md coverage matrix.');

    final matrixLines = matrixFile.readAsLinesSync();
    final rows = matrixLines
        .where((line) => line.trimLeft().startsWith('|'))
        .skip(2)
        .where((line) => line.trim().isNotEmpty)
        .toList();

    expect(rows, isNotEmpty,
        reason: 'Coverage matrix must include at least one callback row.');

    for (final row in rows) {
      final columns = row
          .split('|')
          .map((column) => column.trim())
          .where((column) => column.isNotEmpty)
          .toList();

      expect(columns.length, 4, reason: 'Invalid matrix row format: $row');

      final location = columns[0];
      final wrapperName = columns[1];
      final actionType = columns[2];
      final payloadKeys = columns[3];

      expect(actionType, isNotEmpty,
          reason: 'Missing expected action_type in row: $row');
      expect(payloadKeys, isNotEmpty,
          reason: 'Missing expected payload keys in row: $row');

      final splitIndex = location.lastIndexOf(':');
      expect(splitIndex, greaterThan(0),
          reason: 'Invalid callback location format: $location');

      final relativePath = location.substring(0, splitIndex);
      final lineNumber = int.parse(location.substring(splitIndex + 1));

      final sourceFile = File('$repoRoot/$relativePath');
      expect(sourceFile.existsSync(), isTrue,
          reason: 'Missing source file listed in matrix: $relativePath');

      final sourceLines = sourceFile.readAsLinesSync();
      expect(lineNumber, inInclusiveRange(1, sourceLines.length),
          reason: 'Line number out of range for $relativePath:$lineNumber');

      final callbackWindow = [
        for (var i = lineNumber - 1;
            i < sourceLines.length && i < lineNumber + 3;
            i++)
          sourceLines[i],
      ].join('\n');

      expect(
        callbackWindow.contains('ObservableInteraction.'),
        isTrue,
        reason:
            'Callback at $location is not wrapped with ObservableInteraction. Expected wrapper: $wrapperName',
      );
    }
  });
}
