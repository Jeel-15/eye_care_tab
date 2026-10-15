import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ot_booking_models.dart';

/// Color for an `OtBooking.ot_status` value — every OT desk screen
/// (Counsellor/Accountant/Ward/Assistant/Discharge) needs the full status
/// chain now that each one's "All"/History tab (web pull 2026-09-19
/// Queue/All toggle) can surface any status from `counselled` through
/// `discharged`/`surgery_refused`, not just the 2-3 statuses its own Queue
/// view used to show. Centralized here instead of five slightly-different
/// per-screen switch statements.
Color otStatusColor(String status) => switch (status) {
      OtStatus.surgeryRecommended => AppColors.orange,
      OtStatus.counselled => AppColors.blue,
      OtStatus.paid => AppColors.green,
      OtStatus.paymentVerified => AppColors.blue,
      OtStatus.inWard => AppColors.orange,
      OtStatus.dilated => AppColors.teal,
      OtStatus.ready => AppColors.tealDark,
      OtStatus.operated => AppColors.primary,
      OtStatus.discharged => AppColors.green,
      OtStatus.surgeryRefused => AppColors.red,
      _ => AppColors.textDisabled,
    };
