import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';

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
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Row(children: [
        const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFD97706)),
        const SizedBox(width: 8),
        const Text('Dilation In Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      content: Text('This patient is still dilating (~$mins min remaining). Override and examine now?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Override')),
      ],
    ),
  );
  return proceed ?? false;
}
