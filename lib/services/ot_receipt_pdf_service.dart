import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/ot_accountant_models.dart';
import '../utils/date_format.dart';

/// Native Flutter PDF for the OT Payment Receipt — same `pdf`/`printing`
/// pattern already used for the OPD Bill (`opd_bill_screen.dart`, A5 +
/// `PdfGoogleFonts.notoSans*` for currency-symbol support) rather than a
/// server-rendered DomPDF download, to avoid the formatting problems that
/// approach has on this exact codebase (see OT_BUGS_ROUND4_AUDIT.md Bug #6).
/// Field set matches `_DashboardReceiptPreview` in
/// ot_accountant_dashboard_screen.dart exactly (also the audited list in
/// OT_WEB_PARITY_FIX_PRD.md §6 FIX 6.3).
class OtReceiptPdfService {
  OtReceiptPdfService._();
  static final OtReceiptPdfService instance = OtReceiptPdfService._();

  Future<Uint8List> generatePdf({
    required String hospitalName,
    required OtPaymentReceipt receipt,
    required String currencySymbol,
    String? patientNameFallback,
    String? hospitalLogoUrl,
    // Web's Settings → Print "Letter Pad" toggle (hospital_setting
    // 'letter_pad') — see receipt_print.blade.php's own `$letterPad ===
    // 'available'` branch: a minimal "Payment Receipt · {no}" title, no
    // logo/hospital-name block, since the physical letterhead paper
    // already carries the branding. See client report 2026-10-14.
    bool letterPadAvailable = false,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logo = await _fetchLogo(hospitalLogoUrl);

    final p = receipt.payment;
    final remaining = (receipt.requiredTotal - receipt.totalPaid).clamp(
      0,
      double.infinity,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: letterPadAvailable
                  ? pw.Column(
                      children: [
                        pw.Text(
                          'Payment Receipt',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Receipt: ${p.receiptNumber ?? '-'}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    )
                  : pw.Column(
                      children: [
                        if (logo != null) ...[
                          pw.Image(logo, height: 36, fit: pw.BoxFit.contain),
                          pw.SizedBox(height: 6),
                        ],
                        pw.Text(
                          hospitalName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Payment Receipt',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          p.receiptNumber ?? '-',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                '$currencySymbol${p.packageAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            _box('Patient', [
              _row(
                'Name',
                receipt.patient?.fullName ?? patientNameFallback ?? '-',
              ),
              _row('UHID', receipt.patient?.patientCode ?? '-'),
              _row('Mobile', receipt.patient?.contactNo ?? '-'),
            ]),
            _box('Payment Details', [
              _row('Receipt No.', p.receiptNumber ?? '-'),
              _row('Mode', p.paymentMode.toUpperCase()),
              _row('Mediclaim', p.hasMediclaim ? 'Yes' : 'No'),
              _row('Paid At', formatDateTimeString(p.paidAt)),
              _row('Recorded By', p.recordedBy?.name ?? '-'),
            ]),
            _box('Package Balance', [
              _row(
                'Package Total',
                '$currencySymbol${receipt.requiredTotal.toStringAsFixed(0)}',
              ),
              _row(
                'Total Paid',
                '$currencySymbol${receipt.totalPaid.toStringAsFixed(0)}',
              ),
              _row(
                'Remaining',
                '$currencySymbol${remaining.toStringAsFixed(0)}',
              ),
              _row(
                'Status',
                paymentStatusLabel(
                  receipt.bookingPaymentStatus ?? 'pending',
                  verbose: true,
                ),
              ),
            ]),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'This is a computer-generated receipt for OT surgery charges.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      // Logo is a nice-to-have on the printed receipt — never block
      // generation over a failed/slow image fetch.
    }
    return null;
  }

  pw.Widget _box(String title, List<pw.Widget> rows) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    margin: const pw.EdgeInsets.only(bottom: 8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(4),
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        ...rows,
      ],
    ),
  );

  pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
