import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbiddenFixtureAccess = <String, RegExp>{
  'app bootstrap': RegExp(r'\b(?:runApp|main|bootstrap\w*)\s*\('),
  'live backend client': RegExp(
    r'\b(?:Supabase(?:Client)?|createClient|FirebaseApp|Firestore)\b',
  ),
  'network client': RegExp(r'\b(?:HttpClient|Dio|WebSocketChannel)\b'),
  'GPS access': RegExp(
    r'\b(?:Geolocator|PositionStream|getCurrentPosition|getPositionStream)\b',
  ),
  'persistent storage': RegExp(
    r'\b(?:SharedPreferences|Preferences|Hive|SecureStorage|SQLiteDatabase)\b',
  ),
  'telemetry delivery': RegExp(
    r'\b(?:Sentry|FirebaseAnalytics|Amplitude|Mixpanel)\b|'
    r'\b(?:observability|telemetry)\s*\.\s*'
    r'(?:track|record|capture|send|flush|persist)\w*\s*\(',
    caseSensitive: false,
  ),
  'current clock': RegExp(r'\bDateTime\.now\s*\('),
  'external URL literal': RegExp(r'''['"](?:https?|wss?)://'''),
};

void main() {
  final roots = <Directory>[
    Directory('lib/fixtures'),
    Directory('lib/use_cases'),
  ];

  test(
    'fixtures and stories stay offline, deterministic, and side-effect free',
    () {
      for (final root in roots) {
        expect(
          root.existsSync(),
          isTrue,
          reason: 'Missing catalog root: ${root.path}',
        );
        for (final file in _dartFiles(root)) {
          final source = file.readAsStringSync();
          for (final entry in _forbiddenFixtureAccess.entries) {
            expect(
              entry.value.hasMatch(source),
              isFalse,
              reason:
                  '${file.path}: forbidden ${entry.key} (${entry.value.pattern})',
            );
          }
        }
      }
    },
  );

  test(
    'workshop map style only references local assets and fixed provenance',
    () {
      final style = File('web/base-map-style.json');
      final reference = File('assets/map/reference.json');
      expect(
        style.existsSync(),
        isTrue,
        reason: 'Missing workshop map style: ${style.path}',
      );
      expect(
        reference.existsSync(),
        isTrue,
        reason: 'Missing workshop map provenance: ${reference.path}',
      );

      final styleSource = style.readAsStringSync();
      final localReferences = RegExp(
        r'"(?:url|glyphs|sprite)"\s*:\s*"([^"]+)"',
      ).allMatches(styleSource).map((match) => match.group(1)!).toList();
      expect(
        localReferences,
        isNotEmpty,
        reason: '${style.path} must name its local image/glyph assets',
      );
      for (final reference in localReferences) {
        expect(
          reference.startsWith('assets/'),
          isTrue,
          reason: '${style.path}: non-local style reference $reference',
        );
      }
      expect(
        styleSource,
        isNot(matches(RegExp(r'(?:https?|wss?|mapbox)://'))),
        reason: '${style.path} must not fetch map tiles, glyphs, or sprites',
      );
      expect(
        styleSource,
        contains('"referenceMetadata": "assets/map/reference.json"'),
      );
      expect(
        styleSource,
        contains('"expectedBuiltAssetUrl": "assets/assets/map/reference.png"'),
      );

      final metadata = reference.readAsStringSync();
      expect(metadata, contains('"attribution":'));
      expect(
        metadata,
        matches(RegExp(r'"sha256"\s*:\s*"[a-f0-9]{64}"')),
        reason: '${reference.path} must pin the documentary image checksum',
      );
      expect(metadata, contains('"expectedBuiltAssetUrl":'));

      final index = File('web/index.html').readAsStringSync();
      expect(index, contains('http-equiv="Content-Security-Policy"'));
      expect(index, contains("font-src 'self' data:"));
      expect(index, contains("connect-src 'self'"));
    },
  );
}

List<File> _dartFiles(Directory root) {
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}
