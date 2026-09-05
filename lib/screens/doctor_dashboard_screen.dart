import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/doctor_dashboard_models.dart';
import '../models/patient_models.dart';
import '../services/doctor_dashboard_service.dart';
import '../utils/app_route.dart';
import '../utils/refreshable.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/exam/dilation_lock.dart';
import '../widgets/skeleton.dart';
import 'doctor_ot_list_screen.dart';
import 'patient_history_route.dart';
import 'primary_exam_screen.dart';
import 'secondary_exam_screen.dart';

/// Tablet doctor dashboard — Pattern B, with primary/secondary queues shown
/// side-by-side (Pattern G widened) instead of mobile's stacked tables, so a
/// doctor sees both queues without scrolling. Business logic ported
/// unchanged from eye_care_app/lib/screens/doctor_dashboard_screen.dart.
class DoctorDashboardScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final void Function(String railId) onNavigate;

  const DoctorDashboardScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.onNavigate,
  });

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> implements Refreshable {
  DoctorDashboardData? _data;
  bool _loading = true;
  String? _error;
  int? _viewingDoctorId;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DoctorDashboardService.instance.fetchDashboard(viewDoctorId: _viewingDoctorId);
      if (mounted) {
        setState(() {
          _data = data;
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

  void _selectDoctor(int? doctorId) {
    setState(() => _viewingDoctorId = doctorId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const AppSkeletonList(count: 5, itemHeight: 90);
    }
    if (_error != null && _data == null) {
      return _buildError();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    return AppErrorState(message: 'Failed to load dashboard', onRetry: _load);
  }

  Widget _buildBody() {
    final data = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildStatCards(data.stats),
        const SizedBox(height: 10),
        _buildHospitalTodayBar(data),
        if (data.doctorCards.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildDoctorStrip(data.doctorCards),
        ],
        const SizedBox(height: 16),
        _buildOtDoctorStrip(data.otDoctorCards, data.otSummary),
        if (_viewingDoctorId != null && data.viewingDoctor != null) ...[
          const SizedBox(height: 12),
          _buildViewingBanner(data.viewingDoctor!),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final primary = _buildQueueTable(isPrimary: true, patients: data.primaryQueue, secondary: const []);
            final secondary = _buildQueueTable(isPrimary: false, patients: const [], secondary: data.secondaryQueue);
            if (constraints.maxWidth < AppBreakpoints.medium) {
              return Column(children: [primary, const SizedBox(height: 16), secondary]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: primary),
                const SizedBox(width: 20),
                Expanded(child: secondary),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final subtitle = (_viewingDoctorId != null && _data?.viewingDoctor != null) ? 'Viewing: ${_data!.viewingDoctor!.name}' : widget.user.name;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 22)),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ── Stat cards ──────────────────────────────────────────────────────────

  Widget _buildStatCards(DoctorDashStats stats) {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      _statCard('Assigned Today', stats.assignedToday, Icons.people_alt_rounded, AppColors.primary),
      _statCard('Primary Done', stats.primaryDone, Icons.check_circle_outline_rounded, AppColors.blueLight),
      _statCard('Secondary Done', stats.secondaryDone, Icons.check_circle_rounded, AppColors.waitGreen),
      _reportsCard(),
    ]);
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return _cardBox(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, height: 1.1)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, height: 1.3)),
      ]),
    );
  }

  /// Hospital-wide today/primary/secondary counts, shown alongside the
  /// doctor's own stats — mirrors web's `doctoredashboard.blade.php:756-760`
  /// "C: / PC: / SC:" bar (tenant-wide, not filtered to this doctor).
  Widget _buildHospitalTodayBar(DoctorDashboardData data) {
    Widget stat(String label, int value) => Text(
          '$label: $value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        stat('C', data.tenantTodayPatients),
        stat('PC', data.tenantTodayPrimary),
        stat('SC', data.tenantTodaySecondary),
      ]),
    );
  }

  Widget _reportsCard() {
    return PressScaleWrapper(
      onTap: () => widget.onNavigate('reports'),
      child: _cardBox(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, color: AppColors.primary.withValues(alpha: 0.65), size: 22),
          const SizedBox(height: 6),
          Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.50)),
          const SizedBox(height: 4),
          const Text('Reports', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _cardBox({required Widget child}) {
    return Container(
      width: 158,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE5F5)),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  // ── Doctor strip ────────────────────────────────────────────────────────

  Widget _buildDoctorStrip(List<DoctorCardInfo> cards) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: const Color(0xFFCDE5F5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DOCTORS TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.primary)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: cards.map(_buildDoctorCard).toList()),
      ]),
    );
  }

  Widget _buildDoctorCard(DoctorCardInfo doc) {
    final isSelected = _viewingDoctorId == null ? doc.isSelf : _viewingDoctorId == doc.id;
    return PressScaleWrapper(
      onTap: () => _selectDoctor(doc.isSelf && _viewingDoctorId == null ? null : doc.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        width: 156,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDDEEF9) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFCDE5F5), width: isSelected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: isSelected ? AppColors.primary : const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(doc.name.isNotEmpty ? doc.name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isSelected ? Colors.white : AppColors.textSecondary)),
            ),
            if (doc.isSelf) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5)),
                child: const Text('You', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(doc.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${doc.assignedToday} patients', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 7),
          Row(children: [
            _miniPill('P:${doc.primaryCount}', doc.primaryCount > 0 ? AppColors.primary : const Color(0xFFCBD5E1)),
            const SizedBox(width: 4),
            _miniPill('S:${doc.secondaryCount}', doc.secondaryCount > 0 ? AppColors.waitGreen : const Color(0xFFCBD5E1)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
      );

  // ── OT doctor strip ───────────────────────────────────────────────────────
  // Same roster/layout convention as `_buildDoctorStrip` (OPD), counts from
  // that doctor's OT bookings. Supersedes the old "My OT Patients" stat card
  // now that real per-doctor counts are available (web pull 2026-08-07 —
  // see WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §6 / FIX_PLAN TASK 5.2).

  Widget _buildOtDoctorStrip(List<OtDoctorCardInfo> cards, OtSummary summary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(color: const Color(0xFFF8F0FC), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: const Color(0xFFE9D5FF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_hospital_rounded, color: AppColors.purple, size: 16),
          const SizedBox(width: 6),
          Text('OT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.purple)),
          const Spacer(),
          InkWell(
            onTap: () => widget.onNavigate('doctor_ot_list'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.purple.withValues(alpha: 0.3))),
              child: Text('OT ${summary.total} · Pending ${summary.pending} · Complete ${summary.complete}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.purple)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (cards.isEmpty)
          Text('No doctors found for OT counts.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
        else
          Wrap(spacing: 10, runSpacing: 10, children: cards.map(_buildOtDoctorCard).toList()),
      ]),
    );
  }

  Widget _buildOtDoctorCard(OtDoctorCardInfo doc) {
    return PressScaleWrapper(
      onTap: () => doc.isSelf
          ? widget.onNavigate('doctor_ot_list')
          : Navigator.of(context, rootNavigator: true).push(appRoute(DoctorOtListScreen(doctorId: doc.id))),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 156,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE9D5FF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFEFE6F8), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(doc.name.isNotEmpty ? doc.name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.purple)),
            ),
            if (doc.isSelf) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(5)),
                child: const Text('You', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Text(doc.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.purple), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${doc.otTotal} OT cases', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 7),
          Row(children: [
            _miniPill('P:${doc.otPending}', doc.otPending > 0 ? AppColors.orange : const Color(0xFFCBD5E1)),
            const SizedBox(width: 4),
            _miniPill('C:${doc.otComplete}', doc.otComplete > 0 ? AppColors.waitGreen : const Color(0xFFCBD5E1)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildViewingBanner(DoctorCardInfo doctor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: const Color(0xFFFFC107))),
      child: Row(children: [
        const Icon(Icons.visibility_rounded, size: 15, color: Color(0xFFB45309)),
        const SizedBox(width: 8),
        Expanded(child: Text("Viewing Dr. ${doctor.name}'s patients", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
        TextButton(
          onPressed: () => _selectDoctor(null),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Back to Mine', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  // ── Queue tables ────────────────────────────────────────────────────────

  Widget _buildQueueTable({required bool isPrimary, required List<PrimaryPatient> patients, required List<SecondaryPatient> secondary}) {
    final title = isPrimary ? 'Primary Patient' : 'Secondary Patient';
    final count = isPrimary ? patients.length : secondary.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFCDE5F5)),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          color: AppColors.primary,
          child: Row(children: [
            Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        if (count == 0)
          const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: AppEmptyState(message: 'No patients'))
        else if (isPrimary)
          ...patients.map(_buildPrimaryRow)
        else
          ...secondary.map(_buildSecondaryRow),
      ]),
    );
  }

  Widget _buildPrimaryRow(PrimaryPatient p) {
    return _queueRowShell(
      drIndex: p.drIndexNo,
      name: p.patientName,
      age: p.age,
      city: p.city,
      waitPills: [_waitPill('R', p.registeredAt, _rTh)],
      actionWidget: _examBtn('Examine', () => _openPrimaryExam(p)),
      hasHistory: p.hasHistory,
      onHistory: () => _openHistory(p),
    );
  }

  Widget _buildSecondaryRow(SecondaryPatient p) {
    final pills = <Widget>[_waitPill('R', p.registeredAt, _rTh)];
    if (p.primaryDoneAt != null) {
      pills.add(const SizedBox(width: 4));
      pills.add(_waitPill(p.isDilated ? 'D' : 'ND', p.primaryDoneAt!, p.isDilated ? _dTh : _ndTh));
    }
    return _queueRowShell(
      drIndex: p.drIndexNo,
      name: p.patientName,
      age: p.age,
      city: p.city,
      waitPills: pills,
      actionWidget: _examBtn('Examine', () => _openSecondaryExam(p)),
      hasHistory: p.hasHistory,
      onHistory: () => _openHistory(p),
    );
  }

  // ── Navigation — queue rows carry lightweight DTOs, not a full Patient;
  // exam screens only ever read id/patientCode/fullName/doctor?.id off the
  // patient they're given, so a minimal Patient here is safe. ────────────

  Patient _toPatient(PrimaryPatient p) => Patient(
        id: p.id,
        patientCode: p.patientCode,
        firstName: p.patientName,
        lastName: '',
        fullName: p.patientName,
        age: p.age,
        doctor: p.doctorId != null ? PatientDoctor(id: p.doctorId!, name: '') : null,
      );

  Future<void> _openPrimaryExam(PrimaryPatient p) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(appRoute(PrimaryExamScreen(user: widget.user, hospital: widget.hospital, patient: _toPatient(p))));
    if (result == true && mounted) _load();
  }

  Future<void> _openSecondaryExam(SecondaryPatient p) async {
    final unlockTimeMs = (p.isDilated && p.primaryDoneAt != null) ? p.primaryDoneAt!.millisecondsSinceEpoch + p.dilationLockMinutes * 60000 : null;
    final ok = await canStartSecondaryExam(context, unlockTimeMs);
    if (!ok || !mounted) return;
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(appRoute(SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: _toPatient(p))));
    if (result == true && mounted) _load();
  }

  void _openHistory(PrimaryPatient p) {
    Navigator.of(context, rootNavigator: true).push(appRoute(PatientHistoryRoute(user: widget.user, hospital: widget.hospital, patient: _toPatient(p))));
  }

  Widget _queueRowShell({
    required String drIndex,
    required String name,
    required int? age,
    required String city,
    required List<Widget> waitPills,
    required Widget actionWidget,
    required bool hasHistory,
    required VoidCallback onHistory,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFFCDE5F5).withValues(alpha: 0.5)))),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, child: Text(drIndex, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${age != null ? '${age}y' : '-'} • ${city.isNotEmpty ? city : '-'}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: waitPills),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          actionWidget,
          if (hasHistory) ...[const SizedBox(height: 6), _histBtn(onHistory)],
        ]),
      ]),
    );
  }

  static const _rTh = [30, 60, 120];
  static const _dTh = [40, 90, 9999];
  static const _ndTh = [20, 60, 9999];

  Widget _waitPill(String label, DateTime since, List<int> th) {
    final mins = DateTime.now().difference(since).inMinutes.clamp(0, 99999);
    final isFire = mins > th[2];
    final isRed = mins > th[1];
    final isOrange = mins > th[0];

    Color bg;
    if (isFire) {
      bg = DateTime.now().second % 2 == 0 ? AppColors.waitRed : AppColors.waitRed.withValues(alpha: 0.55);
    } else if (isRed) {
      bg = AppColors.waitRed;
    } else if (isOrange) {
      bg = AppColors.waitOrange;
    } else {
      bg = AppColors.waitGreen;
    }

    final waitText = mins < 60 ? '${mins}m' : '${mins ~/ 60}h${mins % 60 > 0 ? '${mins % 60}m' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
        const SizedBox(width: 3),
        Text(waitText, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _examBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _histBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: const Color(0xFF0D9488), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: const Text('History', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
