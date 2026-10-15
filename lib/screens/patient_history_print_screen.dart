import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../models/patient_history_models.dart';
import '../services/auth_service.dart';
import '../services/patient_history_print_service.dart';
import '../services/settings_service.dart';

/// Prints the patient's *entire* clinical timeline — every exam, full
/// clinical data — mirroring web's "Print Full History" (the printer icon
/// next to the Clinical Timeline heading). See PATIENT_HISTORY_PRINT_PLAN.md.
class PatientHistoryPrintScreen extends StatelessWidget {
  final PatientHistorySummary patient;
  final List<ExamRecord> exams;
  final Map<int, String> diagnosisMasters;
  final HospitalInfo hospital;

  const PatientHistoryPrintScreen({
    super.key,
    required this.patient,
    required this.exams,
    required this.diagnosisMasters,
    required this.hospital,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Patient History',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          Text(patient.name,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: PdfPreview(
        // PdfPreview has built-in print + share buttons in its action bar
        build: (_) async {
          bool letterPadAvailable = false;
          try {
            final settings = await SettingsService.instance.fetchSettings();
            letterPadAvailable = settings.letterPadAvailable;
          } catch (_) {
            // Best-effort — never block PDF generation over a failed
            // settings fetch.
          }
          return PatientHistoryPrintService.instance.generatePdf(
            hospitalName: hospital.name,
            patient: patient,
            exams: exams,
            diagnosisMasters: diagnosisMasters,
            // Live session cache, not `hospital` — that's frozen at
            // login/launch and won't reflect a logo uploaded mid-session.
            hospitalLogoUrl: AuthService.instance.cachedHospital?.logoUrl ?? hospital.logoUrl,
            letterPadAvailable: letterPadAvailable,
          );
        },
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'patient_history_${patient.patientCode}.pdf',
      ),
    );
  }
}
