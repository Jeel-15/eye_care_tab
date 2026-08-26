import 'package:flutter/material.dart';
import '../config/client_theme.dart';

class AppColors {
  AppColors._();

  // ── Theme-overridable colors (private mutable + public getter) ────────────
  static Color _primary      = const Color(0xFF1B4F72);
  static Color _primaryLight = const Color(0xFF2471A3);
  static Color _secondary    = const Color(0xFF2E86C1);
  static Color _background   = const Color(0xFFEBF5FB);

  static Color get primary      => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get secondary    => _secondary;
  static Color get background   => _background;

  // ── Fixed brand colors ────────────────────────────────────────────────────
  static const Color primaryDark  = Color(0xFF154360);
  static const Color darkNavy     = Color(0xFF1A3A52);
  static const Color blue         = Color(0xFF006497);
  static const Color blueLight    = Color(0xFF2980B9);
  static const Color teal         = Color(0xFF1ABC9C);
  static const Color tealDark     = Color(0xFF0E9E82);
  static const Color green        = Color(0xFF27AE60);
  static const Color orange       = Color(0xFFE67E22);
  static const Color purple       = Color(0xFF8E44AD);
  static const Color red          = Color(0xFFDC3545);
  static const Color redDark      = Color(0xFFC0392B);
  static const Color backgroundAlt    = Color(0xFFEAF2F8);
  static const Color surfaceFill      = Color(0xFFF0F6FB);
  static const Color drawerBackground = Color(0xFFF3F4F7);
  static const Color surface          = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled  = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color navBarBg      = Color(0xF0FFFFFF);
  static const Color black10       = Color(0x1A000000);
  static const Color splashAccent  = Color(0xFF9DCBF4);
  static const Color waitGreen     = Color(0xFF16A34A);
  static const Color waitOrange    = Color(0xFFEA580C);
  static const Color waitRed       = Color(0xFFDC2626);
  static const Color skeletonBase  = Color(0xFFE2E8F0);
  static const Color skeletonShine = Color(0xFFF8FAFC);

  // ── Primary alpha variants (private mutable + public getter) ─────────────
  static Color _primaryA03 = const Color(0xFF1B4F72).withValues(alpha: 0.03);
  static Color _primaryA04 = const Color(0xFF1B4F72).withValues(alpha: 0.04);
  static Color _primaryA05 = const Color(0xFF1B4F72).withValues(alpha: 0.05);
  static Color _primaryA06 = const Color(0xFF1B4F72).withValues(alpha: 0.06);
  static Color _primaryA07 = const Color(0xFF1B4F72).withValues(alpha: 0.07);
  static Color _primaryA08 = const Color(0xFF1B4F72).withValues(alpha: 0.08);
  static Color _primaryA10 = const Color(0xFF1B4F72).withValues(alpha: 0.10);
  static Color _primaryA12 = const Color(0xFF1B4F72).withValues(alpha: 0.12);
  static Color _primaryA13 = const Color(0xFF1B4F72).withValues(alpha: 0.13);
  static Color _primaryA14 = const Color(0xFF1B4F72).withValues(alpha: 0.14);
  static Color _primaryA15 = const Color(0xFF1B4F72).withValues(alpha: 0.15);
  static Color _primaryA18 = const Color(0xFF1B4F72).withValues(alpha: 0.18);
  static Color _primaryA20 = const Color(0xFF1B4F72).withValues(alpha: 0.20);
  static Color _primaryA22 = const Color(0xFF1B4F72).withValues(alpha: 0.22);
  static Color _primaryA24 = const Color(0xFF1B4F72).withValues(alpha: 0.24);
  static Color _primaryA25 = const Color(0xFF1B4F72).withValues(alpha: 0.25);
  static Color _primaryA28 = const Color(0xFF1B4F72).withValues(alpha: 0.28);
  static Color _primaryA30 = const Color(0xFF1B4F72).withValues(alpha: 0.30);
  static Color _primaryA35 = const Color(0xFF1B4F72).withValues(alpha: 0.35);
  static Color _primaryA38 = const Color(0xFF1B4F72).withValues(alpha: 0.38);
  static Color _primaryA40 = const Color(0xFF1B4F72).withValues(alpha: 0.40);
  static Color _primaryA45 = const Color(0xFF1B4F72).withValues(alpha: 0.45);
  static Color _primaryA50 = const Color(0xFF1B4F72).withValues(alpha: 0.50);
  static Color _primaryA55 = const Color(0xFF1B4F72).withValues(alpha: 0.55);
  static Color _primaryA58 = const Color(0xFF1B4F72).withValues(alpha: 0.58);
  static Color _primaryA60 = const Color(0xFF1B4F72).withValues(alpha: 0.60);
  static Color _primaryA62 = const Color(0xFF1B4F72).withValues(alpha: 0.62);
  static Color _primaryA70 = const Color(0xFF1B4F72).withValues(alpha: 0.70);
  static Color _primaryA75 = const Color(0xFF1B4F72).withValues(alpha: 0.75);

