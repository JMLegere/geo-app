import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTel surface coverage guards', () {
    test('every presentation screen is wrapped in ObservableScreen', () {
      final screenFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('/presentation/screens/'))
          .where((file) => file.path.endsWith('_screen.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(screenFiles, isNotEmpty);

      final missing = <String>[];
      for (final file in screenFiles) {
        final source = file.readAsStringSync();
        if (!source.contains('ObservableScreen(') ||
            !source.contains('screenName:')) {
          missing.add(file.path);
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Every screen-level surface must be externally observable. '
            'Wrap screens in ObservableScreen with a stable screenName. '
            '\nMissing coverage:\n${missing.join('\n')}',
      );
    });

    test('interactive screen files declare ObservableInteraction coverage', () {
      final interactivePatterns = [
        RegExp(r'onPressed\s*:'),
        RegExp(r'onTap\s*:'),
        RegExp(r'onTapUp\s*:'),
        RegExp(r'onChanged\s*:'),
        RegExp(r'onDestinationSelected\s*:'),
        RegExp(r'onScaleEnd\s*:'),
      ];

      final files = <File>[
        ...Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.contains('/presentation/screens/'))
            .where((file) => file.path.endsWith('.dart')),
        File('lib/shared/widgets/tab_shell.dart'),
        File('lib/features/map/presentation/widgets/hierarchy_header.dart'),
      ]..sort((a, b) => a.path.compareTo(b.path));

      final missing = <String>[];
      for (final file in files) {
        final source = file.readAsStringSync();
        final hasInteractiveCallback =
            interactivePatterns.any((pattern) => pattern.hasMatch(source));
        if (!hasInteractiveCallback) continue;

        final hasCoverage = source.contains('ObservableInteraction.') ||
            source.contains('_logInteraction(') ||
            source.contains('_logMapEvent(');
        if (!hasCoverage) missing.add(file.path);
      }

      expect(
        missing,
        isEmpty,
        reason: 'Files with user-interaction callbacks must route those '
            'callbacks through ObservableInteraction or an equivalent '
            'screen-scoped telemetry logger.\nMissing coverage:\n'
            '${missing.join('\n')}',
      );
    });

    test('domain use cases are observable and propagate trace ids downstream',
        () {
      final useCaseFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('/domain/use_cases/'))
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(useCaseFiles, isNotEmpty);

      final notObservable = <String>[];
      final droppedTrace = <String>[];
      final repositoryCallPattern = RegExp(r'_repository\.[A-Za-z_]\w*\(');

      for (final file in useCaseFiles) {
        final source = file.readAsStringSync();
        if (!source.contains('extends ObservableUseCase<')) {
          notObservable.add(file.path);
        }

        if (!source.contains('String traceId')) continue;
        final repositoryCalls = repositoryCallPattern.allMatches(source);
        for (final match in repositoryCalls) {
          final tail = source.substring(match.start);
          final callEnd = tail.indexOf(');');
          final callSource = callEnd == -1 ? tail : tail.substring(0, callEnd);
          if (!callSource.contains('traceId: traceId')) {
            droppedTrace.add('${file.path}: ${match.group(0)}');
          }
        }
      }

      expect(
        notObservable,
        isEmpty,
        reason: 'Every domain use case must extend ObservableUseCase.\n'
            '${notObservable.join('\n')}',
      );
      expect(
        droppedTrace,
        isEmpty,
        reason: 'Use cases that call repositories must propagate traceId so '
            'frontend spans can be connected to DB/RPC logs.\n'
            '${droppedTrace.join('\n')}',
      );
    });

    test('Supabase repositories emit operation, duration, and error telemetry',
        () {
      final repositoryFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('/data/repositories/'))
          .where((file) => file.path.split('/').last.startsWith('supabase_'))
          .where((file) => !file.path.endsWith('_adapter.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(repositoryFiles, isNotEmpty);

      final missing = <String>[];
      for (final file in repositoryFiles) {
        final source = file.readAsStringSync();
        final requiredSnippets = {
          'RepositoryLogEvent or logEvent':
              source.contains('RepositoryLogEvent') ||
                  source.contains('logEvent'),
          'started event': source.contains('_started\'') ||
              source.contains('db.query_started') ||
              source.contains('db.rpc_started'),
          'completed event': source.contains('_completed\'') ||
              source.contains('db.query_completed') ||
              source.contains('db.rpc_completed'),
          'failed event': source.contains('_failed\'') ||
              source.contains('db.query_failed') ||
              source.contains('db.rpc_failed'),
          'operation attribute': source.contains("'operation'"),
          'duration_ms attribute': source.contains('duration_ms'),
          'error_type attribute': source.contains('error_type'),
          'error_message attribute': source.contains('error_message'),
        };

        final absent = requiredSnippets.entries
            .where((entry) => !entry.value)
            .map((entry) => entry.key)
            .toList();
        if (absent.isNotEmpty) {
          missing.add('${file.path}: missing ${absent.join(', ')}');
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Supabase repository calls are external system boundaries. '
            'They must emit OTel-shaped started/completed/failed telemetry '
            'with operation, duration, and diagnostic error fields.\n'
            '${missing.join('\n')}',
      );
    });
  });
}
