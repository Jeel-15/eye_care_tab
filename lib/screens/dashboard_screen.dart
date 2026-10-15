import '../utils/date_format.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/dashboard_models.dart';
import '../models/patient_models.dart';
import '../services/dashboard_layout_prefs.dart';
import '../services/dashboard_service.dart';
import '../services/permission_service.dart';
import '../utils/currency_format.dart';
import '../utils/app_route.dart';
import '../utils/refreshable.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_section_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/table_row_action.dart';
import '../widgets/permission_guard.dart';
import '../widgets/resizable_dashboard_block.dart';
import '../widgets/skeleton.dart';
import '../widgets/standalone_screen.dart';
import 'opd_bill_screen.dart';
import 'patient_checkin_screen.dart';
import 'patient_form_screen.dart';
import 'phone_history_screen.dart';
import 'admin_collection_screen.dart';
import 'users_screen.dart';
import 'ot_lens_report_screen.dart';
import 'share_history_screen.dart';
import 'ot_accountant_dashboard_screen.dart';
import 'ot_assistant_dashboard_screen.dart';
import 'ot_discharge_dashboard_screen.dart';
import 'ot_ward_queue_screen.dart';
import '../widgets/ot/accountant_desk_home_panel.dart';
import '../widgets/ot/assistant_desk_home_panel.dart';
import '../widgets/ot/discharge_desk_home_panel.dart';
import '../widgets/ot/counselling_desk_home_panel.dart';
import '../widgets/ot/ot_appointment_desk_home_panel.dart';
import '../widgets/ot/ward_desk_home_panel.dart';
import 'ot_appointment_list_screen.dart';
import 'primary_exam_screen.dart';
import 'reports_screen.dart';
import 'patients_screen.dart';
import 'subscription_billing_screen.dart';
import 'ot_counsellor_dashboard_screen.dart';
import 'ot_money_report_screen.dart';

// Drill-down gates — same checks as the matching TabletShell rail entry, so a
// live permission refresh pops a drill-down the user can no longer reach.
bool _canAccountant(PermissionService p) => p.can(Perm.otPaymentRecord);
bool _canWard(PermissionService p) => p.can(Perm.otWardEntry);
bool _canAssistant(PermissionService p) => p.canAny([
  Perm.otLensRecord,
  Perm.otLensImplant,
  Perm.otSurgeryReady,
  Perm.otSurgeryRecord,
]);
bool _canDischarge(PermissionService p) => p.canAny([
  Perm.otDischargeGenerate,
  Perm.otBillingManage,
  Perm.otBillPrint,
  Perm.otCertificatePrint,
]);
bool _canOtAppointments(PermissionService p) =>
    p.canAny([Perm.otAppointmentView, Perm.otPatientList, Perm.dashboardOt]);
bool _canUsers(PermissionService p) =>
    p.canAny([Perm.masterDoctors, Perm.masterReceptions, Perm.masterOtStaff]);
bool _canLensReport(PermissionService p) =>
    p.canAny([Perm.reportsView, Perm.otReportsView]);
bool _canShareHistory(PermissionService p) => p.can(Perm.opdExamHistory);
bool _canOtCounsellor(PermissionService p) => p.can(Perm.otCounsellingFill);
bool _canPatients(PermissionService p) => p.can(Perm.opdPatientView);
bool _canPhoneHistory(PermissionService p) =>
    p.can(Perm.opdPatientRegisterPhone);
bool _canReports(PermissionService p) =>
    p.can(Perm.reportsView) || p.can(Perm.opdReportsView);
bool _canCollection(PermissionService p) =>
    p.canAny([Perm.opdPatientView, Perm.reportsView, Perm.opdReportsView]);

