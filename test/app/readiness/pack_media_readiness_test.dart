import 'dart:async';

import 'package:earth_nova/app/readiness/pack_media_readiness.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterPackMediaReadiness', () {
    testWidgets('deduplicates media and waits for decode outcomes', (
      tester,
    ) async {
      const iconUrl = 'https://assets.test/icon.png';
      const artUrl = 'https://assets.test/art.png';
      const failedUrl = 'https://assets.test/unavailable.png';
      final cache = PaintingBinding.instance.imageCache;
      final iconImage = Completer<ImageInfo>();
      final artImage = Completer<ImageInfo>();
      final failedImage = Completer<ImageInfo>();
      final iconStream = OneFrameImageStreamCompleter(iconImage.future);
      final artStream = OneFrameImageStreamCompleter(artImage.future);
      final failedStream = OneFrameImageStreamCompleter(failedImage.future);
      var iconDetached = false;
      var artDetached = false;
      var failedDetached = false;
      iconStream.addOnLastListenerRemovedCallback(() => iconDetached = true);
      artStream.addOnLastListenerRemovedCallback(() => artDetached = true);
      failedStream.addOnLastListenerRemovedCallback(
        () => failedDetached = true,
      );
      cache.putIfAbsent(NetworkImage(iconUrl), () => iconStream);
      cache.putIfAbsent(NetworkImage(artUrl), () => artStream);
      cache.putIfAbsent(NetworkImage(failedUrl), () => failedStream);
      addTearDown(() {
        cache.evict(NetworkImage(iconUrl));
        cache.evict(NetworkImage(artUrl));
        cache.evict(NetworkImage(failedUrl));
      });

      final preparation = const FlutterPackMediaReadiness().prepare([
        _item(id: 'first', iconUrl: iconUrl, artUrl: artUrl),
        _item(id: 'second', iconUrl: iconUrl, artUrl: failedUrl),
        _item(id: 'third', artUrl: artUrl),
      ]);

      final image = (await tester.runAsync(createTestImage))!;
      iconImage.complete(ImageInfo(image: image));
      artImage.complete(ImageInfo(image: image));
      failedImage.completeError(StateError('image unavailable'));
      await tester.pump();
      final result = await preparation;
      image.dispose();
      cache.evict(NetworkImage(failedUrl));

      expect(result.requested, 3);
      expect(result.decoded, 2);
      expect(result.fallbacks, 1);
      expect(iconDetached, isTrue);
      expect(artDetached, isTrue);
      expect(failedDetached, isTrue);
    });

    test(
      'uses category fallbacks when both Pack media URLs are absent',
      () async {
        final result = await const FlutterPackMediaReadiness().prepare([
          _item(id: 'missing'),
          _item(id: 'blank', iconUrl: '', artUrl: ''),
        ]);

        expect(result.requested, 0);
        expect(result.decoded, 0);
        expect(result.fallbacks, 2);
      },
    );
  });
}

Item _item({required String id, String? iconUrl, String? artUrl}) => Item(
  id: id,
  displayName: id,
  category: ItemCategory.fauna,
  iconUrl: iconUrl,
  artUrl: artUrl,
  acquiredAt: DateTime.utc(2026, 9, 11),
  status: ItemStatus.active,
);
