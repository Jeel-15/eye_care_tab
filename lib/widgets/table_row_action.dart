import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// Meaning of a table-row icon. The color is fixed so the same action
/// reads the same on every screen.
enum TableActionKind { view, edit, delete, history, print, positive }

/// Weight of a labeled row action.
///
/// [primary] and [teal] are filled. The rest are outlined.
enum TableLabelTone { primary, secondary, danger, teal, positive }

/// 34px tinted icon for a table or list row (View, Edit, Delete, Print…).
class TableIconAction extends StatelessWidget {
  const TableIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.kind = TableActionKind.view,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final TableActionKind kind;

  static const double size = 34;

  Color get _color => switch (kind) {
        TableActionKind.view || TableActionKind.print => AppColors.primary,
        TableActionKind.edit => AppColors.orange,
        TableActionKind.delete => AppColors.red,
        TableActionKind.history => AppColors.teal,
        TableActionKind.positive => AppColors.green,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: enabled ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 18, color: enabled ? color : color.withValues(alpha: 0.4)),
          ),
        ),
      ),
      ),
    );
  }
}

/// 34px labeled row action (Examine, Check In, View, Add Payment…).
class TableLabelAction extends StatelessWidget {
  const TableLabelAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tone = TableLabelTone.secondary,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final TableLabelTone tone;
  final bool busy;

  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final filled = tone == TableLabelTone.primary || tone == TableLabelTone.teal;
    final accent = switch (tone) {
      TableLabelTone.primary || TableLabelTone.secondary => AppColors.primary,
      TableLabelTone.teal => AppColors.teal,
      TableLabelTone.danger => AppColors.red,
      TableLabelTone.positive => AppColors.green,
    };
    final fg = filled ? Colors.white : accent;
    final enabled = onTap != null && !busy;
    final paint = enabled ? fg : fg.withValues(alpha: 0.4);
    return Material(
      color: filled ? (enabled ? accent : accent.withValues(alpha: 0.45)) : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: filled ? null : Border.all(color: accent.withValues(alpha: enabled ? 0.35 : 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (busy)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: paint))
            else if (icon != null)
              Icon(icon, size: 16, color: paint),
            if (busy || icon != null) const SizedBox(width: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: paint)),
          ]),
        ),
      ),
    );
  }
}

/// One line of row actions. The row is only as wide as the buttons, so the
/// table can stop its horizontal scroll at the last button.
class ActionCluster extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ActionCluster({super.key, required this.children, this.spacing = 6});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: spacing),
        children[i],
      ],
    ]);
  }
}

/// Old desk buttons passed a raw color. Map that onto a tone so every
/// caller of [deskTableActionBtn] picks up the shared control.
TableLabelTone tableLabelToneFor(Color? color) {
  if (color == AppColors.red || color == AppColors.redDark) return TableLabelTone.danger;
  if (color == AppColors.teal || color == AppColors.tealDark) return TableLabelTone.teal;
  if (color == AppColors.green || color == AppColors.waitGreen) return TableLabelTone.positive;
  if (color == AppColors.primary) return TableLabelTone.primary;
  return TableLabelTone.secondary;
}