/// Tablet admin/receptionist dashboard — Pattern B (grid/card, two-column
/// on wide layouts). Business logic (fetch/cache/refresh/count-up) ported
/// unchanged from eye_care_app/lib/screens/dashboard_screen.dart; only the
/// widget tree is rebuilt for the wider canvas. Quick actions call
/// [onNavigate] to switch the tablet shell's rail selection instead of
/// pushing a route.
class DashboardScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final void Function(String railId) onNavigate;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin
    implements Refreshable {
  DashboardData? _data;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Timer? _timer;
  late final AnimationController _countCtrl;
  late final Animation<double> _countAnim;
  // _TodayPatientsWidget manages its own fetch/state independently — it
  // never re-fetches just because this screen rebuilds, so adding a patient
  // from anywhere (this screen's own Quick Actions, the Patients tab, an OT
  // appointment) left it showing stale data until the app was fully closed
  // and reopened (a fresh mount). This key lets every place that already
  // refreshes the dashboard also poke this widget's own reload.
  final _todayPatientsKey = GlobalKey<_TodayPatientsWidgetState>();
  // The 5 OT-role desk panels (_buildOtDeskHomePanel) are mutually
  // exclusive — a login only ever matches one — so one shared key is
  // enough to reach whichever one is actually built, the same way
  // _todayPatientsKey reaches the receptionist widget above.
  final _deskPanelKey = GlobalKey<State>();

  // User-resized widths (fraction 0.0-1.0 of the row's available width) for
  // My Primary Queue / Revenue Overview / Reception — Today — see
  // DashboardLayoutPrefs. Absent entries fall back to this screen's own
  // computed default for that block, so nothing looks different until the
  // user actually drags a handle.
  final Map<String, double> _customWidthFraction = {};
  List<String> _blockOrder = List<String>.from(
    DashboardLayoutPrefs.defaultOrder,
  );
  // OT desk cards switch the panel under them. Counts from the panel fill
  // the cards even before the new dashboard fields are on the live API.
  String _deskTab = 'queue';
  final Map<String, int> _deskCounts = {};
  int? _viewAssistantId;
  // Client report (2026-10-07): web's Primary Queue panel has a
  // `data-pq-search`/`data-pq-name` client-side name filter
  // (index.blade.php) that this panel never had. The whole queue is
  // already loaded in `d.primaryQueue`, so this filters in memory — no
  // extra API call, same as web's own JS filter.
  final _primaryQueueSearchCtrl = TextEditingController();
  String _primaryQueueSearch = '';

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _countAnim = CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut);
    _fetch();
    _loadLayout();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _data != null) setState(() {});
    });
  }

  void _moveBlock(List<String> visible, String id, int dir) {
    final order = [
      ..._blockOrder,
      for (final known in DashboardLayoutPrefs.defaultOrder)
        if (!_blockOrder.contains(known)) known,
    ];
    final i = order.indexOf(id);
    if (i < 0) return;
    var j = i + dir;
    while (j >= 0 && j < order.length && !visible.contains(order[j])) {
      j += dir;
    }
    if (j < 0 || j >= order.length) return;
    final next = [...order];
    final swap = next[i];
    next[i] = next[j];
    next[j] = swap;
    setState(() => _blockOrder = next);
    DashboardLayoutPrefs.instance.setOrder(widget.user.id, next);
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadLayout() async {
    final order = await DashboardLayoutPrefs.instance.getOrder(widget.user.id);
    if (mounted) setState(() => _blockOrder = order);
    for (final id in DashboardLayoutPrefs.defaultOrder) {
      final f = await DashboardLayoutPrefs.instance.getFraction(
        widget.user.id,
        id,
      );
      if (f != null && mounted) setState(() => _customWidthFraction[id] = f);
    }
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _timer?.cancel();
    _primaryQueueSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _fetch();

  Future<void> _fetch() async {
    if (_data == null) {
      final cached = await DashboardService.instance.getCached();
      if (cached != null && mounted) {
        setState(() {
          _data = cached;
          _loading = false;
        });
        _countCtrl.forward(from: 0);
      } else if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }
    if (mounted) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }
    try {
      final fresh = await DashboardService.instance.fetchDashboard();
      if (!mounted) return;
      // Only mounted for a receptionist (see _buildBody) — a no-op
      // currentState for every other role.
      _todayPatientsKey.currentState?.refresh();
      // The embedded OT desk panel (Accountant/Ward/Assistant/Discharge/
      // Counsellor) manages its own fetch and never reloads just because
      // this screen rebuilds — same reason _todayPatientsKey exists above.
      // Without this, every OT-role login's pull-to-refresh spun but their
      // actual queue/table stayed frozen at whatever loaded on first mount.
      (_deskPanelKey.currentState as Refreshable?)?.refreshSilently();
      // Always adopt the freshly-fetched data — this previously only
      // happened when _isDifferent() flagged a change across a hand-picked
      // subset of counters, so any real change outside that subset (OT
      // totals, doctor-card details, queue contents/order, etc.) made
      // pull-to-refresh spin and silently keep showing stale data. Only
      // skip the count-up animation when nothing in that subset changed.
      final changed = _data == null || _isDifferent(_data!, fresh);
      setState(() {
        _data = fresh;
        _loading = false;
        _refreshing = false;
      });
      if (changed) _countCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      if (_data == null) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _refreshing = false;
        });
      } else {
        setState(() => _refreshing = false);
      }
    }
  }

  bool _isDifferent(DashboardData a, DashboardData b) =>
      a.todayPatients != b.todayPatients ||
      a.primaryQueueCount != b.primaryQueueCount ||
      a.secondaryQueueCount != b.secondaryQueueCount ||
      a.revenueToday != b.revenueToday ||
      a.revenueMonth != b.revenueMonth ||
      a.primaryQueue.length != b.primaryQueue.length ||
      a.receptionists.length != b.receptionists.length ||
      a.doctorCards.length != b.doctorCards.length ||
      a.pendingShareRequestsCount != b.pendingShareRequestsCount;

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const AppSkeletonList(count: 5, itemHeight: 90);
    }
    if (_error != null && _data == null) {
      return _buildError();
    }
    return Stack(
      children: [
        AppRefreshIndicator(
          color: AppColors.primary,
          onRefresh: _fetch,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildBody(),
          ),
        ),
        if (_refreshing)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: AppColors.primary,
          ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final p = PermissionService.instance;
    final hasNoPermissions =
        !p.isSuper &&
        !p.canModule('opd') &&
        !p.canModule('ot') &&
        !p.canModule('master') &&
        !p.canModule('setting') &&
        !p.canModule('report');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App-only addition (no web equivalent) — restricted to Hospital
        // Admin per explicit request; other roles go straight to their
        // Overview cards without it.
        if (p.isSuper) _buildGreetingCard(d),
        _buildReceptionQuickActions(d),
        if (hasNoPermissions) _buildNoPermissionsBanner(),
        if (d.subscriptionDaysLeft != null && d.subscriptionDaysLeft! <= 14)
          _buildSubscriptionBanner(d.subscriptionDaysLeft!),
        const AppSectionHeader(title: "Today's Overview"),
        _buildStatsGrid(d),
        _buildOtDeskHomePanel(d) ?? const SizedBox.shrink(),
        const SizedBox(height: 20),
        // Web's actual order (index.blade.php): Row 2 is My Primary Queue +
        // Revenue Overview/staff side by side (col-lg-8 + col-lg-4); "Today
        // Added Patients" is a SEPARATE, full-width row below both — it was
        // previously stacked underneath Primary Queue inside the same left
        // column here, which doesn't match web's layout.
        // User-resizable layout (client request 2026-09-28): one fixed static
        // arrangement kept fighting itself across roles — a role with no
        // Primary Queue needed different proportions than one with all
        // three blocks, and every width breakpoint chosen for one role's
        // combination looked wrong for another's. Rather than keep
        // hand-branching every permission combination, the three blocks
        // (Queue, Revenue, Reception) now sit in a `Wrap`, each with a
        // user-draggable width (persisted per user — see
        // DashboardLayoutPrefs) that falls back to a sane computed default.
        // The left grip swaps a block with its neighbour so it can move
        // into space on its left or right. Width stays stored on the block
        // id. Narrowing a block still lets the next one sit beside it.
        // Cards are not placed at a free x/y.
        LayoutBuilder(
          builder: (context, constraints) {
            // Exclude `isOtDoctor` (the ot_assistant role) — see the matching
            // note on `_buildStatsGrid`'s `canSeeClinical`; without it, OT
            // Assistant gets My Primary Queue with no permission, unlike web.
            final showQueue =
                p.can(Perm.dashboardClinical) || (d.isDoctor && !d.isOtDoctor);
            final showRevenue = p.can(Perm.dashboardRevenue);
            final showReception =
                p.can(Perm.dashboardStaff) && d.receptionists.isNotEmpty;
            if (!showQueue && !showRevenue && !showReception)
              return const SizedBox.shrink();

            const gap = 16.0;
            final visible = [
              if (showQueue) DashboardLayoutPrefs.queueBlock,
              if (showRevenue) DashboardLayoutPrefs.revenueBlock,
              if (showReception) DashboardLayoutPrefs.receptionBlock,
            ];
            final blockIds = [
              for (final id in _blockOrder)
                if (visible.contains(id)) id,
              for (final id in visible)
                if (!_blockOrder.contains(id)) id,
            ];
            final totalWidth = constraints.maxWidth;

            double minWidthFor(String id) => switch (id) {
              DashboardLayoutPrefs.queueBlock => 420.0,
              _ => 200.0,
            };

            // Only used until the user actually drags a handle — chosen to
            // roughly match what the previous hand-branched layout produced
            // for each combination, so nothing looks different at first.
            double defaultWidth(String id) {
              if (blockIds.length == 1) return totalWidth;
              if (id == DashboardLayoutPrefs.queueBlock) {
                return totalWidth * (blockIds.length == 3 ? 0.46 : 0.62);
              }
              final siblingCount = blockIds.length - (showQueue ? 1 : 0);
              final sideWidth = showQueue
                  ? totalWidth * (blockIds.length == 3 ? 0.50 : 0.34)
                  : totalWidth;
              final share = siblingCount > 1
                  ? (sideWidth - gap) / siblingCount
                  : sideWidth;
              return share.clamp(minWidthFor(id), 480.0);
            }

            Widget buildBlock(String id) {
              final minW = minWidthFor(id);
              final maxW = totalWidth;
              final saved = _customWidthFraction[id];
              final width =
                  (saved != null ? saved * totalWidth : defaultWidth(id)).clamp(
                    minW,
                    maxW,
                  );
              final child = switch (id) {
                DashboardLayoutPrefs.queueBlock => _buildPrimaryQueue(d),
                DashboardLayoutPrefs.revenueBlock => _buildRevenueCard(d),
                _ => _buildReceptionTable(d),
              };
              return ResizableDashboardBlock(
                key: ValueKey(id),
                width: width,
                minWidth: minW,
                maxWidth: maxW,
                onResize: (w) =>
                    setState(() => _customWidthFraction[id] = w / totalWidth),
                onResizeEnd: () {
                  final f = _customWidthFraction[id];
                  if (f != null)
                    DashboardLayoutPrefs.instance.setFraction(
                      widget.user.id,
                      id,
                      f,
                    );
                },
                onMove: blockIds.length < 2
                    ? null
                    : (dir) => _moveBlock(blockIds, id, dir),
                child: child,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [for (final id in blockIds) buildBlock(id)],
                ),
                if (_customWidthFraction.isNotEmpty ||
                    !_sameOrder(_blockOrder, DashboardLayoutPrefs.defaultOrder))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PressScaleWrapper(
                      onTap: () async {
                        await DashboardLayoutPrefs.instance.resetAll(
                          widget.user.id,
                        );
                        if (mounted) {
                          setState(() {
                            _customWidthFraction.clear();
                            _blockOrder = List<String>.from(
                              DashboardLayoutPrefs.defaultOrder,
                            );
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            size: 13,
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reset card layout',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (p.can(Perm.dashboardReception) && d.isReceptionist) ...[
          const SizedBox(height: 16),
          _TodayPatientsWidget(
            key: _todayPatientsKey,
            user: widget.user,
            hospital: widget.hospital,
            onNavigate: widget.onNavigate,
          ),
        ],
      ],
    );
  }

  // ── Reception quick-actions (Walk In / Phone / OT Appointment) ──────────
  // Web (hospital/layouts/app.blade.php): 3 plain nav links shown only for a
  // receptionist on the dashboard route, each individually permission-gated
  // — `patient_register` / `patient_register_phone` / `ot_appointment_create`
  // — matched here exactly. Opens the same add-forms already used elsewhere
  // in this app (PatientFormScreen / OtAppointmentFormPane) as a dialog,
  // the established convention for launching a shell-embedded form outside
  // its own screen.

  Widget _buildReceptionQuickActions(DashboardData d) {
    if (!d.isReceptionist) return const SizedBox.shrink();
    final p = PermissionService.instance;
    final canWalkIn = p.can(Perm.opdPatientRegister);
    final canPhone = p.can(Perm.opdPatientRegisterPhone);
    final canOt = p.can(Perm.otAppointmentCreate);
    if (!canWalkIn && !canPhone && !canOt) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (canWalkIn) ...[
            Expanded(
              child: _quickActionBtn(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Walk In',
                onTap: _openWalkInQuick,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (canPhone) ...[
            Expanded(
              child: _quickActionBtn(
                icon: Icons.phone_in_talk_rounded,
                label: 'Phone',
                onTap: _openPhoneQuick,
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (canOt)
            Expanded(
              child: _quickActionBtn(
                icon: Icons.event_note_rounded,
                label: 'OT Appointment',
                onTap: _openOtAppointmentQuick,
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return PressScaleWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWalkInQuick() async {
    await showPaneDialog<void>(
      context,
      barrierDismissible: false,
      builder: (dCtx) => PatientFormScreen(
        mode: PatientFormMode.addWalkIn,
        user: widget.user,
        hospital: widget.hospital,
        onSaved: (_) {
          Navigator.pop(dCtx);
          _fetch();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openPhoneQuick() async {
    await showPaneDialog<void>(
      context,
      barrierDismissible: false,
      builder: (dCtx) => PatientFormScreen(
        mode: PatientFormMode.addPhone,
        user: widget.user,
        hospital: widget.hospital,
        onSaved: (_) {
          Navigator.pop(dCtx);
          _fetch();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openOtAppointmentQuick() async {
    await showPaneDialog<void>(
      context,
      barrierDismissible: false,
      builder: (dCtx) => OtAppointmentFormPane(
        item: null,
        onSaved: () {
          Navigator.pop(dCtx);
          _fetch();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  // ── Banners ────────────────────────────────────────────────────────────

  Widget _buildNoPermissionsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
        ),
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
                Text(
                  'No Permissions Configured',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your role has no feature permissions assigned. Please contact your administrator.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Web pull parity (2026-09-29) — the "Renew →" text was a dead label with
  // no `onTap` at all; web's own version of this banner links into
  // `hospital.subscription.index` (View Plan History + download invoices —
  // see WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #1). That page is
  // admin-only on web (`SubscriptionController::ensureHospitalAdmin()`), so
  // only super-role users get a working tap target here; other roles still
  // see the same warning text, just not tappable, rather than tapping into
  // a 403.
  Widget _buildSubscriptionBanner(int days) {
    final isSuper = PermissionService.instance.isSuper;
    return GestureDetector(
      onTap: isSuper ? () => showSubscriptionBillingPane(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Subscription expires in $days day${days == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            if (isSuper)
              const Text(
                'Renew →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Greeting hero card ────────────────────────────────────────────────

  Widget _buildGreetingCard(DashboardData d) {
    final hour = toHospitalTime(DateTime.now()).hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final firstName = widget.user.name.trim().split(RegExp(r'\s+')).first;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = toHospitalTime(DateTime.now());
    final dateStr =
        '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$greeting, ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: firstName,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateStr  ·  ${d.isDoctor ? d.myTodayPatients : d.todayPatients} patients today',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _countAnim,
                  builder: (_, _) => Text(
                    '${((d.isDoctor ? d.myPrimaryPending : d.primaryQueueCount) * _countAnim.value).round()}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'in queue',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats grid (wraps to fit — replaces mobile's horizontal scroll rows) ─

  /// Web swaps the generic "OT Appointment" card for a role-specific
  /// pending-count card for Accountant/Ward Management/OT Assistant/
  /// Discharge Counter — mirrors `Hospital\DashboardController.php:386-460`
  /// + `index.blade.php`'s `@if/@elseif` chain exactly (each field is null
  /// unless that role is logged in, so this is a plain first-match swap).
  /// See DASHBOARD_PARITY_FIX_PLAN.md Phase 4. Tablet uses a `Wrap` (not a
  /// scroll `Row` like mobile), so no leading `SizedBox` separators needed.
  void _selectDesk(String tab) => setState(() => _deskTab = tab);

  void _onDeskCounts(Map<String, int> counts) {
    if (!mounted) return;
    setState(() {
      _deskCounts
        ..clear()
        ..addAll(counts);
    });
  }

  int _deskCount(String tab, int? fromApi) => _deskCounts[tab] ?? fromApi ?? 0;

  void _openAssistant(OtAssistantPeer peer) {
    setState(() {
      _viewAssistantId = peer.id;
      _deskTab = 'queue';
      _deskCounts.clear();
    });
  }

  List<Widget> _otSlotCards(DashboardData d) {
    // Card taps switch the desk panel under the cards (web data-acc-tab).
    // "Open full page" on the panel is the only navigation, except OT Report
    // which is a real link to the money report on web too.
    if (d.accountantPendingCount != null) {
      return [
        _statCard(
          label: 'Pending Patients',
          value: '${_deskCount('queue', d.accountantPendingCount)}',
          icon: Icons.hourglass_bottom_rounded,
          iconBg: AppColors.orange,
          badge: 'OT payment',
          rawCount: _deskCount('queue', d.accountantPendingCount),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Refunds',
          value: '${_deskCount('refunds', d.accountantRefundsCount)}',
          icon: Icons.replay_rounded,
          iconBg: const Color(0xFFC0392B),
          badge: 'Surgery refused',
          rawCount: _deskCount('refunds', d.accountantRefundsCount),
          selected: _deskTab == 'refunds',
          onTap: () => _selectDesk('refunds'),
        ),
        _statCard(
          label: 'Completed',
          value: '${_deskCount('history', d.accountantCompletedCount)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Verified+',
          rawCount: _deskCount('history', d.accountantCompletedCount),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
        _statCard(
          label: 'OT Report',
          value: '—',
          icon: Icons.payments_outlined,
          iconBg: AppColors.teal,
          badge: 'Money',
          onTap: () => openOtMoneyReport(context),
        ),
      ];
    }
    if (d.wardPendingCount != null) {
      return [
        _statCard(
          label: 'Pending Patient',
          value: '${_deskCount('queue', d.wardPendingCount)}',
          icon: Icons.hourglass_bottom_rounded,
          iconBg: AppColors.orange,
          badge: 'Ward entry',
          rawCount: _deskCount('queue', d.wardPendingCount),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Completed',
          value: '${_deskCount('history', d.wardCompletedCount)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Ready onward',
          rawCount: _deskCount('history', d.wardCompletedCount),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
      ];
    }
    if (d.otAssistantPendingCount != null) {
      final viewingId = _viewAssistantId;
      return [
        _statCard(
          label: 'Pending Patient',
          value:
              '${_deskCount('queue', viewingId == null ? d.otAssistantPendingCount : null)}',
          icon: Icons.hourglass_bottom_rounded,
          iconBg: AppColors.orange,
          badge: 'Ready for OT',
          rawCount: _deskCount(
            'queue',
            viewingId == null ? d.otAssistantPendingCount : null,
          ),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Completed',
          value:
              '${_deskCount('history', viewingId == null ? d.otAssistantCompletedCount : null)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Surgery done',
          rawCount: _deskCount(
            'history',
            viewingId == null ? d.otAssistantCompletedCount : null,
          ),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
        for (final peer in d.otAssistantPeers)
          _statCard(
            label: peer.name,
            value: '${peer.assignedCount}',
            icon: Icons.person_outline_rounded,
            iconBg: AppColors.purple,
            badge: 'Assigned',
            rawCount: peer.assignedCount,
            selected: viewingId == peer.id,
            onTap: () => _openAssistant(peer),
          ),
      ];
    }
    if (d.dischargePendingCount != null) {
      return [
        _statCard(
          label: 'Pending Patient',
          value: '${_deskCount('queue', d.dischargePendingCount)}',
          icon: Icons.hourglass_bottom_rounded,
          iconBg: AppColors.orange,
          badge: 'Operated',
          rawCount: _deskCount('queue', d.dischargePendingCount),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Completed',
          value: '${_deskCount('history', d.dischargeCompletedCount)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Discharged',
          rawCount: _deskCount('history', d.dischargeCompletedCount),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
      ];
    }
    if (d.otAppointmentPendingCount != null) {
      return [
        _statCard(
          label: 'OT Appointment',
          value: '${_deskCount('queue', d.otAppointmentPendingCount)}',
          icon: Icons.calendar_today_rounded,
          iconBg: const Color(0xFFC2185B),
          badge: 'Appointments today',
          rawCount: _deskCount('queue', d.otAppointmentPendingCount),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Completed',
          value: '${_deskCount('history', d.otAppointmentCompletedCount)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Checked in today',
          rawCount: _deskCount('history', d.otAppointmentCompletedCount),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
      ];
    }
    if (d.counsellingPendingCount != null) {
      return [
        _statCard(
          label: 'Pending Patient',
          value: '${_deskCount('queue', d.counsellingPendingCount)}',
          icon: Icons.hourglass_bottom_rounded,
          iconBg: AppColors.orange,
          badge: 'Awaiting counselling',
          rawCount: _deskCount('queue', d.counsellingPendingCount),
          selected: _deskTab == 'queue',
          onTap: () => _selectDesk('queue'),
        ),
        _statCard(
          label: 'Completed',
          value: '${_deskCount('history', d.counsellingCompletedCount)}',
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.green,
          badge: 'Counselled today',
          rawCount: _deskCount('history', d.counsellingCompletedCount),
          selected: _deskTab == 'history',
          onTap: () => _selectDesk('history'),
        ),
        _statCard(
          label: 'Payment Status',
          value: '${_deskCount('payments', d.counsellingPaymentCount)}',
          icon: Icons.shield_outlined,
          iconBg: const Color(0xFF34495E),
          badge: 'Package paid & onward',
          rawCount: _deskCount('payments', d.counsellingPaymentCount),
          selected: _deskTab == 'payments',
          onTap: () => _selectDesk('payments'),
        ),
      ];
    }
    if (!PermissionService.instance.can(Perm.dashboardOt)) return const [];
    return [
      _statCard(
        label: 'OT Appointment',
        value: '${d.otToday}',
        icon: Icons.medical_services_rounded,
        iconBg: AppColors.teal,
        badge: '${d.otOperated} confirmed',
        rawCount: d.otToday,
        onTap: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'OT Appointments',
              allowed: _canOtAppointments,
              child: OtAppointmentListScreen(),
            ),
          ),
        ),
      ),
    ];
  }

  /// Web's own DOM order (`index.blade.php`): the compact desk panel for
  /// each of the 4 staff-desk roles sits directly BELOW the stat cards this
  /// screen already renders in [_otSlotCards] — same role-detection (the
  /// dashboard's count-only stat fields) and the same `allowed` gate/target
  /// screen each stat card's own `onTap` already pushes to, just also
  /// rendered inline here as a full row/queue/history preview. Mutually
  /// exclusive with the other 3 — a login only ever matches one of these
  /// roles, exactly like [_otSlotCards]'s own `if` chain.
  Widget? _buildOtDeskHomePanel(DashboardData d) {
    if (d.otAppointmentPendingCount != null) {
      return OtAppointmentDeskHomePanel(
        key: _deskPanelKey,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'OT Appointments',
              allowed: _canOtAppointments,
              child: OtAppointmentListScreen(),
            ),
          ),
        ),
      );
    }
    if (d.accountantPendingCount != null) {
      return AccountantDeskHomePanel(
        key: _deskPanelKey,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'Accountant / Billing',
              allowed: _canAccountant,
              child: OtAccountantDashboardScreen(),
            ),
          ),
        ),
      );
    }
    if (d.wardPendingCount != null) {
      return WardDeskHomePanel(
        key: _deskPanelKey,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'Ward Entry Queue',
              allowed: _canWard,
              child: OtWardQueueScreen(),
            ),
          ),
        ),
      );
    }
    if (d.otAssistantPendingCount != null) {
      final viewing = d.otAssistantPeers
          .where((p) => p.id == _viewAssistantId)
          .firstOrNull;
      return AssistantDeskHomePanel(
        key: _deskPanelKey,
        user: widget.user,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        assistantId: _viewAssistantId,
        viewingName: viewing?.name,
        onBackToMine: () => setState(() {
          _viewAssistantId = null;
          _deskTab = 'queue';
          _deskCounts.clear();
        }),
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            StandaloneScreen(
              title: 'Surgery Queue',
              allowed: _canAssistant,
              child: OtAssistantDashboardScreen(user: widget.user),
            ),
          ),
        ),
      );
    }
    if (d.dischargePendingCount != null) {
      return DischargeDeskHomePanel(
        key: _deskPanelKey,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'Discharge & Invoices',
              allowed: _canDischarge,
              child: OtDischargeDashboardScreen(),
            ),
          ),
        ),
      );
    }
    if (d.counsellingPendingCount != null) {
      return CounsellingDeskHomePanel(
        key: _deskPanelKey,
        requestedTab: _deskTab,
        onDeskTab: _selectDesk,
        onCounts: _onDeskCounts,
        onOpenFullPage: () => Navigator.of(context).push(
          appRoute(
            const StandaloneScreen(
              title: 'OT Counsellor',
              allowed: _canOtCounsellor,
              child: OtCounsellorDashboardScreen(),
            ),
          ),
        ),
      );
    }
    return null;
  }

  /// Hospital Admin's own 8-card set — web gives the tenant's Hospital
  /// Admin (`is_super`) a completely different, simpler dashboard than
  /// every other role (`index.blade.php:1610-1725`, comment: "Hospital
  /// admin: only these 8 cards"). Mutually exclusive with the rest of
  /// `_buildStatsGrid`'s card list — see DASHBOARD_PARITY_FIX_PLAN.md
  /// Phase 7.
  // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md finding
  // #1) — matches web's exact 9-card order (`index.blade.php:1651-1799`):
  // Total Today Patients → Total Collection → Report → Primary/Second → OT
  // Appointment → Incoming Requests → Staff (ALL roles, one card) → Masters
  // → Medicines. Was previously Doctor+Reception as two separate cards (no
  // web equivalent — web shows both counts as a sub-line on one "Staff"
  // card) with no Masters/Medicines cards at all, and "OT Total" sourced
  // from the wrong model (see the `ot_total_today` backend fix).
  List<Widget> _hospitalAdminCards(DashboardData d) => [
    // Web/API: plain div, not a link.
    _statCard(
      label: 'Total Today Patients',
      value: '${d.todayPatients}',
      icon: Icons.people_alt_rounded,
      iconBg: AppColors.primary,
      rawCount: d.todayPatients,
    ),
    _statCard(
      label: 'Total Collection',
      value: _fmtRupee(d.revenueToday),
      icon: Icons.account_balance_wallet_rounded,
      iconBg: AppColors.green,
      onTap: () => Navigator.of(context).push(
        appRoute(
          PermissionGuard(
            allowed: _canCollection,
            child: AdminCollectionScreen(
              user: widget.user,
              hospital: widget.hospital,
            ),
          ),
        ),
      ),
    ),
    _statCard(
      label: 'Report',
      value: '—',
      icon: Icons.bar_chart_rounded,
      iconBg: AppColors.secondary,
      badge: 'Summary',
      onTap: () => widget.onNavigate('reports'),
    ),
    // Web/API: plain div, not a link.
    _statCard(
      label: 'Primary / Second',
      value: '${d.todayPrimary}/${d.todaySecondary}',
      icon: Icons.remove_red_eye_rounded,
      iconBg: AppColors.teal,
    ),
    _statCard(
      label: 'OT Appointment',
      value: '${d.otTotalToday}',
      icon: Icons.calendar_month_rounded,
      iconBg: const Color(0xFFC2185B),
      badge: 'Today',
      rawCount: d.otTotalToday,
      onTap: () => Navigator.of(context).push(
        appRoute(
          const StandaloneScreen(
            title: 'OT Appointments',
            allowed: _canOtAppointments,
            child: OtAppointmentListScreen(),
          ),
        ),
      ),
    ),
    if (d.pendingShareRequestsCount != null)
      _statCard(
        label: 'Incoming Requests',
        value: '${d.pendingShareRequestsCount}',
        icon: Icons.send_rounded,
        iconBg: AppColors.secondary,
        rawCount: d.pendingShareRequestsCount,
        onTap: () => Navigator.of(context).push(
          appRoute(
            StandaloneScreen(
              title: 'Share Requests',
              allowed: _canShareHistory,
              child: ShareHistoryScreen(
                user: widget.user,
                hospital: widget.hospital,
                initialTab: 2,
              ),
            ),
          ),
        ),
      ),
    _statCard(
      label: 'Staff',
      value: '${d.totalUsersAllRoles}',
      icon: Icons.person_add_alt_1_rounded,
      iconBg: AppColors.blue,
      badge: 'Dr: ${d.totalDoctors} & Rec: ${d.totalReceptions}',
      rawCount: d.totalUsersAllRoles,
      onTap: () => Navigator.of(context).push(
        appRoute(
          StandaloneScreen(
            title: 'Users',
            allowed: _canUsers,
            child: UsersScreen(user: widget.user, hospital: widget.hospital),
          ),
        ),
      ),
    ),
    _statCard(
      label: 'Masters',
      value: '—',
      icon: Icons.tune_rounded,
      iconBg: AppColors.orange,
      badge: 'Case types, OT & more',
      onTap: () => widget.onNavigate('masters'),
    ),
    _statCard(
      label: 'Medicines',
      value: '${d.totalMedicines}',
      icon: Icons.medication_rounded,
      iconBg: AppColors.purple,
      badge: 'Medicine master list',
      rawCount: d.totalMedicines,
      onTap: () => widget.onNavigate('medicines'),
    ),
    // Web pull 2026-10-14 — admin's new "Lens Report" quick-link card. Not
    // a rail item (it lives inside OT Reports), so pushed standalone same
    // as "Staff" above rather than routed via widget.onNavigate().
    _statCard(
      label: 'Lens Report',
      value: '${d.totalLensToday}',
      icon: Icons.remove_red_eye_rounded,
      iconBg: AppColors.blue,
      badge: 'Lenses used today',
      rawCount: d.totalLensToday,
      onTap: () => Navigator.of(context).push(
        appRoute(
          StandaloneScreen(
            title: 'Lens Report',
            allowed: _canLensReport,
            child: OtLensReportScreen(canExport: PermissionService.instance.canAny([Perm.reportsExport, Perm.otReportsExport])),
          ),
        ),
      ),
    ),
  ];

  Widget _buildStatsGrid(DashboardData d) {
    final p = PermissionService.instance;
    if (p.isSuper) {
      return _cardStrip(_hospitalAdminCards(d));
    }
    // Web/API: dashboard_clinical (doctors also allowed server-side). `isDoctor`
    // is also `true` for the `ot_assistant` role (API's doctor-card-visibility
    // flag, unrelated to this gate — see Api\DashboardController.php's
    // `$isDoctorRoleForClinicalGate` vs `$isDoctor` distinction), so the
    // role-based bypass here must explicitly exclude `isOtDoctor` or OT
    // Assistant wrongly inherits the OPD doctor's clinical cards with no
    // permission granted — web's index controller never does this (its own
    // bypass checks the retired 'ot_doctor' slug, which no role has any more).
    final canSeeClinical =
        p.can(Perm.dashboardClinical) || (d.isDoctor && !d.isOtDoctor);
    final canSeeRegistrations = p.can(Perm.dashboardReception);
    final cards = <Widget>[
      // Web parity: the entire generic bento-grid is suppressed for
      // receptionist regardless of which individual permissions the role
      // happens to carry (`index.blade.php`'s `@if(!$isReceptionistUser)`,
      // ~line 1215) — receptionist gets its own 6-card row below instead,
      // which already includes its own OT Appointment card. Gating each
      // card individually (as before) still let "Today's Patients"/
      // "Pending Exams"/"OPD Queue" leak through whenever a receptionist
      // role was also granted dashboard_clinical, and let _otSlotCards'
      // generic OT-appointment fallback duplicate the receptionist row's
      // own OT Appointment card.
      if (!d.isReceptionist) ...[
        if (canSeeClinical) ...[
          _statCard(
            label: d.isOtDoctor
                ? 'My OT Today'
                : d.isDoctor
                ? 'My Patients'
                : "Today's Patients",
            value: '${d.isDoctor ? d.myTodayPatients : d.todayPatients}',
            icon: d.isOtDoctor
                ? Icons.medical_services_rounded
                : Icons.person_2_rounded,
            iconBg: AppColors.purple,
            badge: d.isOtDoctor ? 'OT' : 'Assigned to you today',
            rawCount: d.isDoctor ? d.myTodayPatients : d.todayPatients,
          ),
          if (!d.isOtDoctor) ...[
            _statCard(
              label: 'Pending Exams',
              value: '${d.pendingExams}',
              icon: Icons.pending_actions_rounded,
              iconBg: AppColors.orange,
              badge: 'In queue',
              rawCount: d.pendingExams,
            ),
            _opdQueueCard(
              d.isDoctor ? d.myPrimaryPending : d.primaryQueueCount,
              d.isDoctor ? d.mySecondaryPending : d.secondaryQueueCount,
            ),
          ],
        ],
        ..._otSlotCards(d),
        if (canSeeRegistrations)
          _statCard(
            label: 'Registrations',
            value: '${d.todayRegistrations}',
            icon: Icons.fact_check_rounded,
            iconBg: AppColors.primary,
            badge: 'Walk-in: ${d.todayWalkin} • Phone: ${d.todayPhone}',
            rawCount: d.todayRegistrations,
          ),
        // Web/API: dashboard_revenue (receptionist gets Today Collection in
        // their own 6-card row instead — see index.blade.php's
        // `$hasRevenue && !$isReceptionistUser` guard).
        if (p.can(Perm.dashboardRevenue))
          _statCard(
            label: 'Today Revenue',
            value: _fmtRupee(d.revenueToday),
            icon: Icons.currency_rupee_rounded,
            iconBg: AppColors.green,
            badge: 'Month: ${_fmtRupee(d.revenueMonth)}',
          ),
      ],
      if (p.can(Perm.dashboardReception) &&
          d.isReceptionist &&
          d.receptionistStats != null)
        ..._receptionistStatCards(d, d.receptionistStats!),
    ];

    return _cardStrip(cards);
  }

  /// Single-row horizontal-scroll strip for the stat cards — replaces the
  /// old `Wrap`, which let cards spill onto extra rows (and waste vertical
  /// space) whenever the pane wasn't wide enough for all of them. Now every
  /// card set stays one row tall; once there are more cards than fit, the
  /// row scrolls left↔right instead of wrapping.
  Widget _cardStrip(List<Widget> cards) {
    return SizedBox(
      height: 66,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => cards[i],
        ),
      ),
    );
  }

  /// Web's receptionist-only 6-card row (`index.blade.php`'s `.rec-5row`) —
  /// Today Collection, Total Patients, My Patients, Reports, Phone
  /// Appointments, OT Appointment. This previously showed a different,
  /// made-up 4-card set (My Patients Today/Collection/Pending Phone/My
  /// Walk-ins) that didn't match web's actual cards at all.
  List<Widget> _receptionistStatCards(DashboardData d, ReceptionistStats rs) {
    final p = PermissionService.instance;
    return [
      // Web pull 2026-09-29 — web links this to the receptionist's own
      // collection drill-down (`hospital.dashboard.collection.show` with
      // `reception` = the logged-in user's own id), same screen/permission
      // the admin's own Total Collection card already uses; was previously
      // a plain, non-tappable div here.
      _statCard(
        label: 'Today Collection',
        value: _fmtRupee(rs.todayCollection),
        icon: Icons.account_balance_wallet_rounded,
        iconBg: AppColors.green,
        onTap: () => Navigator.of(context).push(
          appRoute(
            PermissionGuard(
              allowed: _canCollection,
              child: AdminCollectionDetailScreen(
                user: widget.user,
                hospital: widget.hospital,
                receptionId: widget.user.id,
                receptionName: widget.user.name,
                start: DateTime.now(),
                end: DateTime.now(),
              ),
            ),
          ),
        ),
      ),
      // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md
      // finding #5) — web shows "My Patients: X" as a meta sub-line on this
      // same card, not as its own separate card.
      _statCard(
        label: 'Total Patients',
        value: '${d.todayRegistrations}',
        icon: Icons.people_alt_rounded,
        iconBg: AppColors.primary,
        badge: 'My Patients: ${rs.myPatientsToday}',
        rawCount: d.todayRegistrations,
        onTap: () => Navigator.of(context).push(
          appRoute(
            StandaloneScreen(
              title: 'Patients',
              allowed: _canPatients,
              child: PatientsScreen(
                user: widget.user,
                hospital: widget.hospital,
              ),
            ),
          ),
        ),
      ),
      if (p.can(Perm.reportsView))
        _statCard(
          label: 'Reports',
          value: '—',
          icon: Icons.bar_chart_rounded,
          iconBg: AppColors.secondary,
          onTap: () => Navigator.of(context).push(
            appRoute(
              StandaloneScreen(
                title: 'Reports',
                allowed: _canReports,
                child: ReportsScreen(
                  user: widget.user,
                  hospital: widget.hospital,
                ),
              ),
            ),
          ),
        ),
      _statCard(
        label: 'Phone Appt',
        value: '${d.todayPhone}',
        icon: Icons.phone_rounded,
        iconBg: AppColors.teal,
        badge: 'My Patient: ${rs.myPhoneToday}',
        rawCount: d.todayPhone,
        onTap: () => Navigator.of(context).push(
          appRoute(
            StandaloneScreen(
              title: 'Phone Appointment History',
              allowed: _canPhoneHistory,
              child: PhoneHistoryScreen(
                user: widget.user,
                hospital: widget.hospital,
              ),
            ),
          ),
        ),
      ),
      if (p.can(Perm.dashboardOt))
        _statCard(
          label: 'OT Appointment',
          value: '${d.otToday}',
          icon: Icons.medical_services_rounded,
          iconBg: const Color(0xFFC2185B),
          badge: 'Confirmed: ${d.otOperated} • Booked: ${d.otPending}',
          rawCount: d.otToday,
          onTap: () => Navigator.of(context).push(
            appRoute(
              const StandaloneScreen(
                title: 'OT Appointments',
                allowed: _canOtAppointments,
                child: OtAppointmentListScreen(),
              ),
            ),
          ),
        ),
      // Web pull 2026-09-29 (WEB_ADMIN_RECEPTIONIST_DASHBOARD_AUDIT.md
      // finding #2) — web's 6th receptionist card, gated by
      // `ot_counselling_fill` (API sends null when the viewer lacks it).
      if (rs.counsellingPending != null)
        _statCard(
          label: 'OT Counselling',
          value: '${rs.counsellingPending}',
          icon: Icons.favorite_rounded,
          iconBg: const Color(0xFFD68910),
          badge: 'Pending counselling',
          rawCount: rs.counsellingPending,
          onTap: () => Navigator.of(context).push(
            appRoute(
              const StandaloneScreen(
                title: 'OT Counsellor',
                allowed: _canOtCounsellor,
                child: OtCounsellorDashboardScreen(),
              ),
            ),
          ),
        ),
    ];
  }

  /// Web parity: some overview cards are links (e.g. Total Collection,
  /// Doctor, Reception, OT Total, Incoming Requests) and some are plain
  /// stat divs (e.g. Today's Patients, Pending Exams, Revenue) —
  /// index.blade.php's <a> vs <div> per card. When [onTap] is set, the
  /// card becomes tappable and gets a small chevron + faint tint so it's
  /// visually distinct from the non-tappable ones, matching that split.
  ///
  /// v2 — a compact horizontal chip (icon left, value+label stacked tight
  /// on the right) instead of the old tall icon-on-top/number-below card,
  /// so every card fits in one 66px-tall strip instead of eating 3-4x the
  /// vertical space. A card with a [badge] runs slightly wider (badge
  /// folds into the label line as "label · badge", ellipsized) than one
  /// without — no card carries dead space it doesn't need.
  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    String? badge,
    int? rawCount,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final clickable = onTap != null;
    return Container(
      width: badge != null ? 208.0 : 166.0,
      height: 66,
      decoration: BoxDecoration(
        color: clickable ? iconBg.withValues(alpha: 0.045) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? iconBg : iconBg.withValues(alpha: 0.14),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconBg),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: rawCount != null
                                ? AnimatedBuilder(
                                    animation: _countAnim,
                                    builder: (_, _) => Text(
                                      '${(rawCount * _countAnim.value).round()}',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        height: 1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                      height: 1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (clickable) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 13,
                              color: iconBg,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Client report (2026-10-07): long two-part badges
                      // (e.g. "Confirmed: 5 • Booked: 12") crammed onto this
                      // one `$label · $badge` line were getting clipped by
                      // the card's fixed width — ellipsis hid the second
                      // half entirely. FittedBox shrinks the whole line to
                      // fit instead, so it's always fully visible without
                      // touching the card's size.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          badge != null ? '$label · $badge' : label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Web renders "OPD Queue" as a distinct two-tone split box (Primary in
  /// teal, Secondary in blue) — not the generic icon/value/badge card,
  /// unlike every other stat card (`index.blade.php`'s custom OPD-QUEUE
  /// markup, ~line 1478).
  /// v2 — same compact 66px chip footprint as [_statCard]: the two-tone
  /// split now sits inline (icon · PRI n · divider · SEC n) instead of two
  /// stacked half-height blocks under an "OPD QUEUE" title row, which used
  /// to make this the tallest card in the set.
  Widget _opdQueueCard(int primary, int secondary) {
    Widget half(String value, String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
    return Container(
      width: 168,
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.remove_red_eye_rounded,
              size: 16,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                half('$primary', 'PRI', const Color(0xFF1ABC9C)),
                const SizedBox(height: 2),
                half('$secondary', 'SEC', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Primary Queue ─────────────────────────────────────────────────────

  // Web parity (`index.blade.php`'s `.bento-table`): a plain # / MRD /
  // Patient / [Doctor — Hospital Admin only] / Age-Gender / Time / Action
  // table, no search or pagination — the server already caps this to a
  // top-N queue. Previously rendered as a custom avatar+tile ListView,
  // which was never what web actually shows and (per ScaledDataTable's own
  // scale-up-or-scroll behaviour) is also what fixes the "every card gets
  // too wide when the rail expands" complaint: a table scales its columns
  // together to fill extra width instead of a single tile row stretching
  // out with empty space.
  //
  // DOCTOR/RECEPTIONIST columns were missing entirely — web's queue table
  // shows both (`@if($isHospitalAdmin) <th>Doctor</th><th>Receptionist</th>
  // @endif`) since Hospital Admin's queue spans every doctor/receptionist,
  // not "my own" like a doctor viewing their own queue already knows.
  List<ScaledTableColumn> get _queueColumns => [
    const ScaledTableColumn('#', 40, headerAlign: TextAlign.center),
    const ScaledTableColumn('MRD', 100),
    const ScaledTableColumn('PATIENT', 190),
    if (PermissionService.instance.isSuper) ...[
      const ScaledTableColumn('DOCTOR', 150),
      const ScaledTableColumn('RECEPTIONIST', 150),
    ],
    const ScaledTableColumn('AGE / GENDER', 120),
    const ScaledTableColumn('TIME', 160),
    const ScaledTableColumn('ACTION', 140, headerAlign: TextAlign.right),
  ];

  // dashboard_models.dart's QueuePatient carries only what this panel's own
  // columns need (no firstName/lastName split) — PrimaryExamScreen's header
  // and save calls only ever read `.fullName`/`.patientCode`/`.id` off the
  // Patient it's given (verified — nothing downstream touches
  // firstName/lastName), so a best-effort name split is enough to satisfy
  // Patient's required fields without a second API round-trip just to open it.
  Patient _patientFromQueue(QueuePatient q) {
    final parts = q.fullName.trim().split(RegExp(r'\s+'));
    return Patient(
      id: q.id,
      patientCode: q.patientCode,
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      fullName: q.fullName,
      age: q.age,
      gender: q.gender,
      doctorPatientNo: q.doctorPatientNo,
      checkedInAt: q.checkedInAt,
    );
  }

  Future<void> _startPrimaryExam(QueuePatient q) async {
    final result = await Navigator.of(context).push<bool>(
      appRoute(
        PermissionGuard(
          allowed: (p) => p.can(Perm.opdExamPrimary),
          child: PrimaryExamScreen(
            user: widget.user,
            hospital: widget.hospital,
            patient: _patientFromQueue(q),
          ),
        ),
      ),
    );
    if (result == true && mounted) _fetch();
  }

  Widget _buildPrimaryQueue(DashboardData d) {
    final query = _primaryQueueSearch.trim().toLowerCase();
    // (originalIndex, patient) pairs, not a plain filtered list — keeps
    // each visible row's rank # at its real queue position, matching
    // web's own filter (a pure CSS show/hide of <tr> rows, which never
    // renumbers).
    final visibleQueue = <(int, QueuePatient)>[
      for (var i = 0; i < d.primaryQueue.length; i++)
        if (query.isEmpty || d.primaryQueue[i].fullName.toLowerCase().contains(query))
          (i, d.primaryQueue[i]),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              children: [
                // Web still says "My Primary Queue" as of this pull, but the
                // user asked to rename ahead of web's own fix — "Primary
                // Queue" (it already shows every doctor's queue for Hospital
                // Admin, not just "my" own, so the old name was misleading
                // there anyway).
                Text(
                  'Primary Queue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                // Web only shows this once there's something to search
                // (`@if($primaryQueue->count() > 0)`) — matched here too.
                if (d.primaryQueue.isNotEmpty) ...[
                  SizedBox(
                    width: 180,
                    height: 32,
                    child: TextField(
                      controller: _primaryQueueSearchCtrl,
                      onChanged: (v) => setState(() => _primaryQueueSearch = v),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search patient name...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 30),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    // Web pull: the waiting badge stays the full queue
                    // total even while a search filters the rows below —
                    // matches web, where #pqSearch only ever hides/shows
                    // table rows.
                    '${d.isDoctor ? d.primaryQueue.length : d.primaryQueueCount} waiting',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
                // Web's "My Primary Queue" panel has no "View All"/drill-through
                // link at all (checked directly against index.blade.php) — it's
                // just this same top-20-rows table with an ACTION column per
                // row (an "Examine" button gated by @haspermission('exam_primary')).
                // An earlier version of this button was unconditionally shown
                // regardless of permission, which 403'd for a receptionist —
                // this time it's gated the same way web gates it (see
                // _queueRowCells below), not removed outright.
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: ScaledDataTable(
              columns: _queueColumns,
              emptyMessage: query.isEmpty
                  ? 'Queue is clear'
                  : 'No patient matches your search.',
              rows: [
                for (final (i, p) in visibleQueue)
                  _queueRowCells(p, i + 1, d.waitThresholds),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _queueRowCells(QueuePatient p, int rank, WaitThresholds t) {
    final wait = p.waitMinutes();
    final waitColor = _waitColor(wait, t);
    final genderCap = (p.gender == null || p.gender!.isEmpty)
        ? null
        : p.gender![0].toUpperCase() + p.gender!.substring(1).toLowerCase();
    final ageGender = [if (p.age != null) '${p.age}y', ?genderCap].join(' / ');
    final timeSource = p.checkedInAt ?? p.registeredAt;

    return [
      Text(
        '$rank',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.patientCode,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
      Text(
        p.fullName.isNotEmpty ? p.fullName : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      // Web parity (`index.blade.php`'s queue table): Doctor + Receptionist
      // columns only show for Hospital Admin — a doctor viewing their own
      // queue already knows whose queue it is. Must stay in sync with
      // `_queueColumns`' matching `if (PermissionService.instance.isSuper)`.
      if (PermissionService.instance.isSuper) ...[
        Text(
          p.doctorName == null
              ? '—'
              : (p.doctorPrefix != null && p.doctorPrefix!.isNotEmpty
                    ? '${p.doctorPrefix} ${p.doctorName}'
                    : p.doctorName!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          p.receptionistName ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
      Text(
        ageGender.isEmpty ? '—' : ageGender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timeSource != null)
            Text(
              _fmtTime(timeSource),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          if (timeSource != null) const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: waitColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              _fmtWait(wait),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: waitColor,
              ),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: PermissionService.instance.can(Perm.opdExamPrimary)
            ? TableLabelAction(
                label: 'Examine',
                icon: Icons.medical_services_rounded,
                tone: TableLabelTone.primary,
                onTap: () => _startPrimaryExam(p),
              )
            : const Text(
                '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    ];
  }

  // Matches web's `created_at->format('h:i A')` exactly — this project
  // avoids the `intl` package, so every time/date formatter here is manual.
  String _fmtTime(DateTime dt) {
    final local = toHospitalTime(dt);
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$h12:${local.minute.toString().padLeft(2, '0')} $period';
  }

  // ── Revenue card ──────────────────────────────────────────────────────

  /// Web parity: `index.blade.php`'s `.bento-card` + `.rev-grid` — a plain
  /// white card (not a colored gradient) with a bordered header and three
  /// equal-weight columns side by side (Today / This Month / This Year),
  /// separated by thin vertical dividers, all three the same navy weight —
  /// web gives "Today" no special highlight over the other two.
  Widget _buildRevenueCard(DashboardData d) {
    // User-resizable now (see ResizableDashboardBlock) — below ~260px the
    // 3-column layout would squeeze each amount into an unreadably narrow
    // slice, so it switches to a stacked label/value row per figure instead
    // of letting the 3-column Row degrade on its own.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Revenue Overview',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (compact)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      _revenueRowCompact('Today', d.revenueToday),
                      Divider(
                        height: 1,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      _revenueRowCompact('This Month', d.revenueMonth),
                      Divider(
                        height: 1,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      _revenueRowCompact('This Year', d.revenueYear),
                    ],
                  ),
                )
              else
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(child: _revenueCol('Today', d.revenueToday)),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      Expanded(
                        child: _revenueCol('This Month', d.revenueMonth),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      Expanded(child: _revenueCol('This Year', d.revenueYear)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _revenueCol(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary.withValues(alpha: 0.70),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmtRupee(amount),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueRowCompact(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primary.withValues(alpha: 0.65),
              letterSpacing: 0.5,
            ),
          ),
          Text(
            _fmtRupee(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reception performance table ────────────────────────────────────────

  Widget _buildReceptionTable(DashboardData d) {
    // User-resizable now (see ResizableDashboardBlock) — below ~260px the
    // "Walk-ins" column has no room left once Receptionist/Net take their
    // share, so it drops out instead of squeezing into unreadable digits.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  'Reception — Today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Expanded(flex: 3, child: _TH('Receptionist')),
                    if (!compact)
                      const Expanded(
                        flex: 1,
                        child: _TH('Walk-ins', right: true),
                      ),
                    const Expanded(flex: 2, child: _TH('Net', right: true)),
                    // Web pull 2026-09-30 — the "Detail" column
                    // (`index.blade.php` "Reception — Today" table, gated by
                    // `patient_view|report_view|opd_reports_view`) was missing
                    // entirely; was Receptionist/Walk-ins/Net only.
                    if (_canCollection(PermissionService.instance))
                      const Expanded(
                        flex: 2,
                        child: _TH('Detail', right: true),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: d.receptionists.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: Color(0xFFE2E8F0),
                  indent: 16,
                ),
                itemBuilder: (_, i) =>
                    _receptionRow(d.receptionists[i], compact: compact),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _receptionRow(ReceptionistStat r, {required bool compact}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  child: Text(
                    r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Expanded(
              flex: 1,
              child: Text(
                '${r.todayCount}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtRupee(r.todayNet),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
          if (_canCollection(PermissionService.instance))
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    appRoute(
                      PermissionGuard(
                        allowed: _canCollection,
                        // Web hardcodes today's date for this specific link
                        // (`index.blade.php`'s Reception table), regardless of
                        // any other date range the admin might be viewing
                        // elsewhere on this dashboard.
                        child: AdminCollectionDetailScreen(
                          user: widget.user,
                          hospital: widget.hospital,
                          receptionId: r.id,
                          receptionName: r.name,
                          start: DateTime.now(),
                          end: DateTime.now(),
                        ),
                      ),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  // Web's `money()` helper never compacts (always full, comma-grouped
  // figures — `index.blade.php` calls `money($revenueToday ?? 0, 0)`
  // everywhere on this dashboard) — this used to go through
  // `formatMoneyCompact` ("10k") instead of the exact value ("9,500") web
  // actually shows for Total/Today Collection and every other money figure
  // on this screen.
  String _fmtRupee(double amount) =>
      formatMoney(amount, widget.hospital.currencySymbol);

  String _fmtWait(int minutes) {
    if (minutes < 1) return 'Just in';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Color _waitColor(int minutes, WaitThresholds t) {
    if (minutes < t.rGreen) return AppColors.waitGreen;
    if (minutes < t.rOrange) return AppColors.waitOrange;
    return AppColors.waitRed;
  }
}

// ── Receptionist "Today Added Patients" widget ─────────────────────────────
// Mirrors web's receptionist-dashboard "Today Added Patients" table.
// Tablet adaptation: check-in opens as a dialog (matching this app's
// existing PatientCheckinScreen dialog convention) instead of mobile's
// full-screen push.
// See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §9 / FIX_PLAN TASK 5.1.
// Web pull 2026-10-07 — the OT-appointments merge/tab was removed here:
// receptionist lost `ot_appointment_view` to the new dedicated
// `ot_appointment` role, which gets its own desk panel instead
// (see OtAppointmentDeskHomePanel in widgets/ot/ot_appointment_desk_home_panel.dart).

class _TodayPatientsWidget extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final void Function(String railId) onNavigate;

  const _TodayPatientsWidget({
    super.key,
    required this.user,
    required this.hospital,
    required this.onNavigate,
  });

  @override
  State<_TodayPatientsWidget> createState() => _TodayPatientsWidgetState();
}

enum _TodayTab { walkin, phone, status }

class _TodayPatientsWidgetState extends State<_TodayPatientsWidget> {
  TodayPatientsData? _data;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  _TodayTab _activeTab = _TodayTab.walkin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Public entry point for the parent dashboard to poke this widget's own
  /// reload — see [_DashboardScreenState._todayPatientsKey]'s doc comment.
  Future<void> refresh() => _load(searchContact: _searchCtrl.text.trim());

  Future<void> _load({String searchContact = ''}) async {
    if (_data == null) setState(() => _loading = true);
    try {
      final data = await DashboardService.instance.fetchTodayPatients(
        searchContact: searchContact,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(searchContact: v.trim()),
    );
  }

  Future<void> _openCheckIn(Patient p) async {
    await showDialog<void>(
      context: context,
      builder: (dCtx) => PatientCheckinScreen(
        user: widget.user,
        hospital: widget.hospital,
        patient: p,
        onCancel: () => Navigator.pop(dCtx),
        onDone: (updated) {
          Navigator.pop(dCtx);
          _load(searchContact: _searchCtrl.text.trim());
          Navigator.of(context, rootNavigator: true).push(
            appRoute(
              OpdBillScreen(
                user: widget.user,
                hospital: widget.hospital,
                patient: updated,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPrint(Patient p) {
    Navigator.of(context, rootNavigator: true).push(
      appRoute(
        OpdBillScreen(user: widget.user, hospital: widget.hospital, patient: p),
      ),
    );
  }

  // ── Tab filter (web pull 2026-10-07 — OT pill removed: receptionist lost
  // ot_appointment_view, so this widget no longer merges OT appointments in
  // at all; now just Walk-in/Phone/Status, pure client-side show/hide of
  // this same already-loaded `_data.rows`, no re-fetch) ───────────────────

  // Previously re-derived from `type`/`isOt` alone, which omitted the
  // done/past-primary exclusion web applies to Walk-in (so a patient who'd
  // finished primary+secondary — or entered the OT pipeline — kept showing
  // in Walk-in here, and a phone patient who'd entered the OT pipeline
  // dropped out of Phone, since web's Phone tab is unconditional on
  // status). The server already computes the exact grouping rule
  // (`tap_groups`, mirrors receptionist-today-patients-table.blade.php) —
  // use it directly, same as `_statusPatients` below already does, instead
  // of re-deriving a second, drifted copy of the same rule.
  List<Patient> get _walkinPatients => (_data?.rows ?? const [])
      .where((r) => !r.isOt && r.patient!.tapGroups.contains('walkin'))
      .map((r) => r.patient!)
      .toList();
  List<Patient> get _phonePatients => (_data?.rows ?? const [])
      .where((r) => !r.isOt && r.patient!.tapGroups.contains('phone'))
      .map((r) => r.patient!)
      .toList();
  // Web pull 2026-09-28 — "Patient Status" 4th tab: patients who have moved
  // past the Primary Exam stage, regardless of walk-in/phone origin. Server
  // already computed this exact grouping (`tap_groups`), matching
  // receptionist-today-patients-table.blade.php's split rule.
  List<Patient> get _statusPatients => (_data?.rows ?? const [])
      .where((r) => !r.isOt && r.patient!.tapGroups.contains('status'))
      .map((r) => r.patient!)
      .toList();

  @override
  Widget build(BuildContext context) {
    final rows = _data?.rows ?? const <TodayPatientRow>[];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Text(
                  'Today Added Patients',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 200,
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    // Client report (2026-10-07): TextInputType.phone forced
                    // the numeric keypad, which made searching by name
                    // impossible to even type — the backend already matches
                    // name too now. Plain text keyboard.
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search by name or mobile...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      prefixIconConstraints: const BoxConstraints(minWidth: 30),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _tabPill('Walk-in', _walkinPatients.length, _TodayTab.walkin),
                const SizedBox(width: 8),
                _tabPill('Phone', _phonePatients.length, _TodayTab.phone),
                const SizedBox(width: 8),
                _tabPill('Status', _statusPatients.length, _TodayTab.status),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildActiveTable(),
            ),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int count, _TodayTab tab) {
    final active = _activeTab == tab;
    return PressScaleWrapper(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table (tablet: real table, matching web's # | MRD | Patient |
  // City/Age | Contact | Doctor | Dr Index | Status | Wait | Action —
  // identical across all 3 tabs; the OT tab repurposes Wait → a "Walk-In"
  // convert button and Action → an edit icon, matching web exactly) ────────

  static const _columns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('MRD', 96),
    ScaledTableColumn('PATIENT', 170),
    ScaledTableColumn('CITY/AGE', 120),
    ScaledTableColumn('CONTACT', 120),
    ScaledTableColumn('DOCTOR', 130),
    ScaledTableColumn('DR INDEX', 96),
    ScaledTableColumn('STATUS', 140),
    ScaledTableColumn('WAIT', 110),
    ScaledTableColumn('ACTION', 64, headerAlign: TextAlign.center),
  ];

  // Web pull 2026-09-28 — the Status tab drops the WAIT column entirely
  // (`@unless($tapStatusMode)` in receptionist-today-patients-table.blade.php)
  // since "time waiting in queue" doesn't apply once a patient has moved
  // past Primary Exam into counselling/account/ward/OT.
  static const _statusColumns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('MRD', 96),
    ScaledTableColumn('PATIENT', 170),
    ScaledTableColumn('CITY/AGE', 120),
    ScaledTableColumn('CONTACT', 120),
    ScaledTableColumn('DOCTOR', 130),
    ScaledTableColumn('DR INDEX', 96),
    ScaledTableColumn('STATUS', 150),
    ScaledTableColumn('ACTION', 64, headerAlign: TextAlign.center),
  ];

  Widget _buildActiveTable() {
    switch (_activeTab) {
      case _TodayTab.walkin:
        final items = _walkinPatients;
        return ScaledDataTable(
          columns: _columns,
          rows: List.generate(items.length, (i) => _patientCells(items[i], i)),
          emptyMessage: 'No walk-in patients today.',
        );
      case _TodayTab.phone:
        final items = _phonePatients;
        return ScaledDataTable(
          columns: _columns,
          rows: List.generate(items.length, (i) => _patientCells(items[i], i)),
          emptyMessage: 'No phone appointments today.',
        );
      case _TodayTab.status:
        final items = _statusPatients;
        return ScaledDataTable(
          columns: _statusColumns,
          rows: List.generate(
            items.length,
            (i) => _statusPatientCells(items[i], i),
          ),
          emptyMessage: 'No patients past Primary Exam yet.',
        );
    }
  }

  List<Widget> _patientCells(Patient p, int i) {
    final wait = _waitMinutes(p);
    final waitColor = _waitColor4(wait, _data!.thresholds);
    final isPhoneNotCheckedIn = p.type == 'phone' && p.checkedInAt == null;
    return [
      Text(
        '${i + 1}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.patientCode,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      Text(
        p.fullName.isNotEmpty ? p.fullName : '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        '${p.location?.city ?? '—'} / ${p.age ?? '—'}',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.contactNo ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.doctor?.name ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        _drIndex(p),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(p).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            _statusLabel(p),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _statusColor(p),
            ),
          ),
        ),
      ),
      p.secondaryDoneAt != null
          ? const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.teal,
            )
          : isPhoneNotCheckedIn
          ? Align(
              alignment: Alignment.centerLeft,
              child: TableLabelAction(
                label: 'Check In',
                icon: Icons.how_to_reg_rounded,
                tone: TableLabelTone.positive,
                onTap: () => _openCheckIn(p),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: waitColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _fmtWaitLocal(wait),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: waitColor,
                  ),
                ),
              ),
            ),
      p.secondaryDoneAt != null
          ? const SizedBox.shrink()
          : TableIconAction(
              icon: Icons.print_outlined,
              tooltip: 'Print',
              kind: TableActionKind.print,
              onTap: () => _openPrint(p),
            ),
    ];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _drIndex(Patient p) {
    if (p.doctorPatientNo == null) return '—';
    final n = p.doctorPatientNo!.toString().padLeft(3, '0');
    final prefix = p.doctor?.doctorPrefix;
    return (prefix != null && prefix.isNotEmpty) ? '$prefix-$n' : '#$n';
  }

  String _statusLabel(Patient p) {
    if (p.secondaryDoneAt != null) return 'Done';
    if (p.primaryDoneAt != null) return 'Primary Done';
    if (p.type == 'phone' && p.checkedInAt == null) return 'Not Checked In';
    return 'Waiting';
  }

  Color _statusColor(Patient p) {
    if (p.secondaryDoneAt != null) return AppColors.teal;
    if (p.primaryDoneAt != null) return AppColors.primary;
    if (p.type == 'phone' && p.checkedInAt == null)
      return AppColors.textSecondary;
    return AppColors.orange;
  }

  int _waitMinutes(Patient p) {
    final ref = p.checkedInAt ?? p.createdAt;
    if (ref == null) return 0;
    return DateTime.now().difference(ref).inMinutes.clamp(0, 99999);
  }

  // 4-tier wait color (green/orange/red/fire) — matches web's wait-fire tier
  // beyond the red threshold, which the shared 3-tier `_waitColor` above
  // (Primary Queue widget) doesn't have.
  Color _waitColor4(int minutes, TodayPatientsThresholds t) {
    if (minutes < t.rGreen) return AppColors.waitGreen;
    if (minutes < t.rOrange) return AppColors.waitOrange;
    if (minutes < t.rRed) return AppColors.waitRed;
    return AppColors.redDark;
  }

  String _fmtWaitLocal(int minutes) {
    if (minutes < 1) return 'Just in';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  // ── Status tab cells (web pull 2026-09-28) ──────────────────────────────
  // Reuses the server-computed `status_label`/tone (Patient::workflowStage(),
  // already remapped to match receptionist-today-patients-rows.blade.php)
  // instead of the simplified 4-state `_statusLabel`/`_statusColor` above,
  // which the other 3 tabs use for their own STATUS column.

  Color _toneColor(String? tone) => switch (tone) {
    'warning' => AppColors.orange,
    'info' => AppColors.blue,
    'purple' => AppColors.purple,
    'teal' => AppColors.teal,
    'success' => AppColors.green,
    'danger' => AppColors.red,
    'primary' => AppColors.primary,
    _ => AppColors.textSecondary,
  };

  List<Widget> _statusPatientCells(Patient p, int i) {
    final tone = _toneColor(p.statusTone);
    return [
      Text(
        '${i + 1}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.patientCode,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      Text(
        p.fullName.isNotEmpty ? p.fullName : '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        '${p.location?.city ?? '—'} / ${p.age ?? '—'}',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.contactNo ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.doctor?.name ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        _drIndex(p),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                p.statusLabel ?? '—',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ),
          // Web pull 2026-09-29 — `workflowStage()`'s secondary line (e.g.
          // "Payment pending", "In ward", "Dilated"), shown under the badge.
          if (p.statusSub != null && p.statusSub!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                p.statusSub!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
      p.secondaryDoneAt != null
          ? const SizedBox.shrink()
          : TableIconAction(
              icon: Icons.print_outlined,
              tooltip: 'Print',
              kind: TableActionKind.print,
              onTap: () => _openPrint(p),
            ),
    ];
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
      ),
    );
  }
}
