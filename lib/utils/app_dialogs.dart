import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';

/// Yes/no confirmation on the shared [AppDialog] frame. [destructive] turns
/// the header and confirm button red (delete, refuse, cancel appointment);
/// [color] overrides the accent for positive confirms (e.g. green Accept).
/// Returns false when dismissed.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
  Color? color,
  bool barrierDismissible = true,
}) async {
  final accent = color ?? (destructive ? AppColors.red : null);
  return await showDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (ctx) => AppDialog(
          size: AppDialogSize.small,
          header: AppDialogHeader(
            icon: icon ?? (destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded),
            title: title,
            colors: color != null ? [color, color] : (destructive ? const [AppColors.redDark, AppColors.red] : null),
            onClose: () => Navigator.pop(ctx, false),
          ),
          body: Text(message, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.darkNavy)),
          actions: [
            AppSecondaryButton(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
            AppPrimaryButton(label: confirmLabel, color: accent, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ) ??
      false;
}

Future<bool> showDeleteConfirmDialog(
  BuildContext context,
  String title, {
  String body = 'This action cannot be undone.',
}) =>
    showAppConfirmDialog(context, title: title, message: body, confirmLabel: 'Delete', destructive: true);
