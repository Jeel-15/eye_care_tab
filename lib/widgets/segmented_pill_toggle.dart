import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import 'app_animations.dart';

/// One option in a [SegmentedPillToggle].
typedef SegmentOption<T> = ({T value, String label});

/// The rounded pill segmented-control every "Today / All X" or "Pending /
/// Refunds / Completed"-style toggle in this app uses — factored out of
/// `PatientsScreen`'s original 2-option `_segmentedToggle`/`_segBtn` (now
/// generalized to any number of options and any `T` value type) so OT
/// Accountant's 3-way Pending/Refunds/Completed toggle reuses the exact
/// same widget instead of a second hand-written copy. Colors default to
/// this app's own light-background convention; pass `trackColor`/
/// `activeColor`/text colors to adapt it for a colored header bar (e.g.
/// light-on-primary, as OT Accountant's does).
class SegmentedPillToggle<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color? trackColor;
  final Color? activeColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;

  const SegmentedPillToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.trackColor,
    this.activeColor,
    this.activeTextColor,
    this.inactiveTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? AppColors.background;
    final active = activeColor ?? AppColors.primary;
    final activeText = activeTextColor ?? Colors.white;
    final inactiveText = inactiveTextColor ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isActive = opt.value == selected;
          return PressScaleWrapper(
            onTap: () => onChanged(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(color: isActive ? active : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.sm)),
              alignment: Alignment.center,
              child: Text(opt.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? activeText : inactiveText)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
