import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interactive control contracts', () {
    test(
        'every raw clickable declares product action or explicit non-product reason',
        () {
      final offenders = <String>[];

      for (final file in _dartFilesUnder('lib')) {
        if (_isWithin(file, 'lib/shared/design')) continue;
        if (file.path == 'lib/shared/product/product_action_surface.dart') {
          continue;
        }

        final source = file.readAsStringSync();
        for (final control in _rawInteractiveControls(source, file.path)) {
          if (_hasActionEvidence(source, control)) continue;
          offenders.add(
            '${control.path}:${control.line} ${control.widget} needs ProductActionSurface(actionId: ...), ObservableInteraction with playerActionId/telemetryOnlyReason, or an eac-clickable-ignore/eac-clickable-owner-logs reason.',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Raw interactive controls must be visible to the EAC/native design contract path. '
            'Use product action evidence for gameplay actions and explicit non-product reasons for local UI/debug/account chrome.',
      );
    });
  });
}

List<_RawInteractiveControl> _rawInteractiveControls(
  String source,
  String path,
) {
  final controls = <_RawInteractiveControl>[];
  final constructor = RegExp(
    r'\b(GestureDetector|InkWell|TextButton|ElevatedButton|FilledButton|OutlinedButton|IconButton|FloatingActionButton)\s*\(',
  );

  for (final match in constructor.allMatches(source)) {
    final widget = match.group(1)!;
    final end = _constructorEnd(source, match.end - 1);
    if (end == null) continue;
    final body = source.substring(match.start, end + 1);

    if (!_hasActiveHandler(body)) continue;

    controls.add(
      _RawInteractiveControl(
        path: path.replaceAll(Platform.pathSeparator, '/'),
        widget: widget,
        start: match.start,
        end: end,
        line: _lineForOffset(source, match.start),
        body: body,
      ),
    );
  }

  return controls;
}

bool _hasActiveHandler(String body) {
  const handlers = [
    'onTap:',
    'onTapUp:',
    'onPressed:',
    'onLongPress:',
    'onScaleEnd:',
    'onHorizontalDragEnd:',
    'onVerticalDragEnd:',
  ];
  return handlers.any((handler) {
    final index = body.indexOf(handler);
    if (index == -1) return false;
    final tail = body.substring(index + handler.length).trimLeft();
    return !tail.startsWith('null');
  });
}

bool _hasActionEvidence(String source, _RawInteractiveControl control) {
  if (control.body.contains('ObservableInteraction.') &&
      (control.body.contains('playerActionId:') ||
          control.body.contains('playerActionIdBuilder:') ||
          control.body.contains('telemetryOnlyReason:') ||
          control.body.contains('telemetryOnlyReasonBuilder:'))) {
    return true;
  }

  final neighborhood = source.substring(
    control.start - 450 < 0 ? 0 : control.start - 450,
    control.end + 120 > source.length ? source.length : control.end + 120,
  );

  if (neighborhood.contains('ProductActionSurface(') &&
      neighborhood.contains('actionId:')) {
    return true;
  }

  final precedingComment = source.substring(
    control.start - 240 < 0 ? 0 : control.start - 240,
    control.start,
  );
  return precedingComment.contains('eac-clickable-ignore:') ||
      precedingComment.contains('eac-clickable-owner-logs:');
}

int? _constructorEnd(String source, int openParenOffset) {
  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  var inRaw = false;

  for (var index = openParenOffset; index < source.length; index += 1) {
    final char = source[index];
    final prev = index > 0 ? source[index - 1] : '';

    if (!inSingle && !inDouble && char == 'r' && index + 1 < source.length) {
      final next = source[index + 1];
      if (next == "'" || next == '"') inRaw = true;
    }

    if (!inDouble && char == "'" && (inRaw || prev != r'\')) {
      inSingle = !inSingle;
      if (!inSingle) inRaw = false;
      continue;
    }
    if (!inSingle && char == '"' && (inRaw || prev != r'\')) {
      inDouble = !inDouble;
      if (!inDouble) inRaw = false;
      continue;
    }
    if (inSingle || inDouble) continue;

    if (char == '(') depth += 1;
    if (char == ')') {
      depth -= 1;
      if (depth == 0) return index;
    }
  }

  return null;
}

List<File> _dartFilesUnder(String relativePath) {
  final directory = Directory(relativePath);
  if (!directory.existsSync()) return const [];

  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

bool _isWithin(File file, String relativeDirectory) {
  final dir = Directory(relativeDirectory).absolute.path;
  final path = file.absolute.path;
  return path == dir || path.startsWith('$dir${Platform.pathSeparator}');
}

int _lineForOffset(String source, int offset) {
  var line = 1;
  for (var index = 0; index < offset; index += 1) {
    if (source.codeUnitAt(index) == 10) line += 1;
  }
  return line;
}

class _RawInteractiveControl {
  const _RawInteractiveControl({
    required this.path,
    required this.widget,
    required this.start,
    required this.end,
    required this.line,
    required this.body,
  });

  final String path;
  final String widget;
  final int start;
  final int end;
  final int line;
  final String body;
}
