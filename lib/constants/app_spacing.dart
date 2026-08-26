import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;

  static const double bottomNavClearance = 110.0;

  static const EdgeInsets pagePadding    = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageWithBottom = EdgeInsets.fromLTRB(lg, md, lg, bottomNavClearance);
  static const EdgeInsets cardPadding    = EdgeInsets.all(lg);
  static const EdgeInsets chipPadding    = EdgeInsets.symmetric(horizontal: md, vertical: 6);
}
