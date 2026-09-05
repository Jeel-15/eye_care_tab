import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';

/// Shared Pattern-A responsive list+detail switcher — pure layout, owns no
/// state. The caller computes `showDetail` however it already does (a
/// nullable-selected check, a pane-mode enum, multiple fields) and supplies
/// `onBack` to reset it; this widget only arranges `listPane`/`detailPane`,
/// which remain fully self-contained and already styled by each screen's own
/// `_buildListPane()`/`_buildDetailPane()`. Extracted 2026-08-26 from 14
/// screens that had hand-rolled this exact shape with 4 points of real
/// variation (list-pane width, gap, back-button label, and the
/// showDetail/onBack expressions themselves) — see
/// CODE_NORMALIZATION_FIX_PLAN.md Phase 5 for the verified per-screen values.
class SplitPaneScaffold extends StatelessWidget {
  final bool showDetail;
  final VoidCallback onBack;
  final Widget listPane;
  final Widget detailPane;
  final String backLabel;
  final double listPaneWidth;
  final double gap;

  const SplitPaneScaffold({
    super.key,
    required this.showDetail,
    required this.onBack,
    required this.listPane,
    required this.detailPane,
    this.backLabel = 'Back to list',
    required this.listPaneWidth,
    this.gap = 20,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      if (!splitView) {
        return showDetail
            ? Column(children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(backLabel),
                ),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: listPaneWidth, child: listPane),
        SizedBox(width: gap),
        Expanded(child: detailPane),
      ]);
    });
  }
}
