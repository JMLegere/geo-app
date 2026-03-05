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

  @override
  void hideMapContainer() {
    // Avoid duplicate injection if called multiple times.
    if (document.getElementById(_styleId) != null) return;

    final style = document.createElement('style') as HTMLStyleElement;
    style.id = _styleId;
    // Hide all MapLibre containers. The transition is defined here so it's
    // already active when we later change opacity via inline style override.
    style.textContent = '.maplibregl-map { opacity: 0; transition: opacity 300ms ease; }';
    document.head?.appendChild(style);
  }

  @override
  void revealMapContainer() {
    // Inline styles have higher specificity than class selectors, so setting
    // style.opacity = '1' overrides the stylesheet rule while the CSS
    // transition defined by the rule animates the change smoothly.
    final el = document.querySelector('.maplibregl-map') as HTMLElement?;
    if (el != null) {
      el.style.opacity = '1';
    }

    // Clean up the injected style tag — no longer needed once revealed.
    document.getElementById(_styleId)?.remove();
  }

  @override
  void dispose() {
    document.getElementById(_styleId)?.remove();
  }
}
