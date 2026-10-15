import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../services/exam_sheet_width_prefs.dart';
import 'exam_sections.dart';

/// Result of closing a section sheet.
/// - [done] = user tapped Done → auto-advance (web step-done-btn)
/// - [dismissed] = X / barrier → no advance
enum ExamSectionClose { done, dismissed }

double _defaultWidth(double screenWidth) =>
    screenWidth >= 900 ? screenWidth * 0.52 : screenWidth * 0.88;

/// Right-side section editor sheet — leaves the live slip visible on the left
/// (web modal-over-canvas parity).
///
/// Client request (2026-10-07): every exam section (C/O, Vision, O/E,
/// Fundus, ...) opens through this one function, so its width was always
/// the same fixed fraction of the screen regardless of how much a given
/// section's fields actually needed — some tables read as cramped/clipped
/// at that width. Now drag-resizable from a handle on the panel's left
/// edge, saved per user (`ExamSheetWidthPrefs`) so one resize applies to
/// every section from then on, in this session and the next.
Future<ExamSectionClose> showExamSectionSheet({
  required BuildContext context,
  required int userId,
  required ExamSection section,
  required Widget Function(BuildContext sheetContext) builder,
  Listenable? listenable,
  String? doneLabel,
}) async {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final savedFraction = await ExamSheetWidthPrefs.instance.getFraction(userId);
  final minWidth = 420.0;
  final maxWidth = (screenWidth - 100.0).clamp(minWidth, screenWidth);
  final initialWidth = (savedFraction != null ? savedFraction * screenWidth : _defaultWidth(screenWidth))
      .clamp(minWidth, maxWidth);

  if (!context.mounted) return ExamSectionClose.dismissed;
  final result = await showGeneralDialog<ExamSectionClose>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) => _ResizableExamSheet(
      userId: userId,
      section: section,
      builder: builder,
      listenable: listenable,
      doneLabel: doneLabel,
      initialWidth: initialWidth,
      minWidth: minWidth,
      maxWidth: maxWidth,
      hasCustomWidth: savedFraction != null,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
  return result ?? ExamSectionClose.dismissed;
}

class _ResizableExamSheet extends StatefulWidget {
  final int userId;
  final ExamSection section;
  final Widget Function(BuildContext) builder;
  final Listenable? listenable;
  final String? doneLabel;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final bool hasCustomWidth;

  const _ResizableExamSheet({
    required this.userId,
    required this.section,
    required this.builder,
    required this.listenable,
    required this.doneLabel,
    required this.initialWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.hasCustomWidth,
  });

  @override
  State<_ResizableExamSheet> createState() => _ResizableExamSheetState();
}

class _ResizableExamSheetState extends State<_ResizableExamSheet> {
  static const double _handleZoneWidth = 14.0;

  late double _width = widget.initialWidth;
  late bool _hasCustomWidth = widget.hasCustomWidth;

  void _onResize(double w) {
    setState(() => _width = w.clamp(widget.minWidth, widget.maxWidth));
  }

  void _onResizeEnd() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    _hasCustomWidth = true;
    ExamSheetWidthPrefs.instance.setFraction(widget.userId, _width / screenWidth);
  }

  void _resetWidth() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    setState(() {
      _width = _defaultWidth(screenWidth).clamp(widget.minWidth, widget.maxWidth);
      _hasCustomWidth = false;
    });
    ExamSheetWidthPrefs.instance.reset(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    Widget body = widget.builder(ctx);
    if (widget.listenable != null) {
      body = AnimatedBuilder(animation: widget.listenable!, builder: (_, _) => widget.builder(ctx));
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
            child: SizedBox(
              width: _width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: _handleZoneWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(-4, 0))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                            child: Row(children: [
                              Expanded(
                                child: Text(widget.section.shortLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ),
                              if (_hasCustomWidth)
                                IconButton(
                                  tooltip: 'Reset panel width',
                                  onPressed: _resetWidth,
                                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
                                  color: AppColors.textSecondary,
                                ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(ctx).pop(ExamSectionClose.dismissed),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ]),
                          ),
                          Divider(height: 1, color: AppColors.primaryA08),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: body,
                            ),
                          ),
                          Divider(height: 1, color: AppColors.primaryA08),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                            child: Row(children: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(ExamSectionClose.dismissed),
                                child: const Text('Close'),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.of(ctx).pop(ExamSectionClose.done),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(widget.doneLabel ?? 'Done'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Left-edge drag handle — dragging left (negative dx)
                  // widens the panel, dragging right narrows it, since the
                  // panel itself is right-aligned. Uses raw pointer events
                  // (`Listener`), not `GestureDetector.onHorizontalDragUpdate`
                  // — the section body scrolls vertically, and a drag
                  // recognizer has to win a gesture-arena contest against
                  // that before it starts reporting deltas, which reads as
                  // "resize works on the 2nd attempt, not the 1st". Same
                  // reasoning `ResizableDashboardBlock` already documents.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: _handleZoneWidth,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerMove: (event) => _onResize(_width - event.delta.dx),
                      onPointerUp: (_) => _onResizeEnd(),
                      onPointerCancel: (_) => _onResizeEnd(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryA22,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
