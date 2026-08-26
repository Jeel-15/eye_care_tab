import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';

/// Reusable signature-capture canvas for OT consent (Phase 1). Neither app
/// had a signature component before this — see
/// OT_WORKFLOW_MOBILE_TABLET_BUILD_PRD.md §3/§5.
class SignaturePadField extends StatelessWidget {
  final String label;
  final SignatureController controller;
  final double height;

  const SignaturePadField({super.key, required this.label, required this.controller, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, _, _) => TextButton.icon(
            onPressed: controller.isNotEmpty ? controller.clear : null,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Signature(controller: controller, backgroundColor: const Color(0xFFF8FAFC)),
      ),
    ]);
  }
}

/// Builds the base64 PNG data-URI the backend expects for
/// `patient_signature`/`guardian_signature`. Returns null if nothing was
/// drawn (both fields are optional per the contract).
Future<String?> exportSignatureDataUri(SignatureController controller) async {
  if (controller.isEmpty) return null;
  final bytes = await controller.toPngBytes();
  if (bytes == null) return null;
  return 'data:image/png;base64,${base64Encode(bytes)}';
}
