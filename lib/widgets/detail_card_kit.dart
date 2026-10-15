/// Shared visual language for the tablet's "detail/view" dialogs — Patient
/// View (`patients_screen.dart`), Patient History (`patient_history_screen
/// .dart`), and any future module of the same shape (OT booking detail,
/// partner hospital detail, ...). Extracted so every such dialog looks and
/// behaves consistently instead of each screen hand-rolling its own
/// avatar/card/badge styling that quietly drifts apart over time.
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import 'app_animations.dart';
import 'form_kit.dart' show initialsOf;

/// Gradient initials avatar — decorative identity marker for whatever
/// entity the dialog is about (patient, hospital, booking...).
class GradientAvatar extends StatelessWidget {
  final String name;
  final double size;
  final List<Color>? colors;

  const GradientAvatar(this.name, {super.key, this.size = 44, this.colors});

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final grad = colors ?? [AppColors.primary, AppColors.blueLight];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: grad.first.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.34)),
    );
  }
}

/// Small rounded status/type badge — every pill in these dialogs (type
/// badges, "Same as mobile" fallbacks, exam-progress status) is one of these
/// so they all share the same shape and weight.
class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final bool outlined;

  const Pill(this.text, {super.key, required this.bg, required this.fg, this.outlined = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: outlined ? Border.all(color: fg.withValues(alpha: 0.25)) : null),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      );
}

/// The real, 3-state OPD exam-progress status — shared so every dialog that
/// shows it uses identical wording and colors instead of each screen
/// re-deriving its own. Mirrors web's actual reachable status exactly
/// (`patients/index.blade.php`'s `view-patient-btn` → `data-status`):
/// Waiting → Primary Done → Secondary Done. Deliberately NOT "Checked In" —
/// that wording only exists on an orphaned page nothing in web links to
/// (`patients/show.blade.php`), confirmed by grepping for its route usage.
class ExamProgress {
  final String label;
  final Color bg;
  final Color fg;

  const ExamProgress._(this.label, this.bg, this.fg);

  factory ExamProgress.of({required bool primaryDone, required bool secondaryDone}) {
    if (secondaryDone) return const ExamProgress._('Secondary Done', Color(0xFFDCFCE7), Color(0xFF15803D));
    if (primaryDone) return const ExamProgress._('Primary Done', Color(0xFFDBEAFE), Color(0xFF1D4ED8));
    return const ExamProgress._('Waiting', Color(0xFFFEF9C3), Color(0xFF854D0E));
  }

  Widget badge() => Pill(label, bg: bg, fg: fg);
}

/// Header for a detail dialog about one entity (patient, booking, hospital)
/// — the Patient View / Patient History header: avatar, name, status pills,
/// a meta line, header actions (Edit, Print) and a close button, over a
/// hairline divider. No background of its own, like [AppDialogHeader].
class EntityDialogHeader extends StatelessWidget {
  final String name;
  final List<Widget> pills;
  /// e.g. `MRD: P-104 · 32y · Male` or the phone number.
  final String? meta;
  /// Icon buttons shown before the close button.
  final List<Widget> actions;
  final VoidCallback? onClose;
  final List<Color>? avatarColors;

  /// Key facts placed in the blank middle of the header (date, doctor, case…).
  /// Other dialogs leave this null and keep the identity block full width.
  final Widget? facts;

  const EntityDialogHeader({
    super.key,
    required this.name,
    this.pills = const [],
    this.meta,
    this.actions = const [],
    this.onClose,
    this.avatarColors,
    this.facts,
  });

  @override
  Widget build(BuildContext context) {
    final identity = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.darkNavy, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
      if (pills.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: pills),
      ],
      if (meta != null && meta!.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(meta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA08))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradientAvatar(name, size: 48, colors: avatarColors),
          const SizedBox(width: 12),
          Expanded(child: identity),
          ...actions,
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.textSecondary,
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              onPressed: onClose,
            ),
        ]),
        if (facts != null) ...[
          const SizedBox(height: 10),
          facts!,
        ],
      ]),
    );
  }
}

/// Compact exam state for a header pill row. The timestamp sits in the
/// tooltip so the chip stays one short line.
class ExamChip extends StatelessWidget {
  final String label;
  final bool done;
  final String? when;

  const ExamChip({super.key, required this.label, required this.done, this.when});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.green : AppColors.textSecondary;
    return Tooltip(
      message: done ? (when == null || when!.isEmpty ? 'Done' : when!) : 'Not done yet',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: done ? 0.12 : 0.10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(done ? Icons.check_rounded : Icons.schedule_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

/// Grey header facts. Always the same equal columns across the full bar,
/// so a long name above the bar does not restack Doctors / Staff / Patients.
class HeaderFacts extends StatelessWidget {
  final List<HeaderFact> items;
  const HeaderFacts(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA10),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Container(width: 1, color: AppColors.primaryA12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    items[i].value == null || items[i].value!.trim().isEmpty ? '—' : items[i].value!,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkNavy, height: 1.25),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class HeaderFact {
  final String label;
  final String? value;
  const HeaderFact(this.label, this.value);
}

/// Outlined action used on record views (Print, Edit, Full exam).
class ViewSideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const ViewSideButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryA08 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: active ? AppColors.primaryA24 : AppColors.primaryA18),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      ),
    );
  }
}

/// One filled fact. A null or blank [value] is dropped by [FactSheet].
class Fact {
  final String label;
  final String? value;
  const Fact(this.label, this.value);
}

/// A titled group of [Fact]s inside a [FactSheet]. [trailing] holds a table
/// or a short note when the section is not only tiles.
class FactSection {
  final String title;
  final List<Fact> facts;
  final Widget? trailing;
  const FactSection(this.title, this.facts, {this.trailing});
}

/// One line under a section when that part has no records yet.
class SheetNote extends StatelessWidget {
  final String text;
  const SheetNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }
}

/// One bordered sheet. Each section is a title plus a row of equal tiles.
/// Tiles keep a fixed width, so a short last row does not stretch into empty
/// blocks, and blank facts are omitted.
class FactSheet extends StatelessWidget {
  final List<FactSection> sections;
  const FactSheet({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final visible = <FactSection>[
      for (final section in sections)
        if (section.trailing != null || section.facts.any((f) => f.value != null && f.value!.trim().isNotEmpty))
          FactSection(
            section.title,
            [for (final f in section.facts) if (f.value != null && f.value!.trim().isNotEmpty) f],
            trailing: section.trailing,
          ),
    ];
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA12),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        var cols = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
        const gap = 8.0;
        var tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        if (tileW < 200 && cols > 1) {
          cols = 1;
          tileW = constraints.maxWidth;
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 8),
              Divider(height: 1, thickness: 1, color: AppColors.primaryA10),
              const SizedBox(height: 10),
            ],
            if (visible[i].title.isNotEmpty) ...[
              Text(visible[i].title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
              const SizedBox(height: 8),
            ],
            if (visible[i].facts.isNotEmpty)
              Wrap(spacing: gap, runSpacing: gap, children: [
                for (final fact in visible[i].facts)
                  SizedBox(
                    width: tileW,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.primaryA10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fact.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(fact.value!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25)),
                      ]),
                    ),
                  ),
              ]),
            if (visible[i].trailing != null) ...[
              if (visible[i].facts.isNotEmpty) const SizedBox(height: 10),
              visible[i].trailing!,
            ],
          ],
        ]);
      }),
    );
  }
}

