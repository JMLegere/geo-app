import 'package:earth_nova/ui/product_surfaces/debug/debug_gesture_overlay.dart';
import 'package:earth_nova_widgetbook/fixtures/debug_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

Widget _overlayStory({
  void Function(DebugPlayerMoveDirection direction)? onMovePlayer,
  VoidCallback? onResumeGps,
  VoidCallback? onMovePlayerToUnvisited,
}) => earthNovaStory(
  child: Scaffold(
    body: Stack(
      children: [
        const Center(child: Text('Debug target surface')),
        DebugGestureOverlay(
          injector: StoryGestureInjector(),
          onMovePlayer: onMovePlayer,
          onResumeGps: onResumeGps,
          onMovePlayerToUnvisited: onMovePlayerToUnvisited,
        ),
      ],
    ),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: DebugGestureOverlay,
  path: '[Product Surfaces]/Debug',
)
Widget debugGestureOverlayHappyPath(BuildContext context) => _overlayStory();

@widgetbook.UseCase(
  name: '10 Player Controls',
  type: DebugGestureOverlay,
  path: '[Product Surfaces]/Debug',
)
Widget debugGestureOverlayPlayerControls(BuildContext context) => _overlayStory(
  onMovePlayer: (_) {},
  onResumeGps: () {},
  onMovePlayerToUnvisited: () {},
);

@widgetbook.UseCase(
  name: '20 Collapsed',
  type: DebugGestureOverlay,
  path: '[Product Surfaces]/Debug',
)
Widget debugGestureOverlayCollapsed(BuildContext context) => earthNovaStory(
  child: Scaffold(
    body: Stack(
      children: [
        const Center(child: Text('Debug target surface')),
        const _CollapsedDebugGestureOverlay(),
      ],
    ),
  ),
);

class _CollapsedDebugGestureOverlay extends StatefulWidget {
  const _CollapsedDebugGestureOverlay();

  @override
  State<_CollapsedDebugGestureOverlay> createState() =>
      _CollapsedDebugGestureOverlayState();
}

class _CollapsedDebugGestureOverlayState
    extends State<_CollapsedDebugGestureOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visitDescendants(context, (element) {
        final widget = element.widget;
        if (widget is InkWell &&
            widget.key == const Key('debug_overlay_toggle')) {
          widget.onTap?.call();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) =>
      DebugGestureOverlay(injector: StoryGestureInjector());
}

void _visitDescendants(
  BuildContext context,
  void Function(Element element) visit,
) {
  void walk(Element element) {
    visit(element);
    element.visitChildElements(walk);
  }

  context.visitChildElements(walk);
}
