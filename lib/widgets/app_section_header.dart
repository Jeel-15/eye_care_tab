import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  /// When provided: shows [icon + text] instead of the 3px bar + text.
  /// Use for form screens where icons add contextual meaning.
  final IconData? icon;

  const AppSectionHeader({super.key, required this.title, this.trailing, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
          ] else ...[
            Container(
              width: 3,
              height: 17,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Text(title, style: AppTextStyles.sectionLabel),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
