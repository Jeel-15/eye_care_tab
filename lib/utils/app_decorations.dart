import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';

abstract final class AppDecorations {
  static BoxDecoration card({double radius = AppRadius.md}) => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.primaryA08, width: 0.5),
    boxShadow: [
      BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  static BoxDecoration accentCard({double radius = AppRadius.md}) => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  static BoxDecoration pill({required Color color, double opacity = 0.12}) => BoxDecoration(
    color: color.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(AppRadius.full),
  );

  static BoxDecoration iconBox({required Color color, double radius = AppRadius.sm}) => BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(radius),
  );

  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = false,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: AppColors.surface,
    labelStyle: AppTextStyles.labelMedium,
    hintStyle: AppTextStyles.labelMedium,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: isDense,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
    errorStyle: const TextStyle(fontSize: 11),
  );
}
