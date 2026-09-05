import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

/// Shown when a hospital's access is blocked (plan expired, suspended, or
/// pending approval). Reached only via [AccessGuard] — never pushed
/// directly by a screen. See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 2.
class AccessRestrictedScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AccessRestrictedScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_clock_rounded, size: 48, color: AppColors.red),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Access Restricted',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
