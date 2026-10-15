import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// Wraps a dashboard block (My Primary Queue / Revenue Overview / Reception
/// — Today) with a drag handle on its trailing edge so the user can narrow
/// or widen it. Meant to sit inside a `Wrap`, not a `Row` — narrowing a
/// block just frees width for whatever comes after it to move up onto the
/// same line (or wrap to the next one), so there's no separate "position"
/// to manage.
///
/// [width] is the block's current width in px (the caller owns and persists
/// this value — see `DashboardLayoutPrefs` — this widget only reports drag
/// deltas). [onResize] fires continuously while dragging so the caller can
/// give live visual feedback; [onResizeEnd] fires once, on release, which is
/// when the caller should actually persist the value (avoids a
/// SharedPreferences write on every drag-update tick).
///
/// The handle tracks raw pointer events (`Listener`) rather than
/// `GestureDetector.onHorizontalDragUpdate` — the dashboard body scrolls
/// vertically (`SingleChildScrollView` + `RefreshIndicator`), and a
/// `GestureDetector`'s drag recognizer has to win a "gesture arena" contest
/// against that ancestor's vertical drag recognizer before it starts
/// reporting deltas. Any touch that isn't perfectly horizontal in its very
/// first few pixels (routine on a touchscreen) could lose that contest to
/// the scroll view, which is exactly the "works on the 2nd attempt, not the
/// 1st" symptom this replaces. `Listener` doesn't enter the arena at all —
/// it fires for every pointer event that hits it, so the resize starts
/// immediately and reliably on the very first touch.
class ResizableDashboardBlock extends StatelessWidget {
  static const double handleZoneWidth = 18.0;

  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onResize;
  final VoidCallback onResizeEnd;

  /// -1 moves this block left, +1 moves it right. Null when it is the only
  /// block, so the grip is not shown.
  final ValueChanged<int>? onMove;
  final Widget child;

  const ResizableDashboardBlock({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    required this.onResizeEnd,
    this.onMove,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // The handle's width is reserved out of the block's own declared width
    // (not overflowed into the Wrap's gap via a negative offset) so its hit
    // area is always fully inside this widget's own bounds — no reliance on
    // an ancestor not clipping an overflowing child.
    final moveZone = onMove == null ? 0.0 : handleZoneWidth;
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(left: moveZone, right: handleZoneWidth),
            child: child,
          ),
          if (onMove != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: handleZoneWidth,
              child: _MoveGrip(onMove: onMove!),
            ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: handleZoneWidth,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerMove: (event) {
                final next = (width + event.delta.dx).clamp(minWidth, maxWidth);
                onResize(next);
              },
              onPointerUp: (_) => onResizeEnd(),
              onPointerCancel: (_) => onResizeEnd(),
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
    );
  }
}

/// Horizontal drag on the block's left edge. A vertical scroll still owns
/// the rest of the card. The swap happens on release, once the drag has
/// clearly gone left or right.
class _MoveGrip extends StatefulWidget {
  final ValueChanged<int> onMove;
  const _MoveGrip({required this.onMove});

  @override
  State<_MoveGrip> createState() => _MoveGripState();
}

class _MoveGripState extends State<_MoveGrip> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _dx = 0,
      onPointerMove: (event) => _dx += event.delta.dx,
      onPointerUp: (_) => _finish(),
      onPointerCancel: (_) => _dx = 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Center(
          child: Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.primaryA22),
        ),
      ),
    );
  }

  void _finish() {
    if (_dx >= 48) {
      widget.onMove(1);
    } else if (_dx <= -48) {
      widget.onMove(-1);
    }
    _dx = 0;
  }
}
