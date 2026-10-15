import '../utils/date_format.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/patient_history_models.dart';

/// Builds a PDF covering a patient's *entire* clinical timeline — every
/// exam (Primary + Secondary, all dates) with full clinical data — mirroring
/// web's "Print Full History" (the printer icon next to the Clinical
/// Timeline heading in Patient History). Distinct from
/// [PrescriptionService], which only prints one exam's prescription.
/// See PATIENT_HISTORY_PRINT_PLAN.md.
class PatientHistoryPrintService {
  PatientHistoryPrintService._();
  static final PatientHistoryPrintService instance = PatientHistoryPrintService._();

  Future<Uint8List> generatePdf({
    required String hospitalName,
    required PatientHistorySummary patient,
    required List<ExamRecord> exams,
    Map<int, String> diagnosisMasters = const {},
    String? hospitalLogoUrl,
    // Web's Settings → Print "Letter Pad" toggle (hospital_setting
    // 'letter_pad') — see history-print.blade.php's `$letterPad !==
    // 'available'` branch: when letter pad paper is in use, the icon +
    // hospital-name/phone subtitle are dropped and only the plain
    // "Patient History" title remains, since the physical letterhead
    // already carries the branding.
    bool letterPadAvailable = false,
  }) async {
    final doc = pw.Document();
    final logo = await _fetchLogo(hospitalLogoUrl);
    final patientAge = patient.age != null ? '${patient.age} yrs' : '-';
    final patientGender = patient.gender != null ? _cap(patient.gender!) : '-';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated: ${_fmtDate(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
        build: (ctx) => [
          _buildHeader(hospitalName, logo, patient, patientAge, patientGender,
              letterPadAvailable),
          pw.Divider(color: PdfColors.grey400, height: 20),
          for (final exam in exams) ...[
            _examHeading(exam),
            pw.SizedBox(height: 6),
            _box('History & Vision', _historyVision(exam)),
            pw.SizedBox(height: 8),
            _box('Subjective Testing (ST) & Diagnosis & Rx',
                _stAndRx(exam, diagnosisMasters)),
            pw.SizedBox(height: 8),
            _box('On Examination (O/E)', _rightLeftTable('O/E', _oeRows(exam.oe))),
            pw.SizedBox(height: 8),
            _box('Fundus', _rightLeftTable('Fundus', _fundusRows(exam.fundus))),
            if (exam.advice.trim().isNotEmpty) ...[
              pw.SizedBox(height: 8),
              _box('Advice',
                  pw.Text(exam.advice.trim(), style: const pw.TextStyle(fontSize: 10))),
            ],
            pw.SizedBox(height: 18),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ───────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(
    String hospitalName,
    pw.MemoryImage? logo,
    PatientHistorySummary patient,
    String patientAge,
    String patientGender,
    bool letterPadAvailable,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: letterPadAvailable
              ? pw.Text('Patient History',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))
              : pw.Column(children: [
                  if (logo != null) ...[
                    pw.Image(logo, height: 40, fit: pw.BoxFit.contain),
                    pw.SizedBox(height: 6),
                  ],
                  pw.Text(hospitalName,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Patient Clinical History',
                      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                ]),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _labelValue('Patient', patient.name),
                _labelValue('MRD', patient.patientCode),
                _labelValue('Contact', patient.contactNo ?? '-'),
              ]),
            ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _labelValue('Age / Gender', '$patientAge / $patientGender'),
                _labelValue('Location', patient.location ?? '-'),
                _labelValue('Total Visits', '${patient.visitDays}'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _examHeading(ExamRecord exam) {
    final label = exam.isPrimary ? 'Primary Exam' : 'Secondary Exam';
    final color = exam.isPrimary ? PdfColors.blue900 : PdfColors.grey700;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(
            'Dr. ${exam.doctorName ?? "Unknown"}   ·   ${_fmtDateTime(exam.examinedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // ── Boxes (mirrors _buildClinicalData's on-screen sections) ───────────────

  pw.Widget _box(String title, pw.Widget content) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: PdfColors.blue900,
          child: pw.Text(title.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.4)),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: content),
      ]),
    );
  }

