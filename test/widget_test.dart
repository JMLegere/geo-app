import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/map/map_screen.dart';
import 'package:fog_of_world/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // FogOfWorldApp uses ConsumerWidgets (Riverpod) so it needs a ProviderScope.
    await tester.pumpWidget(const ProviderScope(child: FogOfWorldApp()));

    // MapLibreMap is a platform view (native map renderer). It throws
    // UnimplementedError in the headless Flutter test environment because
    // there is no real iOS/Android platform to host it. This is expected
    // behaviour — the error is caught by the Widgets library, not a sign of
    // a bug in our code.
    //
    // We clear the exception so the test can still verify the screen
    // scaffolding is correct.
    tester.takeException();

    // The MapScreen widget itself is present in the widget tree.
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
