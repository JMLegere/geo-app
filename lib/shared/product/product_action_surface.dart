import 'package:flutter/widgets.dart';

/// Invisible EAC evidence wrapper for clickable UI that is not itself a
/// design button component.
///
/// A string [actionId] maps the wrapped control to a product action. A null
/// [actionId] is an explicit decision that the control is local chrome,
/// debug-only, or otherwise not a product action.
class ProductActionSurface extends StatelessWidget {
  const ProductActionSurface({
    required this.actionId,
    required this.child,
    super.key,
  });

  final String? actionId;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
