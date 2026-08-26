import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  // NOTE: These are static const in Phase 0–6 (AppColors.primary/text* are all const).
  // In Phase 7, if AppColors.primary converts to a getter, change style defs that
  // reference theme-overridable colors to: static TextStyle get xxx => TextStyle(...)

  static const TextStyle headingLarge  = TextStyle(fontSize: 20, fontWeight: FontWeight.w700,  color: AppColors.textPrimary);
  static const TextStyle headingMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w700,  color: AppColors.textPrimary);
  static const TextStyle headingSmall  = TextStyle(fontSize: 14, fontWeight: FontWeight.w700,  color: AppColors.textPrimary);
  static TextStyle get sectionLabel => const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2).copyWith(color: AppColors.primary);
  static const TextStyle bodyLarge     = TextStyle(fontSize: 14, fontWeight: FontWeight.w400,  color: AppColors.textPrimary);
  static const TextStyle bodyMedium    = TextStyle(fontSize: 13, fontWeight: FontWeight.w400,  color: AppColors.textPrimary);
  static const TextStyle bodySmall     = TextStyle(fontSize: 12, fontWeight: FontWeight.w400,  color: AppColors.textSecondary);
  static const TextStyle labelMedium   = TextStyle(fontSize: 12, fontWeight: FontWeight.w600,  color: AppColors.textSecondary);
  static const TextStyle labelSmall    = TextStyle(fontSize: 11, fontWeight: FontWeight.w600,  color: AppColors.textPrimary);
  static const TextStyle navLabel      = TextStyle(fontSize: 10, fontWeight: FontWeight.w700);
  static const TextStyle statNumber    = TextStyle(fontSize: 22, fontWeight: FontWeight.w800,  color: AppColors.textPrimary);
  static const TextStyle cardTitle     = TextStyle(fontSize: 14, fontWeight: FontWeight.w600,  color: AppColors.textPrimary);
  static const TextStyle cardSubtitle  = TextStyle(fontSize: 12, fontWeight: FontWeight.w400,  color: AppColors.textSecondary);
}
