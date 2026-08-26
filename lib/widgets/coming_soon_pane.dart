import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// Placeholder content shown for rail destinations whose real screen hasn't
/// been built yet in the current PRD phase. Replaced screen-by-screen as
/// each phase in EYE_CARE_TAB_PRD.md lands.
class ComingSoonPane extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? phaseNote;

  const ComingSoonPane({
    super.key,
    required this.title,
    required this.icon,
    this.phaseNote,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryA08,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 40, color: AppColors.primaryA55),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            phaseNote ?? 'Coming soon',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
