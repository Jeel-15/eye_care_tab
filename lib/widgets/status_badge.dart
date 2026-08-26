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

  factory StatusBadge.otAppointmentStatus(String status) {
    final color = switch (status.toLowerCase()) {
      'confirmed' => AppColors.green,
      'booked'    => AppColors.blue,
      'completed' => AppColors.teal,
      'cancelled' => AppColors.red,
      _           => AppColors.textDisabled,
    };
    return StatusBadge(label: status, color: color);
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
