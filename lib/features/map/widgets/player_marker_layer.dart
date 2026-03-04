import 'package:flutter/widgets.dart';
import 'package:maplibre/maplibre.dart';

import 'package:fog_of_world/features/map/layers/player_marker_widget.dart';

/// Renders the player marker via a [WidgetLayer] without triggering a full
/// [MapScreen] rebuild on every 60fps frame.
///
/// The [position] [ValueNotifier] is updated at ~60 fps by the
/// [RubberBandController]. [ValueListenableBuilder] scopes rebuilds to this
/// widget only — the rest of the [MapScreen] tree stays stable at its own
/// (much lower) rebuild cadence.
///
/// ## MapLibre API note
/// `Position(lng, lat)` — longitude FIRST, latitude second.
class PlayerMarkerLayer extends StatelessWidget {
  /// Interpolated display position from the rubber-band controller.
  ///
  /// `null` until the first GPS fix arrives. When `null` this widget renders
  /// as [SizedBox.shrink] so no empty [WidgetLayer] is added to the map.
  final ValueNotifier<({double lat, double lon})?> position;

  const PlayerMarkerLayer({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<({double lat, double lon})?>(
      valueListenable: position,
      builder: (context, pos, child) {
        if (pos == null) return const SizedBox.shrink();

        return WidgetLayer(
          markers: [
            Marker(
              // Position(lng, lat) — longitude FIRST!
              // Uses the rubber-band interpolated position (60fps smooth).
              point: Position(pos.lon, pos.lat),
              size: const Size(44, 44),
              child: const PlayerMarkerWidget(size: 20),
            ),
          ],
        );
      },
    );
  }
}
