import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Converts held desktop movement keys into normalized metre deltas.
class DesktopTraversalInput extends StatefulWidget {
  const DesktopTraversalInput({
    required this.child,
    required this.enabled,
    required this.blocked,
    required this.onMove,
    required this.onMovementEnded,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final bool blocked;
  final void Function(double north, double east) onMove;
  final VoidCallback onMovementEnded;

  @override
  State<DesktopTraversalInput> createState() => _DesktopTraversalInputState();
}

class _DesktopTraversalInputState extends State<DesktopTraversalInput>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _metresPerSecond = 100.0;

  final _focusNode = FocusNode(debugLabel: 'desktop-traversal');
  final _pressedKeys = <LogicalKeyboardKey>{};
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  bool get _canMove => widget.enabled && !widget.blocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_handleFocusChanged);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant DesktopTraversalInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_canMove) return;
    _stopMovement();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopMovement();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _stopMovement();
    _ticker.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) _stopMovement();
  }

  void _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    if (_directionFor(key) == null) return;

    if (event is KeyDownEvent) {
      if (!_canMove || !_pressedKeys.add(key)) return;
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
      if (_pressedKeys.isEmpty) _stopMovement();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_canMove || _pressedKeys.isEmpty) {
      _stopMovement();
      return;
    }

    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    if (delta <= Duration.zero) return;

    var north = 0.0;
    var east = 0.0;
    for (final key in _pressedKeys) {
      final direction = _directionFor(key)!;
      north += direction.$1;
      east += direction.$2;
    }
    final magnitude = math.sqrt(north * north + east * east);
    if (magnitude == 0) return;

    final metres = _metresPerSecond *
        delta.inMicroseconds /
        Duration.microsecondsPerSecond;
    widget.onMove(north / magnitude * metres, east / magnitude * metres);
  }

  void _stopMovement() {
    final wasMoving = _pressedKeys.isNotEmpty || _ticker.isActive;
    _pressedKeys.clear();
    _ticker.stop();
    _lastTick = Duration.zero;
    if (wasMoving) widget.onMovementEnded();
  }

  (double, double)? _directionFor(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.keyW || LogicalKeyboardKey.arrowUp => (1, 0),
      LogicalKeyboardKey.keyS || LogicalKeyboardKey.arrowDown => (-1, 0),
      LogicalKeyboardKey.keyA || LogicalKeyboardKey.arrowLeft => (0, -1),
      LogicalKeyboardKey.keyD || LogicalKeyboardKey.arrowRight => (0, 1),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_canMove) _focusNode.requestFocus();
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: widget.enabled,
        onKeyEvent: _handleKeyEvent,
        child: widget.child,
      ),
    );
  }
}
