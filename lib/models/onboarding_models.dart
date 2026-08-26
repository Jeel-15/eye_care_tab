import 'package:flutter/material.dart';

/// What kind of stylized mini-preview the layered card stack shows for a
/// slide — each maps to a small hand-drawn mock (icon + stat chips/bars),
/// not a real screenshot, so it never goes stale when the real UI changes.
enum MockCardKind { dashboard, reports, users, queue, exam, patients, ot }

class OnboardingSlideData {
  final String headline;
  final String subtext;
  final Color accent;
  final MockCardKind cardKind;

  const OnboardingSlideData({
    required this.headline,
    required this.subtext,
    required this.accent,
    required this.cardKind,
  });
}
