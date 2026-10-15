import 'package:flutter/material.dart';

/// Anchored popover mechanism used by every exam-field picker (Phase 4b/4c
/// decision — see EXAMINATIONS_MODULE_PRD.md §8.2: pickers open as a popover
/// anchored to their field, not a bottom sheet / full-screen dialog like
/// mobile. One controller per field; wrap the field in
/// `CompositedTransformTarget(link: controller.link, child: ...)`.
class PopoverController {
  final LayerLink link = LayerLink();
  OverlayEntry? _entry;

  bool get isOpen => _entry != null;

  /// Positions the popover relative to the field's actual on-screen Rect
  /// (via the calling field's own RenderBox) instead of a blind fixed
  /// offset, and keeps it fully inside the safe viewport — flipping above
  /// the field when there isn't enough room below, and clamping
  /// horizontally so it never renders under the system nav bar / status bar
  /// or gets clipped off the left/right screen edge.
  void show(BuildContext context, WidgetBuilder builder, {double width = 340, double maxHeight = 420}) {
    close();
    final overlay = Overlay.of(context);
    const gap = 6.0;
    const edgeInset = 8.0;
    // Extra bottom clearance beyond MediaQuery's own reported inset — on
    // Windows desktop (used for dev/testing this tablet app) the OS
    // taskbar isn't reported as a view padding at all, so without this the
    // popover computes a "safe" bottom that the taskbar then draws over.
    // Harmless slack on real tablets, where the system nav bar IS reported.
    const bottomEdgeInset = 56.0;
    const preferredMinHeight = 200.0;
    // Absolute floor so the popover never shrinks to an unusably tiny
    // sliver — picking whichever side (above/below) has more room already
    // minimizes how often this floor causes any overflow, and by how much.
    const hardFloor = 80.0;

    var targetAnchor = Alignment.bottomLeft;
    var followerAnchor = Alignment.topLeft;
    var followerOffset = const Offset(0, gap);
    var effectiveMaxHeight = maxHeight;

    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox && renderBox.hasSize) {
      final media = MediaQuery.of(context);
      final screenSize = media.size;
      final viewPadding = media.padding;
      final anchorTopLeft = renderBox.localToGlobal(Offset.zero);
      final anchorSize = renderBox.size;

      final safeLeft = viewPadding.left + edgeInset;
      final safeRight = screenSize.width - viewPadding.right - edgeInset;
      final safeTop = viewPadding.top + edgeInset;
      final safeBottom = screenSize.height - viewPadding.bottom - bottomEdgeInset;

      final spaceBelow = safeBottom - (anchorTopLeft.dy + anchorSize.height) - gap;
      final spaceAbove = anchorTopLeft.dy - gap - safeTop;
      final openAbove = spaceBelow < preferredMinHeight && spaceAbove > spaceBelow;

      if (openAbove) {
        targetAnchor = Alignment.topLeft;
        followerAnchor = Alignment.bottomLeft;
        effectiveMaxHeight = spaceAbove.clamp(hardFloor, maxHeight);
        followerOffset = const Offset(0, -gap);
      } else {
        effectiveMaxHeight = spaceBelow.clamp(hardFloor, maxHeight);
      }

      double dx = 0;
      final wouldBeRight = anchorTopLeft.dx + width;
      if (wouldBeRight > safeRight) dx = safeRight - wouldBeRight;
      if (anchorTopLeft.dx + dx < safeLeft) dx = safeLeft - anchorTopLeft.dx;
      followerOffset = Offset(dx, followerOffset.dy);
    }

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: close)),
          CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            targetAnchor: targetAnchor,
            followerAnchor: followerAnchor,
            offset: followerOffset,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: effectiveMaxHeight),
                child: builder(ctx),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  void close() {
    _entry?.remove();
    _entry = null;
  }

  void dispose() => close();
}