  pw.Widget _historyVision(ExamRecord exam) {
    final coRows = exam.coRows
        .cast<Map>()
        .where((r) => (r['complaint'] ?? '').toString().isNotEmpty)
        .toList();
    final kcoRows = exam.kcoRows
        .cast<Map>()
        .where((r) => (r['condition'] ?? '').toString().isNotEmpty)
        .toList();

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionLabel('C/O'),
      _simpleTable(
        headers: const ['Complaint', 'Since', 'Eye', 'Comment'],
        widths: const {0: 2.0, 1: 1.0, 2: 1.0, 3: 1.5},
        rows: coRows
            .map((r) => [
                  _cv(r['complaint']),
                  '${_cv(r['since'])} ${r['unit'] ?? ''}'.trim(),
                  _cv(r['eye']),
                  _cv(r['comment']),
                ])
            .toList(),
      ),
      if (kcoRows.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _sectionLabel('K/C/O'),
        _simpleTable(
          headers: const ['Condition', 'Since', 'Comment'],
          widths: const {0: 2.0, 1: 1.0, 2: 1.5},
          rows: kcoRows
              .map((r) => [
                    _cv(r['condition']),
                    '${_cv(r['since'])} ${r['unit'] ?? ''}'.trim(),
                    _cv(r['comment']),
                  ])
              .toList(),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Wrap(spacing: 10, runSpacing: 4, children: [
        _vnChip('Vn', _cv(exam.vision['vn_re']), _cv(exam.vision['vn_le'])),
        _vnChip('PH', _cv(exam.vision['pnvn_re']), _cv(exam.vision['pnvn_le'])),
        _vnChip('NrVn', _cv(exam.vision['nrvn_re']), _cv(exam.vision['nrvn_le'])),
        _vnChip('IOP', _cv(exam.nct['iop_re']), _cv(exam.nct['iop_le'])),
      ]),
      pw.SizedBox(height: 8),
      _refractionTable(exam.pgRe, exam.pgLe),
    ]);
  }

