import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _dartDirectivePattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<File> _dartFilesUnder(String directoryPath) {
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) return const <File>[];

  final files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => _normalizePath(file.path).endsWith('.dart'))
          .toList()
        ..sort(
          (left, right) =>
              _normalizePath(left.path).compareTo(_normalizePath(right.path)),
        );
  return files;
}

String _normalizePath(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  final normalized = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (normalized.isNotEmpty && normalized.last != '..') {
        normalized.removeLast();
      } else {
        normalized.add(segment);
      }
      continue;
    }
    normalized.add(segment);
  }
  return normalized.join('/');
}

String _resolvedImportPath(File sourceFile, String importUri) {
  if (!importUri.startsWith('.')) return _normalizePath(importUri);

  final sourceSegments = _normalizePath(sourceFile.path).split('/')
    ..removeLast();
  return _normalizePath([...sourceSegments, importUri].join('/'));
}

bool _matchesPackagePrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

bool _isFeaturePackagePath(String path) {
  if (path.startsWith('package:earth_nova/features/')) return true;

  final segments = path.split('/');
  for (var index = 0; index + 1 < segments.length; index++) {
    if (segments[index] == 'lib' && segments[index + 1] == 'features') {
      return true;
    }
  }
  return false;
}

bool _isFeatureLayerImport(File sourceFile, String importUri, String layer) {
  final path = _resolvedImportPath(sourceFile, importUri);
  if (!_isFeaturePackagePath(path)) return false;

  final segments = path.split('/');
  final featuresIndex = segments.indexOf('features');
  return featuresIndex >= 0 &&
      featuresIndex + 2 < segments.length &&
      segments[featuresIndex + 2] == layer;
}

bool _isForbiddenDomainImport(File sourceFile, String importUri) {
  final path = _resolvedImportPath(sourceFile, importUri);
  const forbiddenPackagePrefixes = [
    'package:flutter',
    'package:flutter_riverpod',
    'package:riverpod',
    'package:supabase',
  ];

  return path == 'dart:ui' ||
      forbiddenPackagePrefixes.any(
        (prefix) => _matchesPackagePrefix(path, prefix),
      ) ||
      _isFeatureLayerImport(sourceFile, importUri, 'presentation') ||
      _isFeatureLayerImport(sourceFile, importUri, 'data');
}

bool _isFeaturePresentationUiFile(File file) {
  final segments = _normalizePath(file.path).split('/');
  final featuresIndex = segments.indexOf('features');
  const uiDirectories = {'screens', 'widgets', 'painters'};

  return featuresIndex >= 0 &&
      featuresIndex + 3 < segments.length &&
      segments[featuresIndex + 2] == 'presentation' &&
      uiDirectories.contains(segments[featuresIndex + 3]);
}

bool _isFeatureObservabilitySharedImportViolation(File file, String contents) =>
    contents.contains('ObservabilityService') &&
    contents.contains("import 'package:earth_nova/shared/") &&
    !_isFeaturePresentationUiFile(file);

