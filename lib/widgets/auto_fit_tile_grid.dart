import 'package:flutter/material.dart';

/// Fits as many tiles per row as [tileWidth] allows, then gives each tile
/// an equal share of the row so leftover space does not sit as an empty
/// strip on the right. [tileWidth] is the minimum: a wide pane gets more
/// columns instead of two stretched cards.
class AutoFitTileGrid extends StatelessWidget {
  final List<Widget> children;
  final double tileWidth;
  final double spacing;
  final double runSpacing;

  const AutoFitTileGrid({super.key, required this.children, required this.tileWidth, this.spacing = 10, this.runSpacing = 10});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      if (!maxW.isFinite || maxW <= 0 || children.isEmpty) {
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [for (final child in children) SizedBox(width: tileWidth, child: child)],
        );
      }
      final cols = ((maxW + spacing) / (tileWidth + spacing)).floor().clamp(1, 100);
      final width = (maxW - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}
