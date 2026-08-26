import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary:   AppColors.primary,
      secondary: AppColors.secondary,
      surface:   AppColors.surface,
      error:     AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.background,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      contentTextStyle: const TextStyle(color: AppColors.textOnPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: AppColors.primaryA12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: AppColors.primaryA12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: AppColors.textDisabled),
      selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      indicatorColor: AppColors.primaryA12,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      useIndicator: true,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AppColors.primaryA05),
      headingTextStyle: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
      dataRowColor: WidgetStatePropertyAll(AppColors.surface),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
    ),
  );
}
