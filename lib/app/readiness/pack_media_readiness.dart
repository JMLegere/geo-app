import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/domain/entities/item.dart';

final packMediaReadinessProvider = Provider<PackMediaReadiness>(
  (_) => const FlutterPackMediaReadiness(),
);

abstract interface class PackMediaReadiness {
  Future<PackMediaPreparation> prepare(List<Item> items);
}

class PackMediaPreparation {
  const PackMediaPreparation({
    required this.requested,
    required this.decoded,
    required this.fallbacks,
  });

  final int requested;
  final int decoded;
  final int fallbacks;
}

/// Warms every available Pack image before input is admitted.
///
/// A failed or absent image is still ready because Pack has a synchronous,
/// bundled category fallback. Completing only after success/error means later
/// browsing never exposes an indeterminate network-loading state.
class FlutterPackMediaReadiness implements PackMediaReadiness {
  const FlutterPackMediaReadiness();

  @override
  Future<PackMediaPreparation> prepare(List<Item> items) async {
    final urls = <String>{
      for (final item in items)
        if (item.iconUrl case final url? when url.isNotEmpty) url,
      for (final item in items)
        if (item.artUrl case final url? when url.isNotEmpty) url,
    };
    var decoded = 0;
    var fallbacks = items.where((item) {
      return (item.iconUrl == null || item.iconUrl!.isEmpty) &&
          (item.artUrl == null || item.artUrl!.isEmpty);
    }).length;

    await Future.wait([
      for (final url in urls)
        _decode(NetworkImage(url)).then((succeeded) {
          if (succeeded) {
            decoded++;
          } else {
            fallbacks++;
          }
        }),
    ]);
    return PackMediaPreparation(
      requested: urls.length,
      decoded: decoded,
      fallbacks: fallbacks,
    );
  }

  Future<bool> _decode(ImageProvider provider) {
    final completer = Completer<bool>();
    late final ImageStreamListener listener;
    final stream = provider.resolve(ImageConfiguration.empty);
    listener = ImageStreamListener(
      (_, __) {
        if (!completer.isCompleted) completer.complete(true);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.complete(false);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
