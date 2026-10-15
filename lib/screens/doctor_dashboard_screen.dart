import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../models/auth_models.dart';
import '../models/doctor_dashboard_models.dart';
import '../models/patient_models.dart';
import '../services/base_service.dart';
import '../services/doctor_dashboard_service.dart';
import '../utils/app_route.dart';
import '../utils/refreshable.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/exam/dilation_lock.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_row_action.dart';
import 'doctor_ot_list_screen.dart';
import 'latest_exam_view_screen.dart';
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
  bool _noPermissions = false;
  int? _viewingDoctorId;
  Timer? _tickTimer;

  // Web parity: doctoredashboard.blade.php's Primary/Secondary Patient
  // tables each have their own "Show entries"/search/pagination controls
  // (~lines 900-990) — web's own markup for these is static HTML with no
  // JS wired to it (the Previous/Next buttons are literally `disabled`),
  // so this makes them actually work client-side over the already-fetched
  // queue list instead of reproducing web's inert placeholders.
  String _primarySearch = '';
  String _secondarySearch = '';
  int _primaryPageSize = 10;
  int _secondaryPageSize = 10;
  int _primaryPage = 1;
  int _secondaryPage = 1;

  // OPD/OT dashboard tab (web pull 2026-10-13, doctoredashboard.blade.php's
  // `.dash-tab-bar`) — OPD selected by default, same page/data already
  // loaded, just switches which sections show.
  String _activeDashTab = 'opd';
  String _otPendingSearch = '';
  String _otCompletedSearch = '';
  int _otPendingPageSize = 10;
  int _otCompletedPageSize = 10;
  int _otPendingPage = 1;
  int _otCompletedPage = 1;

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
      _noPermissions = false;
    });
    try {
      final data = await DoctorDashboardService.instance.fetchDashboard(viewDoctorId: _viewingDoctorId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } on PermissionDeniedException {
      // A calm "no permissions" state, not a hard error — matches the
      // regular Dashboard's treatment of the same zero-permission
      // situation. See DOCTOR_DASHBOARD_FIX_PLAN.md Phase 3.
      if (mounted) {
        setState(() {
          _noPermissions = true;
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
    if (_noPermissions) {
      return _buildNoPermissionsState();
    }
    if (_error != null && _data == null) {
      return _buildError();
    }
    return AppRefreshIndicator(
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
    // Show the real backend reason (e.g. "Access denied." for a
    // permission-denied 403, now meaningful since
    // ROLES_PERMISSIONS_ROUND3_FIX_PLAN.md Phase 1) instead of a hardcoded
    // literal that made every failure — permission, network, server error —
    // look identical. See ROLES_PERMISSIONS_DEEP_AUDIT_ROUND3.md.
    final message = (_error != null && _error!.trim().isNotEmpty)
        ? _error!
        : 'Failed to load dashboard';
    return AppErrorState(message: message, onRetry: _load);
  }

  Widget _buildNoPermissionsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.40)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No Permissions Configured',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                      SizedBox(height: 3),
                      Text('Your role has no feature permissions assigned. Please contact your administrator.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppEmptyState(message: 'No dashboard data to show'),
        ]),
      ),
    );
  }

  Widget _buildDashTabBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dashTabBtn('OPD', 'opd'),
          const SizedBox(width: 6),
          _dashTabBtn('OT', 'ot'),
        ]),
      ),
    );
  }

  Widget _dashTabBtn(String label, String tab) {
    final active = _activeDashTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeDashTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
        decoration: BoxDecoration(color: active ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: active ? Colors.white : const Color(0xFF5B7385))),
      ),
    );
  }

  Widget _buildBody() {
    final data = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDoctorOverviewPanel(data),
        if (_viewingDoctorId != null && data.viewingDoctor != null) ...[
          const SizedBox(height: 12),
          _buildViewingBanner(data.viewingDoctor!),
        ],
        const SizedBox(height: 18),
        _buildDashTabBar(),
        const SizedBox(height: 18),
        if (_activeDashTab == 'opd')
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
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final pending = _buildOtQueueTable(isPending: true, items: data.otPendingQueue);
              final completed = _buildOtQueueTable(isPending: false, items: data.otCompletedQueue);
              if (constraints.maxWidth < AppBreakpoints.medium) {
                return Column(children: [pending, const SizedBox(height: 16), completed]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: pending),
                  const SizedBox(width: 20),
                  Expanded(child: completed),
                ],
              );
            },
          ),
      ],
    );
  }

  // ── Doctor Overview ─────────────────────────────────────────────────────
  //
  // Web parity: `doctoredashboard.blade.php`'s single `.doc-overview-panel` —
  // a featured card for whichever doctor's dashboard is open (self, or a
  // doctor switched to via `?view_doctor=`), stacking hospital-wide /
  // this-doctor's-OPD / this-doctor's-OT counts as three bars, plus an
  // "All Doctor List" of every OTHER doctor with OPD+OT stats merged into
  // ONE card each. Replaces the app's previous 4 separate sections (a
  // standalone stat-card row, a hospital-today bar, an OT-only doctor strip
  // and an OPD-only doctor strip) that don't exist as separate pieces on
  // web — web has no "Reports" link and no standalone stat cards here at all.

  // Two zones, same outer height. The open doctor stays in its own box on
  // the left. Every other doctor sits at the top of a separate panel on the
  // right — not vertically centered against the taller card.
  Widget _buildDoctorOverviewPanel(DoctorDashboardData data) {
    final viewingName = data.viewingDoctor?.name ?? widget.user.name;
    final otById = {for (final o in data.otDoctorCards) o.id: o};
    final others = data.doctorCards.where((d) => !d.isSelf).toList();

    return LayoutBuilder(builder: (context, constraints) {
      const leftW = 276.0;
      const gap = 12.0;
      final rightW = (constraints.maxWidth - leftW - gap).clamp(0.0, constraints.maxWidth);
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: leftW, child: _overviewZone(
            child: Align(alignment: Alignment.topCenter, child: _buildFeaturedDoctorCard(data, viewingName)),
          )),
          const SizedBox(width: gap),
          SizedBox(width: rightW, child: _overviewZone(
            fill: const Color(0xFFF4F7FB),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('All Doctor List', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ]),
                InkWell(
                  onTap: _load,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              others.isEmpty
                  ? Text('No other doctors on duty right now.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (var i = 0; i < others.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          _buildCombinedDoctorCard(others[i], otById[others[i].id]),
                        ],
                      ]),
                    ),
            ]),
          )),
        ]),
      );
    });
  }

  Widget _overviewZone({required Widget child, Color fill = Colors.white}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }

  Widget _buildFeaturedDoctorCard(DoctorDashboardData data, String name) {
    return _SelectedPulse(
      active: true,
      radius: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Web pull 2026-10-13 (same OPD/OT tab-switch pull): the OPD-tab
          // top bar dropped its 4th "OT" segment (old $otPipelineCount) —
          // now just C/PC/SC. Web's controller still computes the value
          // (kept for later reuse, unused anywhere in the blade now), so
          // the API keeps sending tenantTodayOtPipeline too; only the
          // display here stops showing it, matching web exactly.
          if (_activeDashTab == 'opd')
            _overviewBar(const Color(0xFF0F4F86), [
              ('C', '${data.tenantTodayPatients}'),
              ('PC', '${data.tenantTodayPrimary}'),
              ('SC', '${data.tenantTodaySecondary}'),
            ])
          else
            _overviewBar(const Color(0xFF0F4F86), [
              ('OT', '${data.todayOtWalkins}'),
              ('PD', '${data.todayPaymentPending}'),
              ('OC', '${data.todayDischargeCounter}'),
            ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              child: const Icon(Icons.badge_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (_viewingDoctorId != null)
              TextButton(
                onPressed: () => _selectDoctor(null),
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('← Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
          ]),
          const SizedBox(height: 6),
          // Web parity: `.doc-ref-btns opd-only` vs `.doc-ref-btns--ot
          // ot-only` — only one of these two bars shows at a time, matching
          // the active tab, not both stacked. "Pending" is plain text now
          // (web removed its onclick link in the same pull) — the new OT
          // Pending/Completed tables below are the entry point now.
          if (_activeDashTab == 'opd')
            _overviewBar(const Color(0xFF0A2F52), [
              ('Patient', '${data.stats.assignedToday}'),
              ('P', '${data.stats.primaryDone}'),
              ('S', '${data.stats.secondaryDone}'),
            ])
          else
            _overviewBar(
              const Color(0xFF0D9488),
              [('OT', '${data.otSummary.total}'), ('OP', '${data.otSummary.pending}'), ('OC', '${data.otSummary.complete}')],
            ),
        ]),
      ),
    );
  }

  Widget _overviewBar(Color bg, List<(String, String)> segments, {VoidCallback? onMidTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: bg,
        child: Row(children: [
          for (int i = 0; i < segments.length; i++) ...[
            if (i > 0) Container(width: 1, height: 16, color: Colors.white24),
            Expanded(child: _overviewSeg(segments[i].$1, segments[i].$2, onTap: i == 1 ? onMidTap : null)),
          ],
        ]),
      ),
    );
  }

  Widget _overviewSeg(String label, String value, {VoidCallback? onTap}) {
    final tappable = onTap != null;
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, decoration: tappable ? TextDecoration.underline : null, decorationColor: Colors.white)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1)),
        if (tappable) ...[
          const SizedBox(width: 2),
          const Icon(Icons.north_east_rounded, size: 12, color: Colors.white),
        ],
      ]),
    );
    if (!tappable) return body;
    return Material(
      color: Colors.white.withValues(alpha: 0.20),
      child: InkWell(onTap: onTap, child: body),
    );
  }

  Widget _buildCombinedDoctorCard(DoctorCardInfo doc, OtDoctorCardInfo? ot) {
    final isSelected = _viewingDoctorId == doc.id;
    return _SelectedPulse(
      active: isSelected,
      radius: 10,
      child: PressScaleWrapper(
        onTap: () => _selectDoctor(doc.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 228,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F4FC) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.16), width: isSelected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.badge_rounded, size: 16, color: AppColors.teal),
              const SizedBox(width: 6),
              Expanded(child: Text(doc.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            // Web parity: opd-only vs ot-only — one row per active tab, not
            // both stacked. "Pending" (OP) is plain text now, not a link —
            // web removed its onclick in the same pull; see the featured
            // card's OT bar above for where the entry point moved to.
            if (_activeDashTab == 'opd')
              Row(children: [
                _refBtn('Pt', '${doc.assignedToday}', const Color(0xFF0A2F52)),
                const SizedBox(width: 4),
                _refBtn('P', '${doc.primaryCount}', const Color(0xFF0A2F52)),
                const SizedBox(width: 4),
                _refBtn('S', '${doc.secondaryCount}', const Color(0xFF0A2F52)),
              ])
            else
              Row(children: [
                _refBtn('OT', '${ot?.otTotal ?? 0}', const Color(0xFF0D9488)),
                const SizedBox(width: 4),
                _refBtn('OP', '${ot?.otPending ?? 0}', const Color(0xFF0D9488)),
                const SizedBox(width: 4),
                _refBtn('OC', '${ot?.otComplete ?? 0}', const Color(0xFF0D9488)),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _refBtn(String label, String value, Color color, {VoidCallback? onTap}) {
    final tappable = onTap != null;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            decoration: BoxDecoration(
              color: tappable ? Colors.white : color,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color, width: tappable ? 1.4 : 0),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tappable ? color : Colors.white.withValues(alpha: 0.92), decoration: tappable ? TextDecoration.underline : null, decorationColor: color)),
              const SizedBox(width: 3),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tappable ? color : Colors.white, height: 1)),
              if (tappable) ...[const SizedBox(width: 1), Icon(Icons.north_east_rounded, size: 11, color: color)],
            ]),
          ),
        ),
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
  //
  // Patient cell is the name at 15, with age · gender · city on the line
  // under it. Waiting and Action stay their own columns. The row fills the
  // card, so the queue does not scroll sideways.

  Widget _tableRow(List<Widget> cells) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 32, child: cells[0]),
      const SizedBox(width: 8),
      Expanded(child: cells[1]),
      const SizedBox(width: 8),
      SizedBox(width: 108, child: cells[2]),
      const SizedBox(width: 8),
      SizedBox(width: 156, child: Align(alignment: Alignment.centerRight, child: cells[3])),
    ]);
  }

  Widget _tableHeaderRow() {
    // maxLines/overflow/softWrap are load-bearing — without them, a header
    // word that doesn't fit its column wraps character-by-character
    // instead of truncating (found the hard way on mobile's narrower
    // screen; applying the same safety here defensively).
    Widget h(String label, {bool left = false}) => Text(
          label,
          textAlign: left ? TextAlign.left : TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        );
    return Container(
      color: const Color(0xFFF4F8FB),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: _tableRow([h('#'), h('Patient', left: true), h('Waiting'), h('Action')]),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String _patientMeta(int? age, String? gender, String city) {
    final parts = <String>[
      if (age != null) '$age',
      if (gender != null && gender.isNotEmpty) _capitalize(gender),
      if (city.isNotEmpty) city,
    ];
    return parts.join(' · ');
  }

  Widget _dataRow({
    required String drIndex,
    required String name,
    required int? age,
    required String? gender,
    required String city,
    required List<Widget> waitPills,
    required Widget actionWidget,
    Widget? viewButton,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFFCDE5F5).withValues(alpha: 0.5)))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _tableRow([
        Text(drIndex, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_patientMeta(age, gender, city).isNotEmpty)
            Text(_patientMeta(age, gender, city), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ]),
        Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 2, children: waitPills),
        Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 4, children: [
          actionWidget,
          ?viewButton,
        ]),
      ]),
    );
  }

  Widget _buildQueueTable({required bool isPrimary, required List<PrimaryPatient> patients, required List<SecondaryPatient> secondary}) {
    final title = isPrimary ? 'Primary Patient' : 'Secondary Patient';
    final search = (isPrimary ? _primarySearch : _secondarySearch).trim().toLowerCase();
    final pageSize = isPrimary ? _primaryPageSize : _secondaryPageSize;
    final page = isPrimary ? _primaryPage : _secondaryPage;

    final filteredPrimary = isPrimary ? patients.where((p) => search.isEmpty || p.patientName.toLowerCase().contains(search)).toList() : const <PrimaryPatient>[];
    final filteredSecondary = !isPrimary ? secondary.where((p) => search.isEmpty || p.patientName.toLowerCase().contains(search)).toList() : const <SecondaryPatient>[];
    final totalCount = isPrimary ? filteredPrimary.length : filteredSecondary.length;
    final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    final clampedPage = page.clamp(1, totalPages);
    final start = ((clampedPage - 1) * pageSize).clamp(0, totalCount);
    final end = (start + pageSize).clamp(0, totalCount);
    final pagePrimary = isPrimary ? filteredPrimary.sublist(start, end) : const <PrimaryPatient>[];
    final pageSecondary = !isPrimary ? filteredSecondary.sublist(start, end) : const <SecondaryPatient>[];

    void setPage(int p) => setState(() {
          if (isPrimary) {
            _primaryPage = p;
          } else {
            _secondaryPage = p;
          }
        });

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
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text('${isPrimary ? patients.length : secondary.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(children: [
            Text('Show entries', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700),
              items: const [10, 20, 30].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (isPrimary) {
                    _primaryPageSize = v;
                    _primaryPage = 1;
                  } else {
                    _secondaryPageSize = v;
                    _secondaryPage = 1;
                  }
                });
              },
            ),
            const Spacer(),
            Text('Search', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            SizedBox(
              width: 160,
              height: 36,
              child: TextField(
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
                onChanged: (v) => setState(() {
                  if (isPrimary) {
                    _primarySearch = v;
                    _primaryPage = 1;
                  } else {
                    _secondarySearch = v;
                    _secondaryPage = 1;
                  }
                }),
              ),
            ),
          ]),
        ),
        Column(children: [
          _tableHeaderRow(),
          if (totalCount == 0)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No Data Found', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))))
          else if (isPrimary)
            ...pagePrimary.map(_buildPrimaryRow)
          else
            ...pageSecondary.map(_buildSecondaryRow),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Text(
              totalCount == 0 ? 'Showing 0 of 0 entries' : 'Showing ${start + 1} to $end of $totalCount entries',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: clampedPage > 1 ? () => setPage(clampedPage - 1) : null,
              style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Previous', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: clampedPage < totalPages ? () => setPage(clampedPage + 1) : null,
              style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPrimaryRow(PrimaryPatient p) {
    final perm = PermissionService.instance;
    final canExam = perm.can(Perm.opdExamPrimary);
    final canHistory = perm.can(Perm.opdExamHistory);
    return _dataRow(
      drIndex: p.drIndexNo,
      name: p.patientName,
      age: p.age,
      gender: p.gender,
      city: p.city,
      waitPills: [_waitPill('R', p.registeredAt, _rTh)],
      actionWidget: canExam
          ? _examBtn('Examine', () => _openPrimaryExam(p))
          : const SizedBox.shrink(),
      viewButton: p.hasHistory && canHistory ? _viewBtn(() => _openLatestExam(p)) : null,
    );
  }

  Widget _buildSecondaryRow(SecondaryPatient p) {
    final perm = PermissionService.instance;
    final canExam = perm.can(Perm.opdExamSecondary);
    final pills = <Widget>[_waitPill('R', p.registeredAt, _rTh)];
    if (p.primaryDoneAt != null) {
      pills.add(_waitPill(p.isDilated ? 'D' : 'ND', p.primaryDoneAt!, p.isDilated ? _dTh : _ndTh));
    }
    return _dataRow(
      drIndex: p.drIndexNo,
      name: p.patientName,
      age: p.age,
      gender: p.gender,
      city: p.city,
      waitPills: pills,
      actionWidget: canExam
          ? _secondaryActionBtn(p)
          : const SizedBox.shrink(),
      viewButton: p.primaryDoneAt != null && canExam && perm.can(Perm.opdExamHistory)
          ? _eyeBtn(() => _openLatestExam(p))
          : null,
    );
  }

  // Web parity: while dilation is locked, show a countdown chip — a single
  // tap does nothing, only a double-tap opens the override confirmation.
  // Once unlocked (or never dilated), it's a plain "Examine" button that
  // navigates straight through with no dialog.
  Widget _secondaryActionBtn(SecondaryPatient p) {
    final unlockTimeMs = (p.isDilated && p.primaryDoneAt != null)
        ? p.primaryDoneAt!.millisecondsSinceEpoch + p.dilationLockMinutes * 60000
        : null;
    if (unlockTimeMs != null) {
      final remaining = unlockTimeMs - DateTime.now().millisecondsSinceEpoch;
      if (remaining > 0) {
        final mm = (remaining ~/ 60000).toString().padLeft(2, '0');
        final ss = ((remaining % 60000) ~/ 1000).toString().padLeft(2, '0');
        return GestureDetector(
          onDoubleTap: () => _handleSecondaryOverride(p, unlockTimeMs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_bottom_rounded, size: 14, color: Color(0xFFE65100)),
              const SizedBox(width: 4),
              Text('$mm:$ss', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
            ]),
          ),
        );
      }
    }
    return _examBtn('Examine', () => _openSecondaryExam(p));
  }

  Future<void> _handleSecondaryOverride(SecondaryPatient p, int unlockTimeMs) async {
    final ok = await canStartSecondaryExam(context, unlockTimeMs);
    if (ok) _openSecondaryExam(p);
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

  // Only called once the caller already knows it's safe: either the patient
  // was never locked, or _handleSecondaryOverride's double-tap confirmation
  // already ran. No dialog here — matches web's plain (non-locked)
  // "Examine" link.
  Future<void> _openSecondaryExam(SecondaryPatient p) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(appRoute(SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: _toPatient(p))));
    if (result == true && mounted) _load();
  }

  void _openLatestExam(PrimaryPatient p) {
    showLatestExamView(context, _toPatient(p));
  }

  // [green_max_min, orange_max_min, red_max_min] — anything past the 3rd
  // value is "fire". Hospital-configurable via wait_thresholds on the API
  // response, not hardcoded — see DOCTOR_DASHBOARD_FIX_PLAN.md Phase 4.
  WaitThresholds get _wt => _data?.waitThresholds ?? WaitThresholds.defaults;
  List<int> get _rTh  => [_wt.rGreen, _wt.rOrange, _wt.rRed];
  List<int> get _dTh  => [_wt.dGreen, _wt.dOrange, _wt.dRed];
  List<int> get _ndTh => [_wt.ndGreen, _wt.ndOrange, _wt.ndRed];

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
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        Text(waitText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── OT Queue Table (OT tab) ───────────────────────────────────────────
  //
  // Web parity: doctoredashboard.blade.php's new "OT Pending Patients" /
  // "OT Completed Patients" cards (`.row.g-4.ot-only`) — # / Patient /
  // Status / Action, same client-side search+pagination convention as the
  // OPD tables above. Review/View simply opens the existing
  // DoctorOtListScreen via openDoctorOpList(), matching web's Review/View
  // links which just navigate to the `doctor-ot` page.

  Widget _otTableHeaderRow() {
    Widget h(String label, {bool left = false}) => Text(
          label,
          textAlign: left ? TextAlign.left : TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        );
    return Container(
      color: const Color(0xFFF4F8FB),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: _tableRow([h('#'), h('Patient', left: true), h('Status'), h('Action')]),
    );
  }

  Color _hexToColor(String hex) => Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  void _openOtList(int doctorId, String doctorName) =>
      openDoctorOpList(context, doctorId: doctorId, doctorName: doctorName);

  Widget _otDataRow(int index, OtQueueItem item, int doctorId, String doctorName) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFFCDE5F5).withValues(alpha: 0.5)))),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _tableRow([
        Text('${index + 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(item.patientName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_patientMeta(item.age, item.gender, item.city ?? '').isNotEmpty)
            Text(_patientMeta(item.age, item.gender, item.city ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ]),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _hexToColor(item.statusTone), borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Text(item.statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
        item.isConsultPending
            ? _examBtn('Review', () => _openOtList(doctorId, doctorName))
            : _viewBtn(() => _openOtList(doctorId, doctorName)),
      ]),
    );
  }

  Widget _buildOtQueueTable({required bool isPending, required List<OtQueueItem> items}) {
    final title = isPending ? 'OT Pending Patients' : 'OT Completed Patients';
    final search = (isPending ? _otPendingSearch : _otCompletedSearch).trim().toLowerCase();
    final pageSize = isPending ? _otPendingPageSize : _otCompletedPageSize;
    final page = isPending ? _otPendingPage : _otCompletedPage;
    final doctorId = _viewingDoctorId ?? widget.user.id;
    final doctorName = _data?.viewingDoctor?.name ?? widget.user.name;

    final filtered = items.where((i) => search.isEmpty || i.patientName.toLowerCase().contains(search)).toList();
    final totalCount = filtered.length;
    final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    final clampedPage = page.clamp(1, totalPages);
    final start = ((clampedPage - 1) * pageSize).clamp(0, totalCount);
    final end = (start + pageSize).clamp(0, totalCount);
    final pageItems = filtered.sublist(start, end);

    void setPage(int p) => setState(() {
          if (isPending) {
            _otPendingPage = p;
          } else {
            _otCompletedPage = p;
          }
        });

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
          color: isPending ? AppColors.primary : const Color(0xFF0D9488),
          child: Row(children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(children: [
            Text('Show entries', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700),
              items: const [10, 20, 30].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (isPending) {
                    _otPendingPageSize = v;
                    _otPendingPage = 1;
                  } else {
                    _otCompletedPageSize = v;
                    _otCompletedPage = 1;
                  }
                });
              },
            ),
            const Spacer(),
            Text('Search', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            SizedBox(
              width: 160,
              height: 36,
              child: TextField(
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
                onChanged: (v) => setState(() {
                  if (isPending) {
                    _otPendingSearch = v;
                    _otPendingPage = 1;
                  } else {
                    _otCompletedSearch = v;
                    _otCompletedPage = 1;
                  }
                }),
              ),
            ),
          ]),
        ),
        Column(children: [
          _otTableHeaderRow(),
          if (totalCount == 0)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No Data Found', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))))
          else
            ...pageItems.asMap().entries.map((e) => _otDataRow(start + e.key, e.value, doctorId, doctorName)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Text(
              totalCount == 0 ? 'Showing 0 of 0 entries' : 'Showing ${start + 1} to $end of $totalCount entries',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: clampedPage > 1 ? () => setPage(clampedPage - 1) : null,
              style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Previous', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: clampedPage < totalPages ? () => setPage(clampedPage + 1) : null,
              style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _examBtn(String label, VoidCallback onTap) {
    return TableLabelAction(label: label, onTap: onTap, tone: TableLabelTone.primary);
  }

  Widget _viewBtn(VoidCallback onTap) {
    return TableLabelAction(label: 'View', onTap: onTap, tone: TableLabelTone.teal);
  }

  Widget _eyeBtn(VoidCallback onTap) {
    return TableIconAction(icon: Icons.visibility_rounded, tooltip: 'View', onTap: onTap);
  }
}

class _SelectedPulse extends StatefulWidget {
  final bool active;
  final double radius;
  final Widget child;

  const _SelectedPulse({required this.active, required this.radius, required this.child});

  @override
  State<_SelectedPulse> createState() => _SelectedPulseState();
}

class _SelectedPulseState extends State<_SelectedPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_SelectedPulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F4F86).withValues(alpha: 0.10 + 0.22 * t),
                blurRadius: 3 + 7 * t,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
