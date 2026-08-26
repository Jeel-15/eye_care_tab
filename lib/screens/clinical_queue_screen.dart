import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/clinical_queue_models.dart';
import '../models/patient_models.dart';
import '../services/clinical_queue_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/exam/dilation_lock.dart';
import '../widgets/skeleton.dart';
import 'primary_exam_screen.dart';
import 'secondary_exam_screen.dart';

String _hhmm(DateTime? dt) {
  if (dt == null) return '--:--';
  final l = dt.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _chipDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _apiDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.primaryA10),
      boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 10, offset: const Offset(0, 3))],
    );

// One shared 1-second ticker drives every dilation countdown on screen.
final _queueTick = ValueNotifier<int>(0);
Timer? _queueTickTimer;
void _startQueueTicker() => _queueTickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _queueTick.value++);
void _stopQueueTicker() {
  _queueTickTimer?.cancel();
  _queueTickTimer = null;
}

/// Tablet Clinical Queue — Pattern G, widened into 3 simultaneous columns
/// (Primary / Dilation / Secondary) on wide layouts instead of mobile's
/// tab-switch — doctors/reception see the whole queue at a glance. Falls
/// back to tabs under the medium breakpoint. Business logic (fetch,
/// auto-refresh, wait thresholds, dilation countdown) ported unchanged from
/// eye_care_app/lib/screens/clinical_queue_screen.dart.
class ClinicalQueueScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const ClinicalQueueScreen({super.key, required this.user, required this.hospital});

  @override
  State<ClinicalQueueScreen> createState() => _ClinicalQueueScreenState();
}

class _ClinicalQueueScreenState extends State<ClinicalQueueScreen> with SingleTickerProviderStateMixin {
  QueueData? _data;
  bool _loading = false;
  String? _error;
  DateTime _filterDate = DateTime.now();
  int? _selectedDoctorId;