  pw.Widget _stAndRx(ExamRecord exam, Map<int, String> diagnosisMasters) {
    final dxIds = exam.diagnoses
        .map((id) => (id is num) ? id.toInt() : int.tryParse(id.toString()))
        .whereType<int>()
        .toList();
    final dxNames = dxIds.map((id) => diagnosisMasters[id] ?? '').where((s) => s.isNotEmpty).join(', ');

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _refractionTable(exam.stRe, exam.stLe),
      if ((exam.stRe['add'] ?? '').toString().isNotEmpty || (exam.stLe['add'] ?? '').toString().isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text('ADD   RE: ${_cv(exam.stRe['add'])}  LE: ${_cv(exam.stLe['add'])}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      ],
      if (exam.stBadges.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(exam.stBadges.join('  ·  '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
      pw.SizedBox(height: 8),
      pw.Text('Dx: ${dxNames.isEmpty ? "-" : dxNames}    Dilate: ${exam.dilate}',
          style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 8),
      _simpleTable(
        headers: const ['Medicine', 'Dosage', 'Days', 'Eye'],
        widths: const {0: 2.5, 1: 1.2, 2: 1.0, 3: 1.0},
        rows: exam.prescriptions.map((rx) => [rx.medicineName, rx.dosage, rx.duration, rx.eye]).toList(),
        emptyLabel: 'No medicines',
      ),
    ]);
  }

  List<(String, String, String)> _oeRows(Map<String, dynamic> oe) {
    const fields = [
      ('sac', 'SAC'), ('lid', 'LID'), ('conj', 'CONJ'), ('cornea', 'CORNEA'),
      ('ac', 'AC'), ('iris', 'IRIS'), ('pupil', 'PUPIL'), ('lens', 'LENS'),
      ('em', 'EM'), ('covertest', 'COVERTEST'), ('other', 'OTHER'),
    ];
    return fields.map((f) => (f.$2, _cv(oe['${f.$1}_re']), _cv(oe['${f.$1}_le']))).toList();
  }

  List<(String, String, String)> _fundusRows(Map<String, dynamic> fundus) => [
        ('DISC', _cv(fundus['disc_re']), _cv(fundus['disc_le'])),
        ('FR', _cv(fundus['fr_re']), _cv(fundus['fr_le'])),
        ('COMMENT', _cv(fundus['comment_re']), _cv(fundus['comment_le'])),
      ];

  // ── Table builders ─────────────────────────────────────────────────────────

  pw.Widget _refractionTable(Map<String, dynamic> re, Map<String, dynamic> le) {
    pw.Widget th(String t) => pw.Container(
        color: PdfColors.blue900,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)));
    pw.Widget thSub(String t) => pw.Container(
        color: PdfColors.grey200,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)));
    pw.Widget rowLabel(String t) => pw.Container(
        color: PdfColors.grey100,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)));
    pw.Widget td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(children: [th(''), th('RIGHT EYE (RE)'), th(''), th(''), th(''), th('LEFT EYE (LE)'), th(''), th(''), th('')]),
        pw.TableRow(children: [thSub(''), thSub('SPH'), thSub('CYL'), thSub('AXIS'), thSub('VN'), thSub('SPH'), thSub('CYL'), thSub('AXIS'), thSub('VN')]),
        pw.TableRow(children: [
          rowLabel('D'),
          td(_cv(re['ds'])), td(_cv(re['dc'])), td(_cv(re['ax'])), td(_cv(re['vn'])),
          td(_cv(le['ds'])), td(_cv(le['dc'])), td(_cv(le['ax'])), td(_cv(le['vn'])),
        ]),
        pw.TableRow(children: [
          rowLabel('N'),
          td(_cv(re['ns'])), td(_cv(re['nc'])), td(_cv(re['na'])), td(_cv(re['near_vn'])),
          td(_cv(le['ns'])), td(_cv(le['nc'])), td(_cv(le['na'])), td(_cv(le['near_vn'])),
        ]),
      ],
    );
  }

  pw.Widget _rightLeftTable(String title, List<(String, String, String)> rows) {
    pw.Widget th(String t, {pw.TextAlign align = pw.TextAlign.center}) => pw.Container(
        color: PdfColors.blue900,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(t, textAlign: align, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)));
    pw.Widget rowLabel(String t) => pw.Container(
        color: PdfColors.grey100,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)));
    pw.Widget td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(t, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(1.6), 1: const pw.FlexColumnWidth(1.0), 2: const pw.FlexColumnWidth(1.0)},
      children: [
        pw.TableRow(children: [th(title, align: pw.TextAlign.left), th('RIGHT'), th('LEFT')]),
        ...rows.map((r) => pw.TableRow(children: [rowLabel(r.$1), td(r.$2), td(r.$3)])),
      ],
    );
  }

  pw.Widget _simpleTable({
    required List<String> headers,
    required Map<int, double> widths,
    required List<List<String>> rows,
    String emptyLabel = 'None recorded',
  }) {
    pw.Widget cell(String t, {bool isHeader = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 8, fontWeight: isHeader ? pw.FontWeight.bold : null, color: isHeader ? PdfColors.white : null)));

    if (rows.isEmpty) {
      return pw.Text(emptyLabel, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: widths.map((k, v) => MapEntry(k, pw.FlexColumnWidth(v))),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: headers.map((h) => cell(h, isHeader: true)).toList(),
        ),
        ...rows.map((r) => pw.TableRow(children: r.map((v) => cell(v)).toList())),
      ],
    );
  }

  pw.Widget _vnChip(String label, String re, String le) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.RichText(
        text: pw.TextSpan(style: const pw.TextStyle(fontSize: 9), children: [
          pw.TextSpan(text: '$label  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: '$re/$le'),
        ]),
      ),
    );
  }

  pw.Widget _sectionLabel(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
      );

  pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<pw.MemoryImage?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
    } catch (_) {
      // Logo is a nice-to-have — never block generation over a failed fetch.
    }
    return null;
  }

  static String _cv(dynamic v) => (v != null && v != '') ? v.toString() : '-';

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _fmtDate(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _fmtDateTime(DateTime utc) {
    final dt = toHospitalTime(utc);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${_fmtDate(dt)}, $h:$mm $ampm';
  }
}
