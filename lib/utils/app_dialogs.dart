import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

Future<bool> showDeleteConfirmDialog(
  BuildContext context,
  String title, {
  String body = 'This action cannot be undone.',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text(body, style: AppTextStyles.cardSubtitle),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
