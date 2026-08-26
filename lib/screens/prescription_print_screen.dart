import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../models/patient_history_models.dart';
import '../services/prescription_service.dart';

/// Tablet prescription print preview — full-screen route (pushed from Patient
/// History's "Print Rx" action), pdf generation ported unchanged from
/// eye_care_app/lib/screens/prescription_print_screen.dart. `PdfPreview`
/// already centers/scales its page nicely on wide screens, so no further
/// layout changes were needed beyond the standard tablet AppBar treatment.
class PrescriptionPrintScreen extends StatelessWidget {
  final ExamRecord exam;
  final PatientHistorySummary patient;
  final HospitalInfo hospital;

  const PrescriptionPrintScreen({super.key, required this.exam, required this.patient, required this.hospital});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Prescription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          Text(patient.name, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: PdfPreview(
        build: (_) => PrescriptionService.instance.generatePdf(hospitalName: hospital.name, exam: exam, patient: patient),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: 'prescription_${patient.patientCode}_${_fileDate(exam.examinedAt)}.pdf',
      ),
    );
  }

  String _fileDate(DateTime dt) => '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
}