  static Color get primaryA03 => _primaryA03;
  static Color get primaryA04 => _primaryA04;
  static Color get primaryA05 => _primaryA05;
  static Color get primaryA06 => _primaryA06;
  static Color get primaryA07 => _primaryA07;
  static Color get primaryA08 => _primaryA08;
  static Color get primaryA10 => _primaryA10;
  static Color get primaryA12 => _primaryA12;
  static Color get primaryA13 => _primaryA13;
  static Color get primaryA14 => _primaryA14;
  static Color get primaryA15 => _primaryA15;
  static Color get primaryA18 => _primaryA18;
  static Color get primaryA20 => _primaryA20;
  static Color get primaryA22 => _primaryA22;
  static Color get primaryA24 => _primaryA24;
  static Color get primaryA25 => _primaryA25;
  static Color get primaryA28 => _primaryA28;
  static Color get primaryA30 => _primaryA30;
  static Color get primaryA35 => _primaryA35;
  static Color get primaryA38 => _primaryA38;
  static Color get primaryA40 => _primaryA40;
  static Color get primaryA45 => _primaryA45;
  static Color get primaryA50 => _primaryA50;
  static Color get primaryA55 => _primaryA55;
  static Color get primaryA58 => _primaryA58;
  static Color get primaryA60 => _primaryA60;
  static Color get primaryA62 => _primaryA62;
  static Color get primaryA70 => _primaryA70;
  static Color get primaryA75 => _primaryA75;

  // ── Other alpha variants (fixed colors, keep as static final) ─────────────
  static final Color tealA06   = teal.withValues(alpha: 0.06);
  static final Color tealA10   = teal.withValues(alpha: 0.10);
  static final Color tealA12   = teal.withValues(alpha: 0.12);
  static final Color tealA13   = teal.withValues(alpha: 0.13);
  static final Color orangeA12 = orange.withValues(alpha: 0.12);
  static final Color orangeA13 = orange.withValues(alpha: 0.13);
  static final Color orangeA14 = orange.withValues(alpha: 0.14);
  static final Color purpleA12 = purple.withValues(alpha: 0.12);
  static final Color redA70    = red.withValues(alpha: 0.70);
  static final Color greenA12  = green.withValues(alpha: 0.12);
  static final Color greyA10   = Colors.grey.withValues(alpha: 0.10);
  static final Color blueA12   = blue.withValues(alpha: 0.12);

