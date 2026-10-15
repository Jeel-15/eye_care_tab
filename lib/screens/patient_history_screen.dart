import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../models/patient_history_models.dart';
import '../services/patient_history_service.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/exam_clinical_data_view.dart';
import '../widgets/skeleton.dart';
import 'prescription_print_screen.dart';
import 'patient_history_print_screen.dart';
import 'primary_exam_screen.dart';
import 'secondary_exam_screen.dart';

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
  // Share History's connected-hospital patients aren't fetchable through the
  // normal tenant-scoped history endpoint — this lets that one call site
  // swap in ShareHistoryService.fetchPartnerPatientHistory() instead, while
  // every other call site keeps using the default (PatientHistoryService).
  final Future<ExamHistoryData> Function(int patientId)? historyLoader;

  const PatientHistoryScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.patient,
    required this.onBack,
    required this.onNotReady,
    this.historyLoader,
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  ExamHistoryData? _history;
  bool _loading = true;
  String? _error;

  final Set<int> _fullExam = {};
  final Set<String> _partnerFull = {};

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
      final loader = widget.historyLoader ?? PatientHistoryService.instance.fetchHistory;
      final data = await loader(widget.patient.id);
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
    // Compact visual density tightens every stock Material control on this
    // screen (IconButtons, ElevatedButtons) to match the hand-tuned tight
    // spacing of the custom rows below — part of the same "less vertical
    // space, one-glance scan" pass.
    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Expanded(
          child: AppRefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadHistory,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Staggered ~120ms-per-section entrance (not the default
                // 30ms — this modal has a handful of large sections, not a
                // long list of small rows, so each one should read as its
                // own beat instead of arriving all at once).
                AnimatedListItem(index: 0, staggerMs: 120, child: _buildFacts()),
                const SizedBox(height: 10),
                AnimatedListItem(index: 1, staggerMs: 120, child: _buildTimeline()),
                if (_history != null)
                  ..._history!.partnerHospitals.asMap().entries.map((e) => Column(children: [
                        const SizedBox(height: 10),
                        AnimatedListItem(index: 2 + e.key, staggerMs: 120, child: _buildPartnerSection(e.key, e.value)),
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
    final isWalkin = p.type == 'walkin';
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary), onPressed: widget.onBack, tooltip: 'Back'),
      GradientAvatar(p.fullName, size: 44),
      const SizedBox(width: 12),
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.fullName, style: const TextStyle(color: AppColors.darkNavy, fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Pill(isWalkin ? 'Walk-in' : 'Phone', bg: (isWalkin ? AppColors.blue : AppColors.purple).withValues(alpha: 0.10), fg: isWalkin ? AppColors.blue : AppColors.purple, outlined: true),
              ExamChip(label: 'Primary', done: p.primaryDoneAt != null, when: p.primaryDoneAt != null ? _fmtDateTime(p.primaryDoneAt!) : null),
              ExamChip(label: 'Secondary', done: p.secondaryDoneAt != null, when: p.secondaryDoneAt != null ? _fmtDateTime(p.secondaryDoneAt!) : null),
              if (p.isOldPatient) Pill('Returning', bg: AppColors.teal.withValues(alpha: 0.10), fg: AppColors.teal),
            ]),
            const SizedBox(height: 4),
            Text('MRD ${p.patientCode}${p.age != null ? ' · ${p.age}y' : ''} · ${p.genderDisplay}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HeaderFacts([
            HeaderFact('Doctor', p.doctor?.name),
            HeaderFact('Case', p.caseType?.caseType),
            HeaderFact('Date', _fmtDate(p.appointmentDate)),
            HeaderFact('Fee', p.caseFee != null ? '${widget.hospital.currencySymbol}${_fmtFee(p.caseFee!)}' : null),
          ]),
        ),
      ),
      if (_history != null && _history!.exams.isNotEmpty)
        PressScaleWrapper(
          onTap: () => Navigator.of(context, rootNavigator: true).push(appRoute(PatientHistoryPrintScreen(
            patient: _history!.patient,
            exams: _history!.exams,
            diagnosisMasters: _history!.diagnosisMasters,
            hospital: widget.hospital,
          ))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.print_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          ),
        ),
    ]);
  }

  Widget _buildFacts() {
    final p = widget.patient;
    final phone = p.contactNo?.trim() ?? '';
    final wa = p.whatsappNo?.trim() ?? '';
    return FactSheet(sections: [
      FactSection('', [
        Fact('Phone', phone.isEmpty ? null : phone),
        Fact('WhatsApp', wa.isEmpty || wa == phone ? null : wa),
        Fact('City', p.location?.city),
        Fact('Occupation', p.occupation),
        Fact('Referred by', p.referrer?.name),
        Fact('Registered', p.createdAt != null ? _fmtDateTime(p.createdAt!) : null),
      ]),
    ]);
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Text('Clinical timeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
          const Spacer(),
          if (_history != null) Pill('${_history!.patient.visitDays} visit${_history!.patient.visitDays == 1 ? '' : 's'}', bg: AppColors.primaryA08, fg: AppColors.primary, outlined: true),
        ]),
        const SizedBox(height: 8),
        _buildTimelineBody(),
      ],
    );
  }

  Widget _buildTimelineBody() {
    if (_loading) {
      return const AppSkeletonList(count: 4, itemHeight: 80);
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primary.withValues(alpha: 0.22))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: AppColors.primaryA10)),
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
    final showFull = _fullExam.contains(exam.id);
    final accent = isPrimary ? AppColors.blue : AppColors.purple;
    final label = isPrimary ? 'Primary Exam' : 'Secondary Exam';
    final icon = isPrimary ? Icons.assignment_outlined : Icons.remove_red_eye_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withValues(alpha: 0.16)), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: accent.withValues(alpha: 0.08),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accent)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: accent.withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: accent.withValues(alpha: 0.75)),
                const SizedBox(width: 3),
                Text(_fmtTime(exam.examinedAt), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent.withValues(alpha: 0.75))),
              ]),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
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
                if (exam.prescriptions.isNotEmpty && PermissionService.instance.can(Perm.opdPrescriptionPrint)) ...[
                  ViewSideButton(icon: Icons.print_outlined, label: 'Print Rx', onTap: () => Navigator.of(context, rootNavigator: true).push(appRoute(PrescriptionPrintScreen(exam: exam, patient: _history!.patient, hospital: widget.hospital)))),
                  const SizedBox(width: 8),
                ],
                if (PermissionService.instance.can(isPrimary ? Perm.opdExamPrimary : Perm.opdExamSecondary))
                  ViewSideButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () => Navigator.of(context, rootNavigator: true).push(appRoute(isPrimary
                        ? PrimaryExamScreen(user: widget.user, hospital: widget.hospital, patient: widget.patient)
                        : SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: widget.patient))),
                  ),
                const Spacer(),
                ViewSideButton(
                  icon: showFull ? Icons.compress_rounded : Icons.open_in_full_rounded,
                  label: showFull ? 'Filled only' : 'Full exam',
                  active: showFull,
                  onTap: () => setState(() => showFull ? _fullExam.remove(exam.id) : _fullExam.add(exam.id)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: buildExamClinicalData(exam, _history!.diagnosisMasters, onlyFilled: !showFull),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // Hospital-timezone-aware (not raw UTC / device-local) — see
  // PATIENT_DATE_TIME_DISPLAY_AUDIT.md.
  String _fmtDate(String? s) => formatDateString(s);

  String _fmtDateTime(DateTime dt) => toDisplayDateTime(dt);

  String _fmtTime(DateTime dt) {
    final local = toHospitalTime(dt);
    final h = local.hour;
    final min = local.minute.toString().padLeft(2, '0');
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
    final showFull = _partnerFull.contains(expandKey);
    final accent = isPrimary ? AppColors.blue : AppColors.purple;
    final label = isPrimary ? 'Primary Exam' : 'Secondary Exam';
    final icon = isPrimary ? Icons.assignment_outlined : Icons.remove_red_eye_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withValues(alpha: 0.16)), boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: accent.withValues(alpha: 0.08),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 9),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: accent)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: accent.withValues(alpha: 0.2))),
              child: Row(children: [Icon(Icons.access_time_rounded, size: 11, color: accent.withValues(alpha: 0.75)), const SizedBox(width: 3), Text(_fmtTime(exam.examinedAt), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent.withValues(alpha: 0.75)))]),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
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
                const Spacer(),
                ViewSideButton(
                  icon: showFull ? Icons.compress_rounded : Icons.open_in_full_rounded,
                  label: showFull ? 'Filled only' : 'Full exam',
                  active: showFull,
                  onTap: () => setState(() => showFull ? _partnerFull.remove(expandKey) : _partnerFull.add(expandKey)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: buildExamClinicalData(exam, dm, onlyFilled: !showFull),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
