import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../models/patient_history_models.dart';
import '../services/patient_history_service.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import 'prescription_print_screen.dart';

/// Tablet Patient History — Pattern G. Embedded in the Patients detail pane
/// (no own Scaffold/AppBar). Clinical data tables (refraction/O-E/fundus)
/// ported verbatim from eye_care_app/lib/screens/patient_history_screen.dart
/// — these are already dense grids that benefit from tablet width as-is.
/// "Print Rx" pushes PrescriptionPrintScreen as a full-screen route.
class PatientHistoryScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;
  final VoidCallback onBack;
  final void Function(String label) onNotReady;

  const PatientHistoryScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.patient,
    required this.onBack,
    required this.onNotReady,
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  ExamHistoryData? _history;
  bool _loading = true;
  String? _error;

  final Set<int> _expanded = {};
  final Set<String> _partnerExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await PatientHistoryService.instance.fetchHistory(widget.patient.id);
      if (mounted) {
        setState(() {
          _history = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadHistory,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 14),
                _buildInfoGrid(),
                const SizedBox(height: 14),
                _buildTimeline(),
                if (_history != null)
                  ..._history!.partnerHospitals.asMap().entries.map((e) => Column(children: [
                        const SizedBox(height: 14),
                        _buildPartnerSection(e.key, e.value),
                      ])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final p = widget.patient;
    return Row(children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary), onPressed: widget.onBack, tooltip: 'Back'),
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.fullName, style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
          Text('MRD: ${p.patientCode}  ·  ${p.age != null ? "${p.age}y / " : ""}${p.genderDisplay}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _buildStatusBadge() {
    final p = widget.patient;
    final isCheckedIn = p.caseId != null;
    final bgColor = isCheckedIn ? const Color(0xFFD5F5E3) : const Color(0xFFFFF3CD);
    final borderColor = isCheckedIn ? const Color(0xFF82E0AA) : const Color(0xFFFFD57F);
    final textColor = isCheckedIn ? const Color(0xFF1E8449) : const Color(0xFF856404);
    final label = isCheckedIn ? 'Checked In' : 'Pending Check-In';
    final icon = isCheckedIn ? Icons.check_circle_rounded : Icons.schedule_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: borderColor)),
      child: Row(children: [
        Icon(icon, color: textColor, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        const Spacer(),
        if (p.doctorPatientNo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA18)),
            child: Text('Serial #${p.doctorPatientNo!.toString().padLeft(3, '0')}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
      ]),
    );
  }

  Widget _buildInfoGrid() {
    final p = widget.patient;
    final cards = [
      _infoCard(icon: Icons.phone_rounded, title: 'Contact', rows: [('Mobile', p.contactNo ?? '—'), ('WhatsApp', p.whatsappNo ?? 'Same as mobile'), ('City', p.location?.city ?? '—')]),
      _infoCard(icon: Icons.calendar_today_rounded, title: 'Appointment', rows: [('Date', _fmtDate(p.appointmentDate)), ('Doctor', p.doctor?.name ?? '—'), ('Type', p.type == 'walkin' ? 'Walk-in' : 'Phone Appt')]),
      _infoCard(icon: Icons.receipt_long_rounded, title: 'Case Details', rows: [('Case Type', p.caseType?.caseType ?? '—'), ('Case Fee', p.caseFee != null ? '₹${_fmtFee(p.caseFee!)}' : '—'), ('Referred By', p.referrer?.name ?? '—')]),
      _infoCard(icon: Icons.info_rounded, title: 'Registration', rows: [('MRD', p.patientCode), ('Occupation', p.occupation ?? '—'), ('Registered', p.createdAt != null ? _fmtDateTime(p.createdAt!) : '—')]),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : c.maxWidth >= 560 ? 2 : 1;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((card) => SizedBox(width: (c.maxWidth - (cols - 1) * 12) / cols, child: card)).toList(),
      );
    });
  }

  Widget _infoCard({required IconData icon, required String title, required List<(String, String)> rows}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA12), boxShadow: [BoxShadow(color: AppColors.primaryA08, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text(title.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.primaryA55)),
          ]),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primaryA55)),
                  const SizedBox(height: 2),
                  Text(r.$2.isEmpty ? '—' : r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A202C))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA12), boxShadow: [BoxShadow(color: AppColors.primaryA08, blurRadius: 12, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(color: AppColors.primaryA06, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)), border: Border(bottom: BorderSide(color: AppColors.primaryA10))),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('CLINICAL TIMELINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.primary)),
              const Spacer(),
              if (_history != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Text('${_history!.patient.visitDays} visit${_history!.patient.visitDays == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildTimelineBody()),
        ],
      ),
    );
  }

  Widget _buildTimelineBody() {
    if (_loading) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(Icons.wifi_off_rounded, size: 38, color: AppColors.primaryA50),
          const SizedBox(height: 12),
          Text('Failed to load history', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryA62)),
          const SizedBox(height: 4),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.primaryA50)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadHistory, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)))),
        ]),
      );
    }
    if (_history == null || _history!.exams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(children: [
            Icon(Icons.folder_open_rounded, size: 38, color: AppColors.primaryA50),
            const SizedBox(height: 12),
            Text('No examination records found.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryA62)),
          ]),
        ),
      );
    }
    final grouped = _history!.byDate;
    return Column(children: grouped.entries.map((entry) => _buildDateGroup(entry.key, entry.value)).toList());
  }

  Widget _buildDateGroup(String date, List<ExamRecord> exams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white),
                const SizedBox(width: 5),
                Text(date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryA24, AppColors.primaryA06]), borderRadius: BorderRadius.circular(1)))),
            const SizedBox(width: 8),
            Text('${exams.length} exam${exams.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryA50)),
          ]),
        ),
        ...exams.map((e) => _buildExamCard(e)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExamCard(ExamRecord exam) {
    final isPrimary = exam.isPrimary;
    final isExpanded = _expanded.contains(exam.id);
    final headerBg = isPrimary ? AppColors.primaryA08 : const Color(0xFFF3F4F6);
    final headerFg = isPrimary ? AppColors.primary : const Color(0xFF6B7280);
    final label = isPrimary ? 'Primary Exam' : 'Secondary Exam';
    final icon = isPrimary ? Icons.assignment_outlined : Icons.remove_red_eye_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA12), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 6, offset: const Offset(0, 2))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: headerBg,
          child: Row(children: [
            Icon(icon, size: 16, color: headerFg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headerFg)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA12)),
              child: Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: AppColors.primaryA62),
                const SizedBox(width: 3),
                Text(_fmtTime(exam.examinedAt), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA62)),
              ]),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exam.doctorName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: AppColors.primaryA50),
                    const SizedBox(width: 4),
                    Text('Examined by: ', style: TextStyle(fontSize: 12, color: AppColors.primaryA50)),
                    Text('Dr. ${exam.doctorName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() => isExpanded ? _expanded.remove(exam.id) : _expanded.add(exam.id)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: isExpanded ? AppColors.primaryA08 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: isExpanded ? AppColors.primaryA24 : AppColors.primaryA18)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isExpanded ? Icons.visibility_off_outlined : Icons.description_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(isExpanded ? 'Hide Clinical Data' : 'View Clinical Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                    ]),
                  ),
                ),
                if (exam.prescriptions.isNotEmpty && PermissionService.instance.can(Perm.opdPrescriptionPrint)) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(appRoute(PrescriptionPrintScreen(exam: exam, patient: _history!.patient, hospital: widget.hospital))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.primaryA18)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.print_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Print Rx', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ]),
                    ),
                  ),
                ],
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isExpanded ? Padding(padding: const EdgeInsets.only(top: 12), child: _buildClinicalData(exam)) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildClinicalData(ExamRecord exam, {Map<int, String>? diagnosisMap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBox('History & Vision', _buildHistoryVision(exam)),
        const SizedBox(height: 8),
        _buildBox('Subjective Testing (ST) & Diagnosis & Rx', _buildStAndRx(exam, diagnosisMap: diagnosisMap)),
        const SizedBox(height: 8),
        _buildBox('On Examination (O/E)', _buildOeTable(exam.oe)),
        const SizedBox(height: 8),
        _buildBox('Fundus', _buildFundusTable(exam.fundus)),
        if (exam.advice.trim().isNotEmpty) ...[const SizedBox(height: 8), _buildBox('Advice', _buildAdvice(exam.advice))],
      ],
    );
  }

  Widget _buildBox(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.primaryA18), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: const BorderRadius.vertical(top: Radius.circular(7))),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
        ),
        Padding(padding: const EdgeInsets.all(8), child: content),
      ]),
    );
  }

  Widget _buildHistoryVision(ExamRecord exam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('C/O'),
        _buildTable(
          headers: const ['Complaint', 'Since', 'Eye', 'Comment'],
          widths: const [2.0, 1.0, 1.0, 1.5],
          rows: exam.coRows.where((r) => (r['complaint'] ?? '').isNotEmpty).map((r) => <String>[(r['complaint'] ?? '-').toString(), '${r['since'] ?? '-'} ${r['unit'] ?? ''}'.trim(), (r['eye'] ?? '-').toString(), (r['comment'] ?? '-').toString()]).toList(),
          emptyLabel: '—',
        ),
        if (exam.kcoRows.where((r) => (r['condition'] ?? '').isNotEmpty).isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildSectionLabel('K/C/O'),
          _buildTable(
            headers: const ['Condition', 'Since', 'Comment'],
            widths: const [2.0, 1.0, 1.5],
            rows: exam.kcoRows.where((r) => (r['condition'] ?? '').isNotEmpty).map((r) => <String>[(r['condition'] ?? '-').toString(), '${r['since'] ?? '-'} ${r['unit'] ?? ''}'.trim(), (r['comment'] ?? '-').toString()]).toList(),
            emptyLabel: '—',
          ),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 4, children: [
          _vnChip('Vn', _cv(exam.vision['vn_re']), _cv(exam.vision['vn_le'])),
          _vnChip('PH', _cv(exam.vision['pnvn_re']), _cv(exam.vision['pnvn_le'])),
          _vnChip('NrVn', _cv(exam.vision['nrvn_re']), _cv(exam.vision['nrvn_le'])),
          _vnChip('IOP', _cv(exam.nct['iop_re']), _cv(exam.nct['iop_le'])),
        ]),
        const SizedBox(height: 8),
        _buildRefractionTable(exam.pgRe, exam.pgLe),
      ],
    );
  }

  Widget _vnChip(String label, String re, String le) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primaryA06, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primaryA12)),
      child: RichText(
        text: TextSpan(style: TextStyle(fontSize: 11, color: AppColors.primary), children: [
          TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: '$re/$le'),
        ]),
      ),
    );
  }

  Widget _buildRefractionTable(Map<String, dynamic> re, Map<String, dynamic> le) {
    return Table(
      border: TableBorder.all(color: AppColors.primaryA18, width: 0.8),
      columnWidths: const {0: FixedColumnWidth(18), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth(), 4: FlexColumnWidth(), 5: FlexColumnWidth(), 6: FlexColumnWidth(), 7: FlexColumnWidth(), 8: FlexColumnWidth()},
      children: [
        TableRow(decoration: BoxDecoration(color: AppColors.primary), children: [_th(''), _th('RIGHT EYE (RE)'), _th(''), _th(''), _th(''), _th('LEFT EYE (LE)'), _th(''), _th(''), _th('')]),
        TableRow(decoration: BoxDecoration(color: AppColors.primaryA08), children: [_thSub(''), _thSub('SPH'), _thSub('CYL'), _thSub('AXIS'), _thSub('VN'), _thSub('SPH'), _thSub('CYL'), _thSub('AXIS'), _thSub('VN')]),
        TableRow(children: [_rowLabel('D'), _td(_cv(re['ds'])), _td(_cv(re['dc'])), _td(_cv(re['ax'])), _td(_cv(re['vn'])), _td(_cv(le['ds'])), _td(_cv(le['dc'])), _td(_cv(le['ax'])), _td(_cv(le['vn']))]),
        TableRow(children: [_rowLabel('N'), _td(_cv(re['ns'])), _td(_cv(re['nc'])), _td(_cv(re['na'])), _td(_cv(re['near_vn'])), _td(_cv(le['ns'])), _td(_cv(le['nc'])), _td(_cv(le['na'])), _td(_cv(le['near_vn']))]),
      ],
    );
  }

  Widget _buildStAndRx(ExamRecord exam, {Map<int, String>? diagnosisMap}) {
    final effectiveDx = diagnosisMap ?? _history!.diagnosisMasters;
    final dxIds = exam.diagnoses.map((id) => (id is num) ? id.toInt() : int.tryParse(id.toString())).whereType<int>().toList();
    final dxNames = dxIds.map((id) => effectiveDx[id] ?? '').where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRefractionTable(exam.stRe, exam.stLe),
        if ((exam.stRe['add'] ?? '').isNotEmpty || (exam.stLe['add'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text('ADD  ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
            Text('RE: ${exam.stRe['add'] ?? '-'}  LE: ${exam.stLe['add'] ?? '-'}', style: TextStyle(fontSize: 11, color: AppColors.primary)),
          ]),
        ],
        if (exam.stBadges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: exam.stBadges.map((b) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.md)), child: Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)))).toList()),
        ],
        const SizedBox(height: 8),
        _buildSectionLabel('Diagnosis & Rx'),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(children: [
            RichText(
              text: TextSpan(style: TextStyle(fontSize: 11, color: AppColors.primary), children: [
                const TextSpan(text: 'Dx: ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: dxNames.isEmpty ? '-' : dxNames),
                const TextSpan(text: '   Dilate: ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: exam.dilate),
              ]),
            ),
          ]),
        ),
        _buildTable(headers: const ['Medicine', 'Dosage', 'Days', 'Eye'], widths: const [2.5, 1.2, 1.0, 1.0], rows: exam.prescriptions.map((rx) => [rx.medicineName, rx.dosage, rx.duration, rx.eye]).toList(), emptyLabel: 'No medicines'),
      ],
    );
  }

  Widget _buildOeTable(Map<String, dynamic> oe) {
    const fields = [('sac', 'SAC'), ('lid', 'LID'), ('conj', 'CONJ'), ('cornea', 'CORNEA'), ('ac', 'AC'), ('iris', 'IRIS'), ('pupil', 'PUPIL'), ('lens', 'LENS'), ('em', 'EM'), ('covertest', 'COVERTEST'), ('other', 'OTHER')];
    return Table(
      border: TableBorder.all(color: AppColors.primaryA18, width: 0.8),
      columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0)},
      children: [
        TableRow(decoration: BoxDecoration(color: AppColors.primary), children: [_th('O/E', align: TextAlign.left), _th('RIGHT'), _th('LEFT')]),
        ...fields.map((f) => TableRow(children: [_rowLabel(f.$2, align: TextAlign.left), _td(_cv(oe['${f.$1}_re'])), _td(_cv(oe['${f.$1}_le']))])),
      ],
    );
  }

  Widget _buildFundusTable(Map<String, dynamic> fundus) {
    return Table(
      border: TableBorder.all(color: AppColors.primaryA18, width: 0.8),
      columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1.0), 2: FlexColumnWidth(1.0)},
      children: [
        TableRow(decoration: BoxDecoration(color: AppColors.primary), children: [_th('Fundus', align: TextAlign.left), _th('RIGHT'), _th('LEFT')]),
        TableRow(children: [_rowLabel('DISC', align: TextAlign.left), _td(_cv(fundus['disc_re'])), _td(_cv(fundus['disc_le']))]),
        TableRow(children: [_rowLabel('FR', align: TextAlign.left), _td(_cv(fundus['fr_re'])), _td(_cv(fundus['fr_le']))]),
        TableRow(children: [_rowLabel('COMMENT', align: TextAlign.left), _td(_cv(fundus['comment_re'])), _td(_cv(fundus['comment_le']))]),
      ],
    );
  }

  Widget _buildAdvice(String text) => Text(text.trim(), style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.primary));

  Widget _buildSectionLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.3)));

  Widget _buildTable({required List<String> headers, required List<double> widths, required List<List<String>> rows, required String emptyLabel}) {
    final colWidths = <int, TableColumnWidth>{};
    for (var i = 0; i < widths.length; i++) {
      colWidths[i] = FlexColumnWidth(widths[i]);
    }
    return Table(
      border: TableBorder.all(color: AppColors.primaryA18, width: 0.8),
      columnWidths: colWidths,
      children: [
        TableRow(decoration: BoxDecoration(color: AppColors.primary), children: headers.asMap().map((i, h) => MapEntry(i, _th(h, align: i == 0 ? TextAlign.left : TextAlign.center))).values.toList()),
        if (rows.isEmpty)
          TableRow(children: [
            TableCell(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(emptyLabel, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.primaryA50)))),
            ...List.generate(headers.length - 1, (_) => const TableCell(child: SizedBox())),
          ])
        else
          ...rows.map((row) => TableRow(children: row.asMap().map((i, cell) => MapEntry(i, i == 0 ? _rowLabel(cell, align: TextAlign.left) : _td(cell))).values.toList())),
      ],
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.center}) => TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(text, textAlign: align, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))));

  Widget _thSub(String text) => TableCell(child: Container(color: AppColors.primaryA08, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primaryA62))));

  Widget _rowLabel(String text, {TextAlign align = TextAlign.center}) => TableCell(child: Container(color: AppColors.primaryA06, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5), child: Text(text, textAlign: align, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary))));

  Widget _td(String text) => TableCell(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5), child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.primary))));

  static String _cv(dynamic v) => (v != null && v != '') ? v.toString() : '-';

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _fmtDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h12:$min $p';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$min $p';
  }

  String _fmtFee(double v) => v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

  Widget _buildPartnerSection(int idx, PartnerHospitalHistory partner) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA18), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFEEF3FB), border: Border(bottom: BorderSide(color: AppColors.primaryA12))),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(partner.hospitalName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  if (partner.locationLine.isNotEmpty) Text(partner.locationLine, style: TextStyle(fontSize: 11, color: AppColors.primaryA62)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.link_rounded, size: 11, color: Colors.white), SizedBox(width: 4), Text('PARTNER HOSPITAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: partner.exams.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('No examination records at this hospital', style: TextStyle(fontSize: 13, color: AppColors.primaryA50))))
                : Column(children: partner.byDate.entries.map((e) => _buildPartnerDateGroup(idx, e.key, e.value, partner.diagnosisMasters)).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerDateGroup(int partnerIdx, String date, List<ExamRecord> exams, Map<int, String> dm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white), const SizedBox(width: 5), Text(date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryA24, AppColors.primaryA06]), borderRadius: BorderRadius.circular(1)))),
            const SizedBox(width: 8),
            Text('${exams.length} exam${exams.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryA50)),
          ]),
        ),
        ...exams.map((e) => _buildPartnerExamCard(partnerIdx, e, dm)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPartnerExamCard(int partnerIdx, ExamRecord exam, Map<int, String> dm) {
    final isPrimary = exam.isPrimary;
    final expandKey = '${partnerIdx}_${exam.id}';
    final isExpanded = _partnerExpanded.contains(expandKey);
    final headerBg = isPrimary ? AppColors.primaryA08 : const Color(0xFFF3F4F6);
    final headerFg = isPrimary ? AppColors.primary : const Color(0xFF6B7280);
    final label = isPrimary ? 'Primary Exam' : 'Secondary Exam';
    final icon = isPrimary ? Icons.assignment_outlined : Icons.remove_red_eye_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA12), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 6, offset: const Offset(0, 2))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: headerBg,
          child: Row(children: [
            Icon(icon, size: 16, color: headerFg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headerFg)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA12)),
              child: Row(children: [Icon(Icons.access_time_rounded, size: 11, color: AppColors.primaryA62), const SizedBox(width: 3), Text(_fmtTime(exam.examinedAt), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA62))]),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (exam.doctorName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: AppColors.primaryA50),
                    const SizedBox(width: 4),
                    Text('Examined by: ', style: TextStyle(fontSize: 12, color: AppColors.primaryA50)),
                    Text('Dr. ${exam.doctorName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ),
              GestureDetector(
                onTap: () => setState(() => isExpanded ? _partnerExpanded.remove(expandKey) : _partnerExpanded.add(expandKey)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: isExpanded ? AppColors.primaryA08 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: isExpanded ? AppColors.primaryA24 : AppColors.primaryA18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isExpanded ? Icons.visibility_off_outlined : Icons.description_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(isExpanded ? 'Hide Clinical Data' : 'View Clinical Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(width: 4),
                    Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primary),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isExpanded ? Padding(padding: const EdgeInsets.only(top: 12), child: _buildClinicalData(exam, diagnosisMap: dm)) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
