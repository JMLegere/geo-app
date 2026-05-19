import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ObservableInteraction call sites declare product action classification',
      () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final missing = <String>[];
    final rawStringIds = <String>[];
    final callNames = [
      'ObservableInteraction.log',
      'ObservableInteraction.wrapVoidCallback',
      'ObservableInteraction.wrapAsyncCallback',
      'ObservableInteraction.wrapValueChanged',
      'ObservableInteraction.wrapTapUp',
      'ObservableInteraction.wrapScaleEnd',
      'ObservableInteraction.payload',
      '_logInteraction',
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final callName in callNames) {
        var searchFrom = 0;
        while (true) {
          final index = source.indexOf('$callName(', searchFrom);
          if (index == -1) break;
          searchFrom = index + callName.length;

          if (_isFunctionDeclaration(source, index, callName)) continue;

          final call = _extractCall(source, index + callName.length);
          if (call == null) continue;

          final hasProductAction = call.contains('playerActionId:') ||
              call.contains('playerActionIdBuilder:');
          final hasTelemetryOnlyReason =
              call.contains('telemetryOnlyReason:') ||
                  call.contains('telemetryOnlyReasonBuilder:');
          if (!hasProductAction && !hasTelemetryOnlyReason) {
            missing.add('${file.path}:${_lineNumber(source, index)} $callName');
          }

          if (RegExp(r'''playerActionId\s*:\s*["']''').hasMatch(call)) {
            rawStringIds
                .add('${file.path}:${_lineNumber(source, index)} $callName');
          }
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'ObservableInteraction calls must declare either a typed '
          'PlayerActions.* id or an explicit telemetry-only reason.\n'
          '${missing.join('\n')}',
    );
    expect(
      rawStringIds,
      isEmpty,
      reason:
          'playerActionId must use PlayerActions.* constants, not raw strings.\n'
          '${rawStringIds.join('\n')}',
    );
  });
}

bool _isFunctionDeclaration(String source, int index, String callName) {
  if (callName != '_logInteraction') return false;
  final lineStart = source.lastIndexOf('\n', index) + 1;
  final prefix = source.substring(lineStart, index);
  return prefix.contains('void ') || prefix.contains('Future<void> ');
}

String? _extractCall(String source, int openParenIndex) {
  if (openParenIndex >= source.length || source[openParenIndex] != '(') {
    return null;
  }

  var depth = 0;
  String? quote;
  var escaped = false;
  for (var i = openParenIndex; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }

    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(openParenIndex, i + 1);
    }
  }

  return null;
}

int _lineNumber(String source, int index) {
  return '\n'.allMatches(source.substring(0, index)).length + 1;
}
