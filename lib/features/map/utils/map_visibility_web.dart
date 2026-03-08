import 'dart:async';
import 'dart:developer' as developer;

import 'package:web/web.dart';

import 'map_visibility.dart';

MapVisibility createMapVisibility() => _WebMapVisibility();

/// Web implementation: manipulates the DOM directly to hide/reveal the
/// MapLibre platform view.
///
/// On Flutter web (CanvasKit), [HtmlElementView] widgets render in a separate
/// HTML DOM layer above Flutter's canvas. A CSS `<style>` rule is the ONLY
/// reliable way to hide the element from the moment it's created — inline
/// styles or Flutter opacity widgets cannot prevent the initial frame flash.
class _WebMapVisibility implements MapVisibility {
  static const _styleId = 'fog-hide-map';

  /// Max retries for [revealMapContainer] when querySelector returns null.
  static const _maxRevealRetries = 5;

  /// Delay between reveal retries. Gives the DOM time to create the element.
  static const _retryDelay = Duration(milliseconds: 100);

  Timer? _retryTimer;

  @override
  void hideMapContainer() {
    // Avoid duplicate injection if called multiple times.
    if (document.getElementById(_styleId) != null) return;

    final style = document.createElement('style') as HTMLStyleElement;
    style.id = _styleId;
    // Hide all MapLibre containers. The transition is defined here so it's
    // already active when we later change opacity via inline style override.
    style.textContent =
        '.maplibregl-map { opacity: 0; transition: opacity 300ms ease; }';
    document.head?.appendChild(style);
  }

  @override
  void revealMapContainer() {
    _retryTimer?.cancel();
    _tryReveal(attempt: 0);
  }

  void _tryReveal({required int attempt}) {
    // Inline styles have higher specificity than class selectors, so setting
    // style.opacity = '1' overrides the stylesheet rule while the CSS
    // transition defined by the rule animates the change smoothly.
    final el = document.querySelector('.maplibregl-map') as HTMLElement?;
    if (el != null) {
      el.style.opacity = '1';
      // Clean up the injected style tag — no longer needed once revealed.
      document.getElementById(_styleId)?.remove();
      return;
    }

    // querySelector returned null — the MapLibre container isn't in the DOM
    // yet. Retry after a short delay to give Flutter's platform view time
    // to create the element.
    if (attempt < _maxRevealRetries) {
      developer.log(
        'revealMapContainer: querySelector returned null, retry #${attempt + 1}',
        name: 'map.MAP',
      );
      _retryTimer = Timer(_retryDelay, () {
        _tryReveal(attempt: attempt + 1);
      });
    } else {
      // All retries exhausted. Remove the hide stylesheet as a fallback —
      // the element will get its default opacity when it finally appears.
      developer.log(
        'revealMapContainer: failed after $_maxRevealRetries retries — '
        'removing hide stylesheet as fallback',
        name: 'map.MAP',
        level: 1000,
      );
      document.getElementById(_styleId)?.remove();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    document.getElementById(_styleId)?.remove();
  }
}