  late final TabController _tabCtrl;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    if (widget.user.role?.slug == 'doctor') _selectedDoctorId = widget.user.id;
    _startQueueTicker();
    _load();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _autoRefreshTimer?.cancel();
    _stopQueueTicker();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await ClinicalQueueService.instance.fetchQueue(date: _apiDate(_filterDate), doctorId: _selectedDoctorId);
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null && picked != _filterDate) {
      setState(() => _filterDate = picked);
      _load();
    }
  }

  void _selectDoctor(int? id) {
    if (_selectedDoctorId == id) return;
    setState(() => _selectedDoctorId = id);
    _load();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _filterDate.year == n.year && _filterDate.month == n.month && _filterDate.day == n.day;
  }

  Patient _patientFrom(QueuePatient q) => Patient(id: q.id, patientCode: q.patientCode, firstName: q.firstName, lastName: q.lastName, fullName: q.fullName, age: q.age, gender: q.gender, contactNo: q.contactNo, createdAt: q.createdAt, primaryDoneAt: q.primaryDoneAt);

  Future<void> _startPrimaryExam(QueuePatient q) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(PrimaryExamScreen(user: widget.user, hospital: widget.hospital, patient: _patientFrom(q))),
    );
    if (result == true && mounted) _load(silent: true);
  }

  Future<void> _startSecondaryExam(QueuePatient q) async {
    final ok = await canStartSecondaryExam(context, q.unlockTimeMs);
    if (!ok || !mounted) return;
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: _patientFrom(q))),
    );
    if (result == true && mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final otherDay = !_isToday;
    return Row(children: [
      Text('Clinical Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
      const Spacer(),
      GestureDetector(
        onTap: _selectDate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: otherDay ? const Color(0xFFD97706).withValues(alpha: 0.12) : AppColors.primaryA07,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: otherDay ? const Color(0xFFD97706).withValues(alpha: 0.45) : AppColors.primaryA18),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: otherDay ? const Color(0xFFD97706) : AppColors.primary),
            const SizedBox(width: 6),
            Text(_chipDate(_filterDate), style: TextStyle(color: otherDay ? const Color(0xFFD97706) : AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _loading ? null : _load,
        icon: _loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryA55)) : Icon(Icons.refresh_rounded, color: AppColors.primary),
      ),
    ]);
  }

  Widget _buildBody() {
    if (_loading && _data == null) return const AppSkeletonList();
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: const Color(0xFF6B7D93).withValues(alpha: 0.60)),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7D93), fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
          ]),
        ),
      );
    }
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    return Column(
      children: [
        _DoctorSection(data: data, selectedId: _selectedDoctorId, onSelect: _selectDoctor),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= AppBreakpoints.medium) {
              return _buildThreeColumn(data);
            }
            return _buildTabbed(data);
          }),
        ),
      ],
    );
  }

  // ── Wide: three simultaneous columns ──────────────────────────────────

  Widget _buildThreeColumn(QueueData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _QueueColumn(icon: Icons.visibility_rounded, label: 'Primary', count: data.totalPrimary, onRefresh: _load, child: _PrimaryQueueList(patients: data.primaryQueue, thresholds: data.thresholds, onStart: _startPrimaryExam))),
        const SizedBox(width: 14),
        Expanded(child: _QueueColumn(icon: Icons.hourglass_bottom_rounded, label: 'Dilation', count: data.totalDilation, onRefresh: _load, child: _DilationQueueList(patients: data.dilationQueue, thresholds: data.thresholds))),
        const SizedBox(width: 14),
        Expanded(child: _QueueColumn(icon: Icons.favorite_rounded, label: 'Secondary', count: data.totalSecondary, onRefresh: _load, child: _SecondaryQueueList(patients: data.secondaryQueue, thresholds: data.thresholds, onStart: _startSecondaryExam))),
      ],
    );
  }

  // ── Narrow: tab-switch fallback ────────────────────────────────────────

  Widget _buildTabbed(QueueData data) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF4F8FB), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA12)),
        child: AnimatedBuilder(
          animation: _tabCtrl,
          builder: (_, _) => Row(children: [
            _QueueTabBtn(icon: Icons.visibility_rounded, label: 'Primary', count: data.totalPrimary, active: _tabCtrl.index == 0, onTap: () => _tabCtrl.animateTo(0)),
            _QueueTabBtn(icon: Icons.hourglass_bottom_rounded, label: 'Dilation', count: data.totalDilation, active: _tabCtrl.index == 1, onTap: () => _tabCtrl.animateTo(1)),
            _QueueTabBtn(icon: Icons.favorite_rounded, label: 'Secondary', count: data.totalSecondary, active: _tabCtrl.index == 2, onTap: () => _tabCtrl.animateTo(2)),
          ]),
        ),
      ),
      Expanded(
        child: ListenableBuilder(
          listenable: _tabCtrl,
          builder: (_, _) => IndexedStack(index: _tabCtrl.index, children: [
            _PrimaryQueueList(patients: data.primaryQueue, thresholds: data.thresholds, onStart: _startPrimaryExam),
            _DilationQueueList(patients: data.dilationQueue, thresholds: data.thresholds),
            _SecondaryQueueList(patients: data.secondaryQueue, thresholds: data.thresholds, onStart: _startSecondaryExam),
          ]),
        ),
      ),
    ]);
  }
}

// ── Doctor assignment strip ─────────────────────────────────────────────

class _DoctorSection extends StatelessWidget {
  final QueueData data;
  final int? selectedId;
  final void Function(int? id) onSelect;

  const _DoctorSection({required this.data, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _AllDoctorsCard(data: data, isActive: selectedId == null, onTap: () => onSelect(null)),
          ...data.doctors.map((d) => Padding(padding: const EdgeInsets.only(left: 10), child: _DoctorCard(doctor: d, isActive: selectedId == d.id, onTap: () => onSelect(d.id)))),
        ],
      ),
    );
  }
}

