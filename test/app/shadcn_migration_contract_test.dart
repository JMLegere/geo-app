import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  final pubspecLock = File('$root/pubspec.lock').readAsStringSync();

  String read(String path) => File('$root/$path').readAsStringSync();

  test('preserves the migration contract', () {
    final appRoot = read('lib/ui/product_surfaces/app/earth_nova_app.dart');
    expect(appRoot, contains('theme: AppDesignTheme.dark()'));
    expect(appRoot, contains('themeMode: ThemeMode.dark'));
    expect(appRoot, contains('theme: Theme.of(context)'));
    expect(appRoot, contains("supportedLocales: const [Locale('en', 'US')]"));
    for (final delegate in const [
      'GlobalShadLocalizations.delegate',
      'GlobalMaterialLocalizations.delegate',
      'GlobalCupertinoLocalizations.delegate',
      'GlobalWidgetsLocalizations.delegate',
    ]) {
      expect(appRoot, contains(delegate));
    }
    expect(appRoot, isNot(contains('AppTheme.dark(')));
    final tabShell = read('lib/ui/product_surfaces/app/tab_shell.dart');
    final template = read(
      'product/design/templates/primary-navigation-shell.template',
    );
    final prd = read('docs/prd-shadcn-ui-reset.md');

    expect(appRoot, contains('debugShowCheckedModeBanner: false'));
    expect(appRoot, contains('scrollBehavior: const MaterialScrollBehavior()'));
    for (final device in const [
      'PointerDeviceKind.touch',
      'PointerDeviceKind.mouse',
      'PointerDeviceKind.stylus',
      'PointerDeviceKind.trackpad',
    ]) {
      expect(appRoot, contains(device));
    }
    expect(appRoot, contains('navigatorObservers: ['));
    expect(appRoot, contains('AppNavigationObserver('));
    expect(appRoot, contains('home: authState.when('));
    expect(
      appRoot,
      matches(RegExp(r'authenticated:\s*\(user\)\s*=>\s*AppReadinessGate\(')),
    );
    expect(appRoot, contains('loading: () => const LoadingScreen()'));
    expect(appRoot, contains('unauthenticated: () => const LoginScreen()'));
    expect(appRoot, contains('error: (_) => const LoginScreen()'));
    expect(read('lib/main.dart'), contains('child: const EarthNovaApp()'));

    final destinations = RegExp(
      r'const _bottomNavItems = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(tabShell);
    expect(destinations, isNotNull);
    final destinationSource = destinations!.group(1);
    expect(destinationSource, isNotNull);
    final labels = RegExp(
      r"label: '([^']+)'",
    ).allMatches(destinationSource!).map((match) => match.group(1)).toList();
    expect(labels, ['Map', 'Pack']);
    expect(destinationSource, contains('PlayerActions.openMap'));
    expect(destinationSource, contains('PlayerActions.openPack'));

    expect(template, contains('Map and Pack'));
    expect(template, contains('product actions'));
    expect(template, contains('telemetry'));
    expect(template.toLowerCase(), isNot(contains('four-tab')));

    final nativeExceptions = RegExp(
      r'### 10\.4 Explicit native exceptions(.*?)(?:\n---)',
      dotAll: true,
    ).firstMatch(prd);
    expect(nativeExceptions, isNotNull);
    expect(
      RegExp(r'^- .+$', multiLine: true)
          .allMatches(nativeExceptions!.group(1)!)
          .map((match) => match.group(0))
          .toList(),
      [
        '- `MaterialApp`;',
        '- `Scaffold` and `AppBar` where required structurally;',
        '- `Navigator` and `MaterialPageRoute`;',
        '- `IndexedStack`, `PageView`, scroll views, slivers, layout, gestures, semantics, and focus primitives;',
        '- `RefreshIndicator` where behaviorally required;',
        '- MapLibre and Flutter Canvas/painters;',
        '- native icons;',
        '- custom neutral loading because no `ShadSkeleton` exists;',
        '- custom two-destination navigation because no shadcn navigation component exists.',
      ],
    );
  });

  test('pins shadcn_ui and integrates the Shad root', () {
    final appRoot = read('lib/ui/product_surfaces/app/earth_nova_app.dart');

    expect(
      RegExp(
        r'^\s*shadcn_ui\s*:\s*0\.56\.2\s*$',
        multiLine: true,
      ).hasMatch(pubspec),
      isTrue,
      reason: 'shadcn_ui must be pinned exactly to 0.56.2',
    );
    final lockEntry = RegExp(
      r'^  shadcn_ui:\n(.*?)(?=^  [a-zA-Z0-9_]+:\n)',
      multiLine: true,
      dotAll: true,
    ).firstMatch(pubspecLock);
    expect(lockEntry, isNotNull);
    expect(lockEntry!.group(1), contains('version: "0.56.2"'));
    expect(appRoot, contains("package:shadcn_ui/shadcn_ui.dart"));

    for (final requiredRootContract in const [
      'theme: AppDesignTheme.dark()',
      'themeMode: ThemeMode.dark',
      'theme: Theme.of(context)',
      "supportedLocales: const [Locale('en', 'US')]",
      'GlobalShadLocalizations.delegate',
      'GlobalMaterialLocalizations.delegate',
      'GlobalCupertinoLocalizations.delegate',
      'GlobalWidgetsLocalizations.delegate',
    ]) {
      expect(appRoot, contains(requiredRootContract));
    }
    expect(appRoot, isNot(contains('AppTheme.dark()')));

    expect(
      appRoot,
      matches(
        RegExp(
          r'ShadApp\.custom\([\s\S]*?appBuilder:\s*\([^)]*\)\s*=>\s*MaterialApp\([\s\S]*?builder:\s*\([^)]*\)\s*=>\s*ShadAppBuilder\(',
        ),
      ),
      reason:
          'ShadApp.custom.appBuilder must return MaterialApp whose builder returns ShadAppBuilder',
    );
  });
}
