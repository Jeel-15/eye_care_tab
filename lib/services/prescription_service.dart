import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/patient_history_models.dart';

class PrescriptionService {
  PrescriptionService._();
  static final PrescriptionService instance = PrescriptionService._();

  /// Build PDF bytes for a prescription.
  /// [hospitalName] — shown in header.
  /// [exam] — ExamRecord containing prescriptions + advice.
  /// [patient] — PatientHistorySummary for patient details.
  Future<Uint8List> generatePdf({
    required String hospitalName,
    required ExamRecord exam,
    required PatientHistorySummary patient,
  }) async {
    final doc = pw.Document();
    final rxLines = exam.prescriptions;

    final dateStr = _fmtDate(exam.examinedAt);
    final patientAge =
        patient.age != null ? '${patient.age} yrs' : '-';
    final patientGender =
        patient.gender != null ? _cap(patient.gender!) : '-';
    final doctorName = exam.doctorName ?? '-';

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          pw.Center(
            child: pw.Column(children: [
              pw.Text(
                hospitalName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Prescription',
                style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
              ),
            ]),
          ),
          pw.Divider(color: PdfColors.grey400, height: 20),

          // ── Patient info row ───────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  _labelValue('Patient', patient.name),
                  _labelValue('ID', patient.patientCode),
                  _labelValue('Contact', patient.contactNo ?? '-'),
                ]),
              ),
              pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  _labelValue('Age / Gender', '$patientAge / $patientGender'),
                  _labelValue('Doctor', 'Dr. $doctorName'),
                  _labelValue('Date', dateStr),
                ]),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey300, height: 20),

          // ── Prescription table ─────────────────────────────────────────────
          if (rxLines.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              child: pw.Text('No prescription lines.',
                  style: const pw.TextStyle(color: PdfColors.grey600)),
            )
          else ...[
            pw.Text(
              'Rx',
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: ['Medicine', 'Dosage', 'Duration', 'Eye']
                      .map((h) => _tableCell(h, isHeader: true))
                      .toList(),
                ),
                // Data rows
                ...rxLines.map(
                  (rx) => pw.TableRow(children: [
                    _tableCell(rx.medicineName),
                    _tableCell(rx.dosage),
                    _tableCell(rx.duration),
                    _tableCell(_eyeLabel(rx.eye)),
                  ]),
                ),
              ],
            ),
          ],

          // ── Advice ────────────────────────────────────────────────────────
          if (exam.advice.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Advice',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(exam.advice,
                  style: const pw.TextStyle(fontSize: 11)),
            ),
          ],

          // ── Footer ────────────────────────────────────────────────────────
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Text('Generated: $dateStr',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500)),
            pw.Text('Doctor\'s Signature: ______________',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500)),
          ]),
        ],
      ),
    ));

    return doc.save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ]),
      ),
    );
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _eyeLabel(String eye) {
    return switch (eye.toLowerCase()) {
      're'   => 'RE',
      'le'   => 'LE',
      'both' => 'Both',
      _      => eye,
    };
  }
}
