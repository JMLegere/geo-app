import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/presentation/platform/map_style_label_layers.dart';

void main() {
  group('baseMapTextLabelLayerIdsFromStyle', () {
    test('returns symbol layers that contain a text-field layout property', () {
      const styleJson = '''
{
  "version": 8,
  "layers": [
    {"id": "water", "type": "fill"},
    {"id": "poi-icon", "type": "symbol", "layout": {"icon-image": "park"}},
    {"id": "road-label", "type": "symbol", "layout": {"text-field": ["get", "name"]}},
    {"id": "place-label", "type": "symbol", "layout": {"text-field": "{name}"}}
  ]
}
''';

      expect(
        baseMapTextLabelLayerIdsFromStyle(styleJson),
        ['road-label', 'place-label'],
      );
    });

    test('returns empty list for invalid or label-free style JSON', () {
      expect(baseMapTextLabelLayerIdsFromStyle('not-json'), isEmpty);
      expect(baseMapTextLabelLayerIdsFromStyle('{"layers": []}'), isEmpty);
    });
  });
}
