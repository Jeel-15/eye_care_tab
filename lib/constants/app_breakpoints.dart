import 'package:flutter/material.dart';

/// Tablet-only layout tokens — additive to the mobile design system.
/// Never edit app_spacing.dart / app_radius.dart values; extend here instead.
abstract final class AppBreakpoints {
  static const double compact  = 720;
  static const double medium   = 1100;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width)  => width >= compact && width < medium;
  static bool isExpanded(double width) => width >= medium;
}

abstract final class TabletSpacing {
  static const double railWidthCollapsed = 76;
  static const double railWidthExpanded  = 240;
  static const double paneGapMin         = 24;
  static const double listPaneWidth      = 360;

  static const EdgeInsets pagePaddingWide = EdgeInsets.symmetric(horizontal: 32, vertical: 24);
}
