import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstBuild = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const secondBuild = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  Directory fixture() {
    final root = Directory.systemTemp.createTempSync('earthnova-web-assets-');
    final fonts = Directory('${root.path}/assets/fonts')
      ..createSync(recursive: true);
    File('${root.path}/assets/FontManifest.json').writeAsStringSync(
      '[{"family":"MaterialIcons","fonts":[{"asset":"fonts/MaterialIcons-Regular.otf"}]}]',
    );
    File(
      '${fonts.path}/MaterialIcons-Regular.otf',
    ).writeAsBytesSync(const <int>[0]);
    File('${root.path}/main.dart.js').writeAsStringSync('same compiled Dart');
    File('${root.path}/flutter_bootstrap.js').writeAsStringSync('main.dart.js');
    File(
      '${root.path}/index.html',
    ).writeAsStringSync('<meta name="flutter-asset-base" content="">');
    return root;
  }

  ProcessResult package(Directory root, String buildId) => Process.runSync(
    'sh',
    <String>['tool/package_web_release_assets.sh', root.path, buildId],
  );

  String engineAssetUrl(Directory root) {
    final assetBase = RegExp(
      r'<meta name="flutter-asset-base" content="([^"]+)">',
    ).firstMatch(File('${root.path}/index.html').readAsStringSync())!.group(1)!;
    return Uri.parse(
      'https://earthnova.test/',
    ).resolve(assetBase).resolve('assets/fonts/MaterialIcons-Regular.otf').path;
  }

  test(
    'new Dart and its tree-shaken Material font share one release URL base',
    () {
      final root = fixture();
      addTearDown(() => root.deleteSync(recursive: true));

      expect(package(root, firstBuild).exitCode, 0);
      expect(
        File(
          '${root.path}/releases/$firstBuild/assets/fonts/MaterialIcons-Regular.otf',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${root.path}/releases/$firstBuild/assets/FontManifest.json',
        ).readAsStringSync(),
        contains('fonts/MaterialIcons-Regular.otf'),
      );
      expect(
        File('${root.path}/flutter_bootstrap.js').readAsStringSync(),
        contains('main.dart.js?v=$firstBuild'),
      );
      expect(
        engineAssetUrl(root),
        '/releases/$firstBuild/assets/fonts/MaterialIcons-Regular.otf',
      );
    },
  );

  test(
    'an asset-only upgrade receives a new asset URL even when Dart is unchanged',
    () {
      final firstRoot = fixture();
      final secondRoot = fixture();
      addTearDown(() => firstRoot.deleteSync(recursive: true));
      addTearDown(() => secondRoot.deleteSync(recursive: true));

      expect(package(firstRoot, firstBuild).exitCode, 0);
      expect(package(secondRoot, secondBuild).exitCode, 0);
      expect(
        File('${firstRoot.path}/main.dart.js').readAsStringSync(),
        File('${secondRoot.path}/main.dart.js').readAsStringSync(),
      );
      expect(engineAssetUrl(firstRoot), isNot(engineAssetUrl(secondRoot)));
    },
  );

  test(
    'local bootstrap leaves Flutter on its unversioned default asset base',
    () {
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains('<meta name="flutter-asset-base" content="">'));
      expect(
        index,
        contains('if (assetBase) engineConfig.assetBase = assetBase;'),
      );
    },
  );

  test('bootstrap waits for the inline engine interceptor to register', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('src="flutter_bootstrap.js" defer=""'));
    expect(index, isNot(contains('src="flutter_bootstrap.js" async')));
  });

  test('release packaging rejects a missing or invalid commit identity', () {
    final root = fixture();
    addTearDown(() => root.deleteSync(recursive: true));

    expect(package(root, '').exitCode, isNot(0));
    expect(package(root, 'not-a-commit').exitCode, isNot(0));
  });

  test('Docker packages release assets with the authoritative commit SHA', () {
    final docker = File('Dockerfile').readAsStringSync();

    expect(docker, contains('package_web_release_assets.sh'));
    expect(docker, contains('BUILD_COMMIT_SHA'));
  });
}
