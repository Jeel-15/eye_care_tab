/// Shared input/button styling for every add/edit form dialog in the tablet
/// app — extracted from the Patient Add/Edit form redesign (the first form
/// this pattern was proven on, per the user's explicit "test one form, then
/// roll it out everywhere" plan) so every other form (master CRUD dialogs,
/// OT workflow dialogs, User/Hospital forms) renders identically instead of
/// each screen hand-rolling its own InputDecoration/button shape.
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// Floating-label field decoration — label sits inside the field at rest,
/// floats above it on focus; [hint] (an example) only becomes visible once
/// focused, so it never duplicates the label's own text. Rounded
/// [AppRadius.md] border, filled white (or a faint tint when [readOnly]).
InputDecoration appFieldDecoration(String? label, {String? hint, IconData? prefix, Widget? suffix, bool readOnly = false}) {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA18));
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontSize: 13, color: AppColors.primaryA55),
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: AppColors.primaryA35),
    prefixIcon: prefix != null ? Icon(prefix, size: 18, color: AppColors.primaryA50) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: readOnly ? AppColors.primaryA04 : Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.red)),
    focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
  );
}

/// Primary Save/Add/Update button — rounded [AppRadius.md] corners (not the
/// old stadium/pill shape some forms used), shows a spinner in place of its
/// label while [loading].
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  /// Defaults to [AppColors.primary] — master-data dialogs pass their own
  /// per-type accent color (the same one the Masters hub grid uses for that
  /// item) so the button still matches its section's color-coding.
  final Color? color;

  const AppPrimaryButton({super.key, required this.label, this.icon, this.loading = false, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primary;
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: resolvedColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: resolvedColor.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
    );
  }
}

/// Secondary Cancel/Close button — outlined, the same [AppRadius.md]
/// corners as [AppPrimaryButton] so the pair always matches.
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppSecondaryButton({super.key, this.label = 'Cancel', required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        side: BorderSide(color: AppColors.primaryA22),
      ),
      child: Text(label),
    );
  }
}

/// Header for every form dialog, small or large — the Patient form's look:
/// a colored icon tile, dark title + subtitle, and a close button on the
/// right, over a hairline divider. It has no background of its own, so it
/// sits cleanly on both [AppDialog] and legacy `AlertDialog` surfaces.
class AppDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  /// Hidden when null (e.g. while saving).
  final VoidCallback? onClose;
  /// Icon-tile fill. Defaults to the primary→blueLight gradient — master
  /// dialogs pass `[accentColor, accentColor]` for their section color,
  /// destructive dialogs pass reds.
  final List<Color>? colors;
  /// Replaces the icon tile.
  final Widget? leading;
  final String? subtitle;
  /// Shown before the close button — typically a status [Pill].
  final Widget? trailing;

  const AppDialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.onClose,
    this.colors,
    this.leading,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tile = colors ?? [AppColors.primary, AppColors.blueLight];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA08))),
      child: Row(children: [
        leading ??
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tile, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [BoxShadow(color: tile.first.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.darkNavy, fontSize: 16.5, fontWeight: FontWeight.w800)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        if (onClose != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: onClose,
          ),
        ],
      ]),
    );
  }
}

/// `raj sth` → `RS`, `Admin` → `A`, blank → `?`.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.length == 1 ? parts[0][0] : '${parts[0][0]}${parts[1][0]}').toUpperCase();
}

/// On/off setting (Active, Favourite, ...) drawn as a bordered tile the same
/// height and radius as an [appFieldDecoration] field, so it lines up with
/// the fields around it. The whole tile is the tap target.
class AppSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;

  const AppSwitchTile({super.key, required this.label, this.subtitle, required this.value, required this.onChanged, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Material(
      color: value ? accent.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: value ? accent.withValues(alpha: 0.35) : AppColors.primaryA18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.darkNavy)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ]),
            ),
            Switch(value: value, activeThumbColor: accent, onChanged: onChanged),
          ]),
        ),
      ),
    );
  }
}

/// Lays form fields side by side, sized by [flex] (e.g. `[3, 1]` for a long
/// name next to a short percentage), and stacks them once the row is
/// narrower than [stackBelow].
class AppFormRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double stackBelow;
  final double gap;

  const AppFormRow({super.key, required this.children, this.flex, this.stackBelow = 360, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < stackBelow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: flex != null && i < flex!.length ? flex![i] : 1, child: children[i]),
        ],
      ]);
    });
  }
}
