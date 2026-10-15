import 'package:flutter/material.dart';
import '../../utils/app_dialogs.dart';

/// Cross-cutting dilation-lock rule (EXAMINATIONS_MODULE_PRD.md §5): after
/// Primary Exam sets dilate=Yes, Secondary Exam is time-locked until
/// `unlockTimeMs` passes. Call this before navigating to Secondary Exam —
/// returns true if it's fine to proceed (not locked, or staff confirmed the
/// override), false if the user cancelled.
Future<bool> canStartSecondaryExam(BuildContext context, int? unlockTimeMs) async {
  if (unlockTimeMs == null) return true;
  final remainingMs = unlockTimeMs - DateTime.now().millisecondsSinceEpoch;
  if (remainingMs <= 0) return true;

  final mins = (remainingMs / 60000).ceil();
  return showAppConfirmDialog(
    context,
    title: 'Dilation In Progress',
    message: 'This patient is still dilating (~$mins min remaining). Override and examine now?',
    confirmLabel: 'Override',
    icon: Icons.hourglass_bottom_rounded,
    color: const Color(0xFFD97706),
  );
}
