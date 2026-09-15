import 'package:earth_nova_widgetbook/main.directories.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:earth_nova_widgetbook/support/browser_visual_manifest.dart';

const _defaultViewport = Size(900, 900);
const _fixedPump = Duration(milliseconds: 300);

// These generated leaves require real browser composition. The shared manifest
// is also consumed by the WebDriver capture and comparator, so a native
// exclusion cannot silently lose visual coverage.
final _platformViewOnlyPaths = <String, String>{
  for (final capture in browserVisualCaptures) capture.path: capture.reason,
};

void main() {
  final useCases = _generatedUseCases();
  final captures = _captures(useCases);
  final platformViewPaths = useCases
      .map((useCase) => useCase.path)
      .where(
        (path) =>
            path == 'product-surfaces/map/maprootscreen/00-happy-path' ||
            path.contains('/mapscreen/'),
      )
      .toSet();

  test('MapLibre-only generated paths have explicit browser reasons', () {
    expect(
      platformViewPaths,
      equals(_platformViewOnlyPaths.keys.toSet()),
      reason:
          'Every MapScreen or MapRootScreen generated path must have an exact '
          'browser-only reason before native golden coverage can skip it.',
    );
    expect(
      browserVisualCaptures.map((capture) => capture.name).toSet().length,
      browserVisualCaptures.length,
      reason: 'Browser capture filenames must be unique.',
    );
    for (final path in platformViewPaths) {
      expect(
        browserVisualCaptures
            .where((capture) => capture.path == path)
            .map((capture) => capture.viewport)
            .toSet(),
        {'wide', 'narrow'},
        reason: '$path must cover both required browser viewports.',
      );
    }
  });

  for (final capture in captures) {
    testWidgets('native golden ${capture.fileName}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = capture.viewport;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        Widgetbook.material(
          directories: directories,
          initialRoute: _routeFor(capture.useCase.path),
        ),
      );
      await tester.pump(_fixedPump);

      await expectLater(
        find.byType(Widgetbook),
        matchesGoldenFile('goldens/native/${capture.fileName}.png'),
      );
    });
  }
}

List<WidgetbookUseCase> _generatedUseCases() {
  final root = WidgetbookRoot(children: directories);
  final useCases = root.leaves.whereType<WidgetbookUseCase>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return useCases;
}

List<_GoldenCapture> _captures(List<WidgetbookUseCase> useCases) {
  final captures = <_GoldenCapture>[];
  final names = <String>{};
  for (final useCase in useCases) {
    if (_platformViewOnlyPaths.containsKey(useCase.path)) continue;

    captures.add(_GoldenCapture(useCase, _defaultViewport, 'default'));
    for (final boundary in _boundaryViewports(useCase.path)) {
      captures.add(_GoldenCapture(useCase, boundary.viewport, boundary.name));
    }
  }

  for (final capture in captures) {
    if (!names.add(capture.fileName)) {
      throw StateError('Duplicate native golden filename: ${capture.fileName}');
    }
  }
  return captures;
}

Iterable<_Viewport> _boundaryViewports(String path) {
  if (path.contains('/appstatgrid/')) {
    return const [
      _Viewport('width-419', Size(419, 900)),
      _Viewport('width-420', Size(420, 900)),
    ];
  }
  if (path.contains('/packscreen/')) {
    return const [
      _Viewport('width-599', Size(599, 900)),
      _Viewport('width-600', Size(600, 900)),
      _Viewport('width-899', Size(899, 900)),
      _Viewport('width-900', Size(900, 900)),
    ];
  }
  if (path.contains('/map/') || path.contains('/tabshell/')) {
    return const [
      _Viewport('narrow', Size(390, 844)),
      _Viewport('wide', Size(1440, 900)),
    ];
  }
  return const [];
}

String _routeFor(String path) => Uri(
  path: '/',
  queryParameters: {'path': path, 'preview': 'true'},
).toString();

class _GoldenCapture {
  const _GoldenCapture(this.useCase, this.viewport, this.variant);

  final WidgetbookUseCase useCase;
  final Size viewport;
  final String variant;

  String get fileName => '${useCase.path.replaceAll('/', '__')}--$variant';
}

class _Viewport {
  const _Viewport(this.name, this.viewport);

  final String name;
  final Size viewport;
}