class _AllDoctorsCard extends StatelessWidget {
  final QueueData data;
  final bool isActive;
  final VoidCallback onTap;
  const _AllDoctorsCard({required this.data, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Aggregate from data.doctors (per-doctor summaries, always unfiltered)
    // rather than data.totalPrimary/totalSecondary/totalDilation, which are
    // derived from primaryQueue/dilationQueue/secondaryQueue — lists that
    // are scoped to whichever doctor is currently selected. Using those here
    // made the "All Doctors" card show a specific doctor's counts (often 0)
    // instead of the true grand total whenever a doctor filter was active.
    final primaryN = data.doctors.fold<int>(0, (sum, d) => sum + d.primaryPending);
    final secondaryN = data.doctors.fold<int>(0, (sum, d) => sum + d.secondaryPending);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 152,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryA08 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.28) : AppColors.primaryA12, width: isActive ? 1.5 : 1),
          boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryA10), alignment: Alignment.center, child: Icon(Icons.groups_rounded, size: 19, color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('All Doctors', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF18324A)), overflow: TextOverflow.ellipsis),
                Text('${primaryN + secondaryN} Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
              ]),
            ),
          ]),
          const Spacer(),
          Wrap(spacing: 4, runSpacing: 4, children: [
            _CountPill(label: 'Primary', count: primaryN, filled: primaryN > 0, color: AppColors.primary),
            _CountPill(label: 'Secondary', count: secondaryN, filled: secondaryN > 0, color: const Color(0xFF2563EB)),
          ]),
        ]),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorSummary doctor;
  final bool isActive;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 152,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryA08 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.28) : AppColors.primaryA12, width: isActive ? 1.5 : 1),
          boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryA10), alignment: Alignment.center, child: Text(doctor.initials, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primary))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doctor.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF18324A)), overflow: TextOverflow.ellipsis, maxLines: 1),
                Text('${doctor.totalAssigned} Assigned', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
              ]),
            ),
          ]),
          const Spacer(),
          if (doctor.isAllClear)
            const Row(children: [Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF1F9D55)), SizedBox(width: 4), Text('All Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F9D55)))])
          else
            Wrap(spacing: 4, runSpacing: 4, children: [
              _CountPill(label: 'Primary', count: doctor.primaryPending, filled: doctor.primaryPending > 0, color: AppColors.primary),
              _CountPill(label: 'Secondary', count: doctor.secondaryPending, filled: doctor.secondaryPending > 0, color: const Color(0xFF2563EB)),
            ]),
        ]),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label;
  final int count;
  final bool filled;
  final Color color;
  const _CountPill({required this.label, required this.count, required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: filled ? color : color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999), border: filled ? null : Border.all(color: color.withValues(alpha: 0.20))),
      child: Text('$label $count', style: TextStyle(color: filled ? Colors.white : color.withValues(alpha: 0.70), fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

// ── Column shell (wide layout) ──────────────────────────────────────────

class _QueueColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Future<void> Function() onRefresh;
  final Widget child;

  const _QueueColumn({required this.icon, required this.label, required this.count, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF6FAFD), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA10)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: Colors.white,
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.primary)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(999)), child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class _QueueTabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _QueueTabBtn({required this.icon, required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.96) : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: active ? [BoxShadow(color: AppColors.primaryA08, blurRadius: 18, offset: const Offset(0, 4))] : []),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 13, color: active ? AppColors.primary : const Color(0xFF6B7D93)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? AppColors.primary : const Color(0xFF6B7D93))),
            ]),
            const SizedBox(height: 3),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: active ? AppColors.primaryA08 : AppColors.primaryA04, borderRadius: BorderRadius.circular(999)), child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppColors.primary : const Color(0xFF6B7D93)))),
          ]),
        ),
      ),
    );
  }
}

// ── Primary queue list ────────────────────────────────────────────────

class _PrimaryQueueList extends StatelessWidget {
  final List<QueuePatient> patients;
  final AllWaitThresholds thresholds;
  final void Function(QueuePatient) onStart;
  const _PrimaryQueueList({required this.patients, required this.thresholds, required this.onStart});

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) return const _QueueEmptyState(icon: Icons.check_circle_outline_rounded, title: 'No patients waiting for Primary Exam', subtitle: 'All primary exams completed for the selected date');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: patients.length,
      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _PrimaryPatientCard(patient: patients[i], thresholds: thresholds, onStart: () => onStart(patients[i]))),
    );
  }
}

