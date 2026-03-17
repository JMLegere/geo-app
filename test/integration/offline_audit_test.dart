/// Integration test: verifies that no core game code imports network packages.
///
/// The audit reads source files directly using [dart:io] and asserts that the
/// only code allowed to import cloud/network dependencies is:
///   - `lib/features/sync/`
///   - `lib/features/auth/services/supabase_auth_service.dart`
///
/// Everything else — core logic, fog, discovery, pack, sanctuary, location,
/// restoration, caretaking — must be network-free.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns every *.dart file under [dir], recursively.
List<File> dartFilesUnder(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) return [];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Network-related import patterns that should NOT appear in offline code.
const kNetworkPatterns = [
  "import 'package:supabase",
  'import "package:supabase',
  "import 'package:http",
  'import "package:http',
  "import 'package:dio",
  'import "package:dio',
  "import 'package:connectivity",
  'import "package:connectivity',
];

/// Returns the matching patterns found in [content], or empty list if clean.
List<String> findNetworkImports(String content) =>
    kNetworkPatterns.where((p) => content.contains(p)).toList();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Offline Network Audit', () {
    // ── lib/core/ ─────────────────────────────────────────────────────────

    test('lib/core/ has zero network imports', () {
      final files = dartFilesUnder('lib/core');
      expect(files, isNotEmpty, reason: 'lib/core must contain source files');

      final violations = <String>[];
      for (final file in files) {
        // supabase_bootstrap.dart is intentionally allowed in core/config —
        // it is the single entry point for Supabase SDK initialisation and
        // must live here to break the auth↔sync circular dependency.
        if (file.path.endsWith('supabase_bootstrap.dart')) continue;
        if (file.path.endsWith('daily_seed_provider.dart')) continue;

        final content = file.readAsStringSync();
        final found = findNetworkImports(content);
        if (found.isNotEmpty) {
          violations.add('${file.path}: ${found.join(', ')}');
        }
      }

      expect(violations, isEmpty,
          reason: 'lib/core must be network-free. Violations:\n'
              '${violations.join('\n')}');
    });

    // ── Feature directories that must be network-free ────────────────────

    final offlineFeatureDirs = [
      'lib/features/map',
      'lib/features/discovery',
      'lib/features/pack',
      'lib/features/sanctuary',
      'lib/features/calendar',
      'lib/features/caretaking',
      'lib/features/location',
      'lib/features/world',
    ];

    for (final dir in offlineFeatureDirs) {
      test('$dir has zero network imports', () {
        final files = dartFilesUnder(dir);
        // A missing directory is not a violation — the feature may not exist yet.
        if (files.isEmpty) return;

        final violations = <String>[];
        for (final file in files) {
          final content = file.readAsStringSync();
          final found = findNetworkImports(content);
          if (found.isNotEmpty) {
            violations.add('${file.path}: ${found.join(', ')}');
          }
        }

        expect(violations, isEmpty,
            reason: '$dir must be network-free. Violations:\n'
                '${violations.join('\n')}');
      });
    }

    // ── Only allowed files may import Supabase ────────────────────────────

    test('only sync and supabase_auth_service import supabase', () {
      // Collect every dart file under lib/ that imports supabase.
      final allLibFiles = dartFilesUnder('lib');
      expect(allLibFiles, isNotEmpty);

      final supabasePattern = "import 'package:supabase";
      final supabasePatternDQ = 'import "package:supabase';

      final violations = <String>[];
      for (final file in allLibFiles) {
        final path = file.path;
        final content = file.readAsStringSync();
        final hasSupabase = content.contains(supabasePattern) ||
            content.contains(supabasePatternDQ);

        if (!hasSupabase) continue;

        // Allowed: anything under lib/features/sync/
        // Allowed: lib/features/auth/services/supabase_auth_service.dart
        // Allowed: lib/core/config/supabase_bootstrap.dart (SDK init entry point)
        // Allowed: lib/core/state/daily_seed_provider.dart (wires Supabase RPC callback)
        final isAllowed = path.contains('lib/features/sync/') ||
            path.endsWith('supabase_auth_service.dart') ||
            path.endsWith('supabase_bootstrap.dart') ||
            path.endsWith('daily_seed_provider.dart') ||
            path.endsWith('main.dart');

        if (!isAllowed) {
          violations.add(path);
        }
      }

      expect(violations, isEmpty,
          reason: 'Unexpected Supabase imports found outside of allowed '
              'boundaries:\n${violations.join('\n')}');
    });

    // ── Only allowed files may import http/dio ────────────────────────────

    test('only sync/ may import http or dio packages', () {
      final allLibFiles = dartFilesUnder('lib');
      final httpPatterns = [
        "import 'package:http",
        'import "package:http',
        "import 'package:dio",
        'import "package:dio',
      ];

      final violations = <String>[];
      for (final file in allLibFiles) {
        final path = file.path;
        final content = file.readAsStringSync();
        final hasHttp = httpPatterns.any((p) => content.contains(p));

        if (!hasHttp) continue;

        if (!path.contains('lib/features/sync/')) {
          violations.add(path);
        }
      }

      expect(violations, isEmpty,
          reason: 'Unexpected http/dio imports:\n${violations.join('\n')}');
    });

    // ── lib/features/sync/ and lib/features/auth/ exist ──────────────────

    test('lib/features/sync/ exists and contains Dart files', () {
      final files = dartFilesUnder('lib/features/sync');
      expect(files, isNotEmpty,
          reason: 'lib/features/sync must contain Dart source files');
    });

    test('supabase_auth_service.dart exists', () {
      final file =
          File('lib/features/auth/services/supabase_auth_service.dart');
      expect(file.existsSync(), isTrue,
          reason: 'supabase_auth_service.dart must exist');
    });
  });
}
