import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../widgets/app_animations.dart';

/// Tablet OPD Bill / receipt — full-screen route (pushed from Patients'
/// "Print Bill" action and Check-in's post-submit flow), pdf generation
/// ported unchanged from eye_care_app/lib/screens/opd_bill_screen.dart. Only
/// change from mobile: the receipt card is centered with a fixed max width
/// (matches its A5 PDF proportions) instead of stretching edge-to-edge on
/// the wider tablet canvas.
class OpdBillScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;

  const OpdBillScreen({super.key, required this.user, required this.hospital, required this.patient});

  @override
  State<OpdBillScreen> createState() => _OpdBillScreenState();
}

class _OpdBillScreenState extends State<OpdBillScreen> {
  bool _sharing = false;

  // ── PDF generation ──────────────────────────────────────────────────────────

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'OPD_Bill_${widget.patient.patientCode}.pdf');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Failed to generate bill: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final p = widget.patient;
    final fee = p.caseFee ?? 0.0;
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(widget.hospital.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B4F72'))),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColor.fromHex('#1B4F72'), width: 0.5)),
                child: pw.Text('OPD BILL / RECEIPT', style: pw.TextStyle(fontSize: 9, letterSpacing: 1.5, color: PdfColor.fromHex('#1B4F72'))),
              ),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColor.fromHex('#D5E8F7')),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _lbl('MRD No.', fontBold),
                  pw.Text(p.patientCode, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B4F72'))),
                  pw.SizedBox(height: 8),
                  _lbl('Patient Name', fontBold),
                  pw.Text(p.fullName, style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 8),
                  _lbl('Age / Gender', fontBold),
                  pw.Text([if (p.age != null) '${p.age} yrs', if (p.gender != null) p.gender![0].toUpperCase() + p.gender!.substring(1)].join(' / '), style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 8),
                  _lbl('Contact', fontBold),
                  pw.Text(p.contactNo ?? '-', style: const pw.TextStyle(fontSize: 11)),
                ]),
              ),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _lbl('Date', fontBold),
                  pw.Text(_pdfFmtDate(p.appointmentDate), style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 8),
                  _lbl('Consultant', fontBold),
                  pw.Text(p.doctor?.name ?? '-', style: const pw.TextStyle(fontSize: 11)),
                  if (p.doctorPatientNo != null) ...[
                    pw.SizedBox(height: 8),
                    _lbl('Doctor Serial', fontBold),
                    pw.Text(p.doctorPatientNo!.toString().padLeft(3, '0'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B4F72'))),
                  ],
                  pw.SizedBox(height: 8),
                  _lbl('Type', fontBold),
                  pw.Text(p.type == 'walkin' ? 'Walk-in' : 'Phone Appt', style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 8),
                  _lbl('Case', fontBold),
                  pw.Text(p.caseType?.caseType ?? '-', style: const pw.TextStyle(fontSize: 11)),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColor.fromHex('#D5E8F7')),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D5E8F7')),
            columnWidths: const {0: pw.FixedColumnWidth(20), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(80)},
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EBF5FB')), children: [_tc('#', fontBold, 9, header: true), _tc('Description', fontBold, 9, header: true), _tc('Amount (Rs.)', fontBold, 9, header: true)]),
              pw.TableRow(children: [_tc('1', font, 10), _tc('OPD Consultation Fee', font, 10), _tc(_fmtFee(fee), font, 10)]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Text('Total Payable:  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('#1B4F72'))),
            pw.Text('Rs. ${_fmtFee(fee)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#1B4F72'))),
          ]),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColor.fromHex('#D5E8F7')),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Generated: ${_fmtDateTime(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text(widget.hospital.name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B4F72'))),
          ]),
        ],
      ),
    ));

    return doc.save();
  }

  static pw.Widget _lbl(String text, pw.Font boldFont) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Text(text, style: pw.TextStyle(font: boldFont, fontSize: 7, letterSpacing: 0.5, color: PdfColors.grey600)),
      );

  static pw.Widget _tc(String text, pw.Font font, double size, {bool header = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: size, fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  String _pdfFmtDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  // ── Flutter build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.background, appBar: _buildAppBar(context), body: _buildBody(context));
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context, true)),
      title: const Text('OPD Bill', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      actions: [
        if (_sharing)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
        else
          IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), tooltip: 'Share / Print Bill', onPressed: _share),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = widget.patient;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA12), boxShadow: [BoxShadow(color: AppColors.primaryA08, blurRadius: 24, offset: const Offset(0, 4))]),
                child: Column(children: [_buildHeader(), const Divider(height: 1), _buildPatientInfo(p), const Divider(height: 1), _buildFeeTable(p), const Divider(height: 1), _buildFooter()]),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(color: AppColors.tealA12, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.teal.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20),
                  const SizedBox(width: 8),
                  Text(p.type == 'phone' ? 'Phone appointment registered' : 'Patient registered successfully', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal.withValues(alpha: 0.9))),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: _sharing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share / Print Bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA18, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)), elevation: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA18)), alignment: Alignment.center, child: Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 30)),
        const SizedBox(height: 10),
        Text(widget.hospital.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text('OPD BILL / RECEIPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.primary))),
      ]),
    );
  }

  Widget _buildPatientInfo(Patient p) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoLabel('MRD No.'),
              _infoValue(p.patientCode, bold: true, color: AppColors.primary),
              const SizedBox(height: 10),
              _infoLabel('Patient Name'),
              _infoValue(p.fullName),
              const SizedBox(height: 10),
              _infoLabel('Age / Gender'),
              _infoValue([if (p.age != null) '${p.age} yrs', if (p.gender != null) p.gender![0].toUpperCase() + p.gender!.substring(1)].join(' / ')),
              const SizedBox(height: 10),
              _infoLabel('Contact'),
              _infoValue(p.contactNo ?? '—'),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoLabel('Date'),
              _infoValue(_fmtDate(p.appointmentDate)),
              const SizedBox(height: 10),
              _infoLabel('Consultant'),
              _infoValue(p.doctor?.name ?? '—'),
              if (p.doctorPatientNo != null) ...[const SizedBox(height: 10), _infoLabel('Doctor Serial'), _infoValue(p.doctorPatientNo!.toString().padLeft(3, '0'), bold: true, color: AppColors.primary)],
              const SizedBox(height: 10),
              _infoLabel('Type'),
              _infoValue(p.type == 'walkin' ? 'Walk-in' : 'Phone Appt'),
              const SizedBox(height: 10),
              _infoLabel('Case'),
              _infoValue(p.caseType?.caseType ?? '—'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTable(Patient p) {
    final fee = p.caseFee ?? 0.0;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [
              Expanded(flex: 1, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
              Expanded(flex: 5, child: Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
              Text('Amount (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA70)),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              const Expanded(flex: 1, child: Text('1', style: TextStyle(fontSize: 13, color: Colors.black54))),
              const Expanded(flex: 5, child: Text('OPD Consultation Fee', style: TextStyle(fontSize: 13))),
              Text(_fmtFee(fee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border(top: BorderSide(color: AppColors.primaryA18))),
            child: Row(children: [
              Expanded(child: Text('Total Payable', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary))),
              const SizedBox(width: 16),
              Text('₹${_fmtFee(fee)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(children: [
        Text('Generated: ${_fmtDateTime(now)}', style: TextStyle(fontSize: 11, color: AppColors.primaryA55)),
        const Spacer(),
        Text(widget.hospital.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryA70)),
      ]),
    );
  }

  Widget _infoLabel(String text) => Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.primaryA55));

  Widget _infoValue(String text, {bool bold = false, Color? color}) => Text(text.isEmpty ? '—' : text, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? Colors.black87));

  String _fmtDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _fmtDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h12:$min $period';
  }

  String _fmtFee(double v) => v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);
}
