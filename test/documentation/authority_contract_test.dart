import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

enum _DocumentRole {
  canonical,
  router,
  currentScoped,
  historicalEvidence,
  generatedVendor,
}

void main() {
  group('documentation authority contract', () {
    test('every repository Markdown file has exactly one role', () {
      final markdownPaths = _repositoryMarkdownPaths();
      final unclassified = <String>[];

      for (final path in markdownPaths) {
        if (_roleFor(path) == null) unclassified.add(path);
      }

      expect(
        unclassified,
        isEmpty,
        reason:
            'Every Markdown file must be covered by docs/INDEX.md. '
            'Unclassified:\n${unclassified.join('\n')}',
      );
      expect(markdownPaths, isNotEmpty);
    });

    test('historical evidence carries one visible authority notice', () {
      final violations = <String>[];

      for (final path in _repositoryMarkdownPaths()) {
        if (_roleFor(path) != _DocumentRole.historicalEvidence) continue;
        final contents = File(path).readAsStringSync();
        final markerCount = 'HISTORICAL-EVIDENCE'.allMatches(contents).length;
        if (markerCount != 1) {
          violations.add('$path (markers: $markerCount)');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Historical documents must carry exactly one visible '
            'HISTORICAL-EVIDENCE notice:\n${violations.join('\n')}',
      );
    });

    test('cold-start routers point to the current authority spine', () {
      final index = File('docs/INDEX.md').readAsStringSync();
      final readme = File('README.md').readAsStringSync();
      final rootAgents = File('AGENTS.md').readAsStringSync();
      final projectAgents = File('.agents/AGENTS.md').readAsStringSync();

      for (final authorityPath in [
        'CONTEXT.md',
        'docs/adr/',
        '.agents/constraints.md',
      ]) {
        expect(index, contains(authorityPath));
        expect(readme, contains(authorityPath));
        expect(rootAgents, contains(authorityPath));
        expect(projectAgents, contains(authorityPath));
      }

      expect(index, contains('Complete Markdown Classification'));
      expect(index, isNot(contains('`docs/design.md` | Source of truth')));
      expect(rootAgents, isNot(contains('sanctuary building')));
    });
  });
}

List<String> _repositoryMarkdownPaths() {
  const skippedDirectories = {
    '.git',
    '.dart_tool',
    '.pub-cache',
    'build',
    'node_modules',
    'ephemeral',
  };
  final paths = <String>[];

  for (final entity in Directory('.').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final normalized = entity.path.replaceAll('\\', '/').replaceFirst('./', '');
    final segments = normalized.split('/');
    if (segments.any(skippedDirectories.contains)) continue;
    paths.add(normalized);
  }

  paths.sort();
  return paths;
}

_DocumentRole? _roleFor(String path) {
  const routers = {
    '.agents/AGENTS.md',
    'AGENTS.md',
    'README.md',
    'docs/INDEX.md',
  };
  const currentScoped = {
    '.agents/architecture.md',
    '.agents/constraints.md',
    '.agents/context.md',
    '.agents/decisions.md',
    '.agents/discovery/2026-05-03-earthnova-map-domain-visual-requirements.md',
    '.agents/questions.md',
    'docs/c4/README.md',
    'docs/dependencies.md',
    'docs/frontend-usability-design-system.md',
    'docs/ios-safari-maplibre.md',
    'docs/issue-596-finish-plan.md',
    'docs/local-save-migration.md',
    'docs/prd-target-container-migration.md',
    'docs/prd-shadcn-ui-reset.md',
    'docs/observability-interaction-coverage.md',
    'docs/runbook.md',
    'lib/shared/design/README.md',
  };
  const historicalExact = {
    '.agents/eac-native-design-migration-plan.md',
    'docs/design.md',
    'docs/eac-native-design-migration-plan.md',
    'docs/map-design.md',
    'docs/prd-game-systems-review.md',
    'docs/prd-game-systems.md',
  };

  if (path == 'CONTEXT.md' || path.startsWith('docs/adr/')) {
    return _DocumentRole.canonical;
  }
  if (routers.contains(path)) return _DocumentRole.router;
  if (path.startsWith('docs/specifications/ui596/')) {
    return _DocumentRole.currentScoped;
  }
  if (currentScoped.contains(path)) return _DocumentRole.currentScoped;
  if (path == 'ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md') {
    return _DocumentRole.generatedVendor;
  }
  if (historicalExact.contains(path) ||
      path.startsWith('2026-04-03-') ||
      path.startsWith('docs/diagrams/') ||
      path.startsWith('docs/jtbd/') ||
      path.startsWith('.agents/discovery/') ||
      path.startsWith('.agents/mocks/') ||
      path.startsWith('.agents/qa/') ||
      path.startsWith('.agents/top-down/') ||
      path.startsWith('.claude/agent_notes/') ||
      path.startsWith('.opencode/plans/')) {
    return _DocumentRole.historicalEvidence;
  }
  return null;
}