class _PrimaryPatientCard extends StatelessWidget {
  final QueuePatient patient;
  final AllWaitThresholds thresholds;
  final VoidCallback onStart;
  const _PrimaryPatientCard({required this.patient, required this.thresholds, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PulseDot(color: AppColors.waitOrange),
          const SizedBox(width: 7),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('MRD: ${p.patientCode}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
            ]),
          ),
          const SizedBox(width: 8),
          _AgeGenderBadge(age: p.age, gender: p.gender, bgColor: const Color(0xFFD94841).withValues(alpha: 0.10), textColor: const Color(0xFFD94841)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (p.contactNo != null && p.contactNo!.isNotEmpty) ...[_InfoChip(icon: Icons.phone_outlined, text: p.contactNo!), const SizedBox(width: 14)],
          if (p.caseType != null) Expanded(child: _InfoChip(icon: Icons.label_outline_rounded, text: p.caseType!)),
        ]),
        const SizedBox(height: 5),
        _InfoChip(icon: Icons.schedule_rounded, text: 'Registered: ${_hhmm(p.createdAt)}'),
        const SizedBox(height: 10),
        Row(children: [WaitPill(waitFrom: p.createdAt, label: 'R', thresholds: thresholds.r), const Spacer(), _StartButton(label: 'Start Primary', onTap: onStart)]),
      ]),
    );
  }
}

// ── Dilation queue list ──────────────────────────────────────────────

class _DilationQueueList extends StatelessWidget {
  final List<QueuePatient> patients;
  final AllWaitThresholds thresholds;
  const _DilationQueueList({required this.patients, required this.thresholds});

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) return const _QueueEmptyState(icon: Icons.visibility_outlined, title: 'No patients currently dilating', subtitle: 'All dilation periods have completed or no dilation requested');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: patients.length,
      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _DilationPatientCard(patient: patients[i], thresholds: thresholds)),
    );
  }
}

class _DilationPatientCard extends StatelessWidget {
  final QueuePatient patient;
  final AllWaitThresholds thresholds;
  const _DilationPatientCard({required this.patient, required this.thresholds});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final exam = p.primaryExamination;
    final examAt = exam?.examinedAt;
    final dilTime = exam?.dilationTime ?? 0;
    final unlockMs = p.unlockTimeMs;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('MRD: ${p.patientCode}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
            ]),
          ),
          const SizedBox(width: 8),
          _AgeGenderBadge(age: p.age, gender: p.gender, bgColor: const Color(0xFFD97706).withValues(alpha: 0.10), textColor: const Color(0xFFD97706)),
        ]),
        const SizedBox(height: 10),
        _InfoChip(icon: Icons.check_circle_outline_rounded, text: 'Primary Done: ${_hhmm(examAt)}', color: const Color(0xFF1F9D55)),
        const SizedBox(height: 5),
        Row(children: [
          _InfoChip(icon: Icons.timer_outlined, text: 'Dilation: $dilTime min'),
          if (unlockMs != null) ...[const SizedBox(width: 14), _InfoChip(icon: Icons.notifications_outlined, text: 'Unlocks: ${_hhmm(DateTime.fromMillisecondsSinceEpoch(unlockMs))}')],
        ]),
        if (unlockMs != null) ...[const SizedBox(height: 10), _DilationCountdown(key: ValueKey('countdown_${p.id}_$unlockMs'), unlockTimeMs: unlockMs)],
        const SizedBox(height: 10),
        Row(children: [WaitPill(waitFrom: p.createdAt, label: 'R', thresholds: thresholds.r), if (examAt != null) ...[const SizedBox(width: 8), WaitPill(waitFrom: examAt, label: 'D', thresholds: thresholds.d)]]),
      ]),
    );
  }
}

class _DilationCountdown extends StatelessWidget {
  final int unlockTimeMs;
  const _DilationCountdown({super.key, required this.unlockTimeMs});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _queueTick,
      builder: (_, _, _) {
        final diff = unlockTimeMs - DateTime.now().millisecondsSinceEpoch;
        final done = diff <= 0;
        final col = done ? const Color(0xFF1F9D55) : const Color(0xFFD94841);
        final text = done ? '00:00' : '${(diff ~/ 60000).toString().padLeft(2, '0')}:${((diff % 60000) ~/ 1000).toString().padLeft(2, '0')}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: done ? const Color(0xFF1F9D55).withValues(alpha: 0.10) : const Color(0xFFD94841).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: col.withValues(alpha: 0.22))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.hourglass_bottom_rounded, size: 16, color: col),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w900, color: col, letterSpacing: 2)),
            if (done) ...[const SizedBox(width: 8), Text('Ready!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: col))],
          ]),
        );
      },
    );
  }
}

// ── Secondary queue list ─────────────────────────────────────────────

