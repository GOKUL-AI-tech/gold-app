import 'package:flutter/material.dart';

/// Wraps page content in a centered, max-width container.
///
/// Use this on every screen so the layout looks good on a wide browser
/// (where Flutter would otherwise stretch widgets to the full window
/// width) while still filling the screen on a phone.
class PageContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