void main() {
  group('shared observability architecture guards', () {
    test('non-UI feature observability files do not import lib/shared', () {
      final featuresDir = Directory('lib/features');
      final violations = <String>[];

      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final contents = entity.readAsStringSync();
        if (_isFeatureObservabilitySharedImportViolation(entity, contents)) {
          violations.add(entity.path);
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason:
            'Non-UI feature observability files must not import lib/shared:\n'
            '${violations.join('\n')}',
      );
    });

    test(
      'allows shared imports for presentation screen observability consumers',
      () {
        expect(
          _isFeatureObservabilitySharedImportViolation(
            File('lib/ui/product_surfaces/map/screens/map_screen.dart'),
            '''
import 'package:earth_nova/ui/design_system.dart';
final ObservabilityService observabilityService;
''',
          ),
          isFalse,
        );
      },
    );

    test(
      'rejects shared imports for domain and provider observability sources',
      () {
        const source = '''
import 'package:earth_nova/shared/observability.dart';
final ObservabilityService observabilityService;
''';

        for (final path in [
          'lib/features/map/domain/use_cases/record_visit.dart',
          'lib/features/map/presentation/providers/map_provider.dart',
        ]) {
          expect(
            _isFeatureObservabilitySharedImportViolation(File(path), source),
            isTrue,
            reason: path,
          );
        }
      },
    );

    test(
      'core domain files do not import framework or feature presentation/data layers',
      () {
        final violations = <String>[];

        for (final file in _dartFilesUnder('lib/core/domain')) {
          final contents = file.readAsStringSync();
          for (final match in _dartDirectivePattern.allMatches(contents)) {
            final importUri = match.group(1)!;
            if (_isForbiddenDomainImport(file, importUri)) {
              violations.add(
                '${_normalizePath(file.path)} imports forbidden dependency '
                '$importUri',
              );
            }
          }
        }

        violations.sort();

        expect(
          violations,
          isEmpty,
          reason:
              'Core domain files must not import Flutter (including dart:ui), '
              'Riverpod, Supabase, or feature presentation/data layers. '
              'Move each dependency behind an appropriate adapter:\n'
              '${violations.join('\n')}',
        );
      },
    );

    test('core domain rules do not import feature packages', () {
      final violations = <String>[];

      for (final file in _dartFilesUnder('lib/core/domain/rules')) {
        final contents = file.readAsStringSync();
        for (final match in _dartDirectivePattern.allMatches(contents)) {
          final importUri = match.group(1)!;
          final resolvedImportPath = _resolvedImportPath(file, importUri);
          if (_isFeaturePackagePath(resolvedImportPath)) {
            violations.add(
              '${_normalizePath(file.path)} imports feature package '
              '$importUri',
            );
          }
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason:
            'Rule files must not import feature packages. Move each '
            'feature dependency out of lib/core/domain/rules/:\n'
            '${violations.join('\n')}',
      );
    });

    test('observability layer has no static mutable globals', () {
      final dirs = [
        Directory('lib/core/observability'),
        Directory('lib/shared/observability'),
      ];

      final violations = <String>[];
      final staticMutablePattern = RegExp(
        r'^\s*static\s+(?!const\b|final\b)[\w<>?,\s]+\s+\w+\s*(=|;)',
        multiLine: true,
      );

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final contents = entity.readAsStringSync();
          if (staticMutablePattern.hasMatch(contents)) {
            violations.add(entity.path);
          }
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason:
            'Observability files must not define static mutable globals:\n'
            '${violations.join('\n')}',
      );
    });

    test('core observability contract files have no Flutter UI imports', () {
      final contractFiles = [
        File('lib/core/observability/app_observability_provider.dart'),
        File('lib/core/observability/observable_use_case_provider.dart'),
      ];

      final violations = <String>[];

      for (final file in contractFiles) {
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected core observability contract file to exist: ${file.path}',
        );

        final contents = file.readAsStringSync();
        final hasFlutterUiImport =
            contents.contains("import 'package:flutter/material.dart'") ||
            contents.contains("import 'package:flutter/widgets.dart'") ||
            contents.contains("import 'package:flutter/cupertino.dart'");

        if (hasFlutterUiImport) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Core observability contract files must stay UI-free:\n'
            '${violations.join('\n')}',
      );
    });
  });

  test('all root app screens are wrapped with ObservableScreen', () {
    final screenFiles = <String, ({String path, List<String> evidence})>{
      'loading_screen': (
        path: 'lib/ui/product_surfaces/auth/screens/loading_screen.dart',
        evidence: ["screenName: 'loading_screen'"],
      ),
      'login_screen': (
        path: 'lib/ui/product_surfaces/auth/screens/login_screen.dart',
        evidence: ["screenName: 'login_screen'"],
      ),
      'pack_screen': (
        path: 'lib/ui/product_surfaces/pack/screens/pack_screen.dart',
        evidence: ["screenName: 'pack_screen'"],
      ),
      'identification_service_screen': (
        path:
            'lib/ui/product_surfaces/identification/screens/identification_service_screen.dart',
        evidence: ["screenName: 'identification_service_screen'"],
      ),
      'town_screen': (
        path: 'lib/ui/product_surfaces/living_world/screens/town_screen.dart',
        evidence: ["screenName: 'town_screen'"],
      ),
      'venue_detail_screen': (
        path:
            'lib/ui/product_surfaces/living_world/screens/venue_detail_screen.dart',
        evidence: [
          "static const _screenName = 'venue_detail_screen'",
          'screenName: _screenName',
        ],
      ),
      'home_screen': (
        path: 'lib/ui/product_surfaces/home/screens/home_screen.dart',
        evidence: ["screenName: 'home_screen'"],
      ),
      'map_root_screen': (
        path: 'lib/ui/product_surfaces/map/screens/map_root_screen.dart',
        evidence: ["screenName: 'map_root_screen'"],
      ),
      'map_screen': (
        path: 'lib/ui/product_surfaces/map/screens/map_screen.dart',
        evidence: ["screenName: 'map_screen'"],
      ),
      'settings_screen': (
        path: 'lib/ui/product_surfaces/profile/screens/settings_screen.dart',
        evidence: ["screenName: 'settings_screen'"],
      ),
    };

    final missing = <String>[];
    for (final entry in screenFiles.entries) {
      final source = File(entry.value.path).readAsStringSync();
      final missingEvidence = entry.value.evidence
          .where((evidence) => !source.contains(evidence))
          .toList();
      if (!source.contains('ObservableScreen(') || missingEvidence.isNotEmpty) {
        missing.add('${entry.key} (${entry.value.path})');
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Root screens must be wrapped in ObservableScreen with stable screen names:\n${missing.join('\n')}',
    );
  });
}