class _SecondaryQueueList extends StatelessWidget {
  final List<QueuePatient> patients;
  final AllWaitThresholds thresholds;
  final void Function(QueuePatient) onStart;
  const _SecondaryQueueList({required this.patients, required this.thresholds, required this.onStart});

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) return const _QueueEmptyState(icon: Icons.favorite_border_rounded, title: 'No patients waiting for Secondary Exam', subtitle: 'All secondary exams completed for the selected date');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: patients.length,
      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _SecondaryPatientCard(patient: patients[i], thresholds: thresholds, onStart: () => onStart(patients[i]))),
    );
  }
}

class _SecondaryPatientCard extends StatelessWidget {
  final QueuePatient patient;
  final AllWaitThresholds thresholds;
  final VoidCallback onStart;
  const _SecondaryPatientCard({required this.patient, required this.thresholds, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final exam = p.primaryExamination;
    final examAt = exam?.examinedAt;
    final isDilated = p.isDilated;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('MRD: ${p.patientCode}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
            ]),
          ),
          const SizedBox(width: 8),
          _AgeGenderBadge(age: p.age, gender: p.gender, bgColor: const Color(0xFF2563EB).withValues(alpha: 0.10), textColor: const Color(0xFF2563EB)),
        ]),
        const SizedBox(height: 10),
        if (p.contactNo != null && p.contactNo!.isNotEmpty) ...[_InfoChip(icon: Icons.phone_outlined, text: p.contactNo!), const SizedBox(height: 5)],
        _InfoChip(icon: Icons.check_circle_outline_rounded, text: 'Primary Done: ${_hhmm(examAt)}', color: const Color(0xFF1F9D55)),
        const SizedBox(height: 5),
        _InfoChip(icon: Icons.article_outlined, text: 'Findings: ${p.diagnosisText}'),
        const SizedBox(height: 10),
        Row(children: [
          WaitPill(waitFrom: p.createdAt, label: 'R', thresholds: thresholds.r),
          if (examAt != null) ...[const SizedBox(width: 8), WaitPill(waitFrom: examAt, label: isDilated ? 'D' : 'ND', thresholds: isDilated ? thresholds.d : thresholds.nd)],
          const Spacer(),
          _StartButton(label: 'Start Secondary', onTap: onStart),
        ]),
      ]),
    );
  }
}

// ── Wait pill (shared) ───────────────────────────────────────────────

class WaitPill extends StatefulWidget {
  final DateTime waitFrom;
  final String label;
  final WaitThresholds thresholds;
  const WaitPill({super.key, required this.waitFrom, required this.label, required this.thresholds});

  @override
  State<WaitPill> createState() => _WaitPillState();
}

class _WaitPillState extends State<WaitPill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.30, end: 0.70).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  int get _mins => DateTime.now().difference(widget.waitFrom).inMinutes;

  Color _color(int mins) {
    if (mins < widget.thresholds.greenMax) return AppColors.waitGreen;
    if (mins < widget.thresholds.orangeMax) return AppColors.waitOrange;
    return AppColors.waitRed;
  }

  @override
  Widget build(BuildContext context) {
    final mins = _mins;
    final col = _color(mins);
    final fire = mins >= widget.thresholds.redMax;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: col.withValues(alpha: fire ? _pulseAnim.value : 0.25)),
          boxShadow: fire ? [BoxShadow(color: AppColors.waitOrange.withValues(alpha: _pulseAnim.value * 0.50), blurRadius: 10, spreadRadius: 1)] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: col), alignment: Alignment.center, child: Text(widget.label, style: TextStyle(color: Colors.white, fontSize: widget.label == 'ND' ? 7.5 : 9, fontWeight: FontWeight.w900, letterSpacing: -0.3))),
          const SizedBox(width: 5),
          Text('${mins}m', style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────

class _QueueEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _QueueEmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 82, height: 82, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryA08), alignment: Alignment.center, child: Icon(icon, size: 40, color: AppColors.primary.withValues(alpha: 0.28))),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF18324A))),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: const Color(0xFF6B7D93).withValues(alpha: 0.80))),
        ]),
      ),
    );
  }
}

class _AgeGenderBadge extends StatelessWidget {
  final int age;
  final String gender;
  final Color bgColor;
  final Color textColor;
  const _AgeGenderBadge({required this.age, required this.gender, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Text('$age / ${_cap(gender)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6B7D93);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: c),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c), overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _StartButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _StartButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScaleWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, const Color(0xFF2C6E99)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }
}
