import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../widgets/app_animations.dart';
import 'patient_history_screen.dart';

/// Full-screen route wrapper around [PatientHistoryScreen], which has no
/// chrome of its own since it's normally embedded in the Patients detail
/// pane. Used anywhere history needs to be opened from outside that pane
/// (Share History's own-patient view, Assistant Dashboard's queue rows).
class PatientHistoryRoute extends StatelessWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;

  const PatientHistoryRoute({super.key, required this.user, required this.hospital, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, title: Text(patient.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: PatientHistoryScreen(user: user, hospital: hospital, patient: patient, onBack: () => Navigator.pop(context), onNotReady: (label) => showAppSnackBar(context, '$label — not built yet', duration: const Duration(seconds: 2))),
      ),
    );
  }
}