  // ── Reset to compiled defaults (call on Platform login / logout) ─────────
  static void resetToDefault() {
    _primary      = const Color(0xFF1B4F72);
    _primaryLight = const Color(0xFF2471A3);
    _secondary    = const Color(0xFF2E86C1);
    _background   = const Color(0xFFEBF5FB);
    _primaryA03 = _primary.withValues(alpha: 0.03);
    _primaryA04 = _primary.withValues(alpha: 0.04);
    _primaryA05 = _primary.withValues(alpha: 0.05);
    _primaryA06 = _primary.withValues(alpha: 0.06);
    _primaryA07 = _primary.withValues(alpha: 0.07);
    _primaryA08 = _primary.withValues(alpha: 0.08);
    _primaryA10 = _primary.withValues(alpha: 0.10);
    _primaryA12 = _primary.withValues(alpha: 0.12);
    _primaryA13 = _primary.withValues(alpha: 0.13);
    _primaryA14 = _primary.withValues(alpha: 0.14);
    _primaryA15 = _primary.withValues(alpha: 0.15);
    _primaryA18 = _primary.withValues(alpha: 0.18);
    _primaryA20 = _primary.withValues(alpha: 0.20);
    _primaryA22 = _primary.withValues(alpha: 0.22);
    _primaryA24 = _primary.withValues(alpha: 0.24);
    _primaryA25 = _primary.withValues(alpha: 0.25);
    _primaryA28 = _primary.withValues(alpha: 0.28);
    _primaryA30 = _primary.withValues(alpha: 0.30);
    _primaryA35 = _primary.withValues(alpha: 0.35);
    _primaryA38 = _primary.withValues(alpha: 0.38);
    _primaryA40 = _primary.withValues(alpha: 0.40);
    _primaryA45 = _primary.withValues(alpha: 0.45);
    _primaryA50 = _primary.withValues(alpha: 0.50);
    _primaryA55 = _primary.withValues(alpha: 0.55);
    _primaryA58 = _primary.withValues(alpha: 0.58);
    _primaryA60 = _primary.withValues(alpha: 0.60);
    _primaryA62 = _primary.withValues(alpha: 0.62);
    _primaryA70 = _primary.withValues(alpha: 0.70);
    _primaryA75 = _primary.withValues(alpha: 0.75);
  }

  // ── Apply client theme (call after login) ─────────────────────────────────
  static void applyTheme(ClientTheme theme) {
    _primary      = theme.primary;
    _primaryLight = theme.primaryLight;
    _secondary    = theme.secondary;
    _background   = theme.background;
    _primaryA03 = _primary.withValues(alpha: 0.03);
    _primaryA04 = _primary.withValues(alpha: 0.04);
    _primaryA05 = _primary.withValues(alpha: 0.05);
    _primaryA06 = _primary.withValues(alpha: 0.06);
    _primaryA07 = _primary.withValues(alpha: 0.07);
    _primaryA08 = _primary.withValues(alpha: 0.08);
    _primaryA10 = _primary.withValues(alpha: 0.10);
    _primaryA12 = _primary.withValues(alpha: 0.12);
    _primaryA13 = _primary.withValues(alpha: 0.13);
    _primaryA14 = _primary.withValues(alpha: 0.14);
    _primaryA15 = _primary.withValues(alpha: 0.15);
    _primaryA18 = _primary.withValues(alpha: 0.18);
    _primaryA20 = _primary.withValues(alpha: 0.20);
    _primaryA22 = _primary.withValues(alpha: 0.22);
    _primaryA24 = _primary.withValues(alpha: 0.24);
    _primaryA25 = _primary.withValues(alpha: 0.25);
    _primaryA28 = _primary.withValues(alpha: 0.28);
    _primaryA30 = _primary.withValues(alpha: 0.30);
    _primaryA35 = _primary.withValues(alpha: 0.35);
    _primaryA38 = _primary.withValues(alpha: 0.38);
    _primaryA40 = _primary.withValues(alpha: 0.40);
    _primaryA45 = _primary.withValues(alpha: 0.45);
    _primaryA50 = _primary.withValues(alpha: 0.50);
    _primaryA55 = _primary.withValues(alpha: 0.55);
    _primaryA58 = _primary.withValues(alpha: 0.58);
    _primaryA60 = _primary.withValues(alpha: 0.60);
    _primaryA62 = _primary.withValues(alpha: 0.62);
    _primaryA70 = _primary.withValues(alpha: 0.70);
    _primaryA75 = _primary.withValues(alpha: 0.75);
  }
}
