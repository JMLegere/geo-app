import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  final shadcnUiDeclared = RegExp(
    r'^\s*shadcn_ui\s*:',
    multiLine: true,
  ).hasMatch(pubspec);

  String read(String path) => File('$root/$path').readAsStringSync();

  test('preserves the Phase 0 migration contract', () {
    final appRoot = read('lib/main.dart');
    final tabShell = read('lib/shared/widgets/tab_shell.dart');
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
    expect(appRoot, contains('authenticated: (user) => AppReadinessGate('));
    expect(appRoot, contains('loading: () => const LoadingScreen()'));
    expect(appRoot, contains('unauthenticated: () => const LoginScreen()'));
    expect(appRoot, contains('error: (_) => const LoginScreen()'));

    final destinations = RegExp(
      r'const _bottomNavItems = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(tabShell);
    expect(destinations, isNotNull);
    final destinationSource = destinations!.group(1);
    expect(destinationSource, isNotNull);
    final labels = RegExp(r"label: '([^']+)'")
        .allMatches(destinationSource!)
        .map((match) => match.group(1))
        .toList();
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

  test(
    'integrates the Shad root when shadcn_ui is declared',
    () {
      final appRoot = read('lib/main.dart');

      expect(
        RegExp(r'^\s*shadcn_ui\s*:\s*0\.56\.2\s*$', multiLine: true)
            .hasMatch(pubspec),
        isTrue,
        reason: 'shadcn_ui must be pinned exactly to 0.56.2',
      );
      expect(appRoot, contains("package:shadcn_ui/shadcn_ui.dart"));

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
    },
    skip: !shadcnUiDeclared,
  );
}
