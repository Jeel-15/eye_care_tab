import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 10,
  });

  factory StatusBadge.hospitalStatus(String status) {
    final color = switch (status.toLowerCase()) {
      'active'    => AppColors.green,
      'trial'     => AppColors.secondary,
      'grace'     => AppColors.orange,
      'suspended' => AppColors.red,
      _           => AppColors.textDisabled,
    };
    return StatusBadge(label: status, color: color);
  }

  factory StatusBadge.paymentStatus(String status) {
    final color = switch (status.toLowerCase()) {
      'success' => AppColors.green,
      'pending' => AppColors.orange,
      _         => AppColors.red,
    };
    return StatusBadge(label: status, color: color);
  }

  factory StatusBadge.notificationStatus(String status) {
    final color = switch (status.toLowerCase()) {
      'sent'    => AppColors.green,
      'pending' => AppColors.orange,
      _         => AppColors.red,
    };
    return StatusBadge(label: status, color: color);
  }

  factory StatusBadge.subscriptionStatus(String status) {
    final color = switch (status.toLowerCase()) {
      'active' => AppColors.green,
      _        => AppColors.red,
    };
    return StatusBadge(label: status, color: color);
  }

  /// Web's real per-row stage (`OtAppointment::stage_label`/`stage_badge_class`
  /// — index.blade.php's `.ot-stage-*` CSS, colors matched exactly here) —
  /// not the raw 4-value `status`, which collapses 10 distinct real-world
  /// stages (Surgery Recommended, In Ward, Ready for OT, Discharged, ...)
  /// down to just "completed".
  factory StatusBadge.otAppointmentStage(String badgeClass, String label) {
    final color = switch (badgeClass) {
      'ot-stage-booked'      => const Color(0xFF92660A),
      'ot-stage-confirmed'   => const Color(0xFF1E8E5A),
      'ot-stage-discharged'  => const Color(0xFF1E8E5A),
      'ot-stage-cancelled'   => const Color(0xFFC0392B),
      'ot-stage-checkedin'   => const Color(0xFF5D6D7E),
      'ot-stage-recommended' => const Color(0xFF8E44AD),
      'ot-stage-counselled'  => const Color(0xFF2E86C1),
      'ot-stage-billing'     => const Color(0xFFB9750B),
      'ot-stage-ward'        => const Color(0xFF117864),
      'ot-stage-ready'       => const Color(0xFF148F77),
      'ot-stage-operated'    => const Color(0xFF1A5276),
      _                      => AppColors.textDisabled,
    };
    return StatusBadge(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
