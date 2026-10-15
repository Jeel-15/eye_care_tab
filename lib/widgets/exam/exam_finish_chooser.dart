import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../app_dialog.dart';
import '../form_kit.dart';

enum ExamFinishChoice { recommendOt, saveSecondary }

/// Small chooser after Advice. Recommend OT opens the real fields.
/// Save Secondary finishes without OT.
Future<ExamFinishChoice?> showExamFinishChooser(
  BuildContext context, {
  required bool canRecommend,
}) {
  return showDialog<ExamFinishChoice>(
    context: context,
    builder: (ctx) => AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.fact_check_rounded,
        title: 'Finish examination',
        subtitle: 'Save secondary, or recommend OT',
        colors: const [AppColors.tealDark, AppColors.teal],
        onClose: () => Navigator.pop(ctx),
      ),
      body: const Text(
        'Diagnosis, medicine or advice on this exam can finish secondary here. Recommend OT opens the surgery fields and saves the exam with them.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        if (canRecommend)
          AppSecondaryButton(
            label: 'Recommend OT',
            onPressed: () => Navigator.pop(ctx, ExamFinishChoice.recommendOt),
          ),
        AppPrimaryButton(
          label: 'Save Secondary',
          color: AppColors.teal,
          onPressed: () => Navigator.pop(ctx, ExamFinishChoice.saveSecondary),
        ),
      ],
    ),
  );
}
