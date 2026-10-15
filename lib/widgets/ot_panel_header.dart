import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// The colored panel header bar OT module pages use on web ("Appointment
/// Register", "Awaiting Counselling", "Payment Status", etc.) — an icon in
/// a translucent white circle + bold white title (+ optional subtitle),
/// with room for light-on-dark trailing controls. Uses the tablet app's own
/// [AppColors.primary] (not web's literal dark-navy hex) so this chrome
/// stays visually consistent with every other screen's header/accent color
/// instead of introducing an off-brand one-off color. Shared so the exact
/// same treatment is reused by every OT screen with this chrome instead of
/// re-implemented per screen.
class OtPanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const OtPanelHeader({super.key, required this.icon, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              ),
          ]),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(width: 10), ...actions],
      ]),
    );
  }
}
