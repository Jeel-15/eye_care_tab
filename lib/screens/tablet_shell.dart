import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../services/patient_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/coming_soon_pane.dart';
import '../widgets/dash_tab_switch.dart';
import '../widgets/permission_guard.dart';
import '../widgets/secret_tap_area.dart';
import '../utils/refreshable.dart';
import 'clinical_queue_screen.dart';
import 'dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_ot_list_screen.dart';
// FOC Requests disabled at client's request — see foc_screen.dart.
// import 'foc_screen.dart';
import 'login_screen.dart';
import 'masters_screen.dart';
import 'medicines_screen.dart';
import 'onboarding_screen.dart';
import 'ot_appointment_list_screen.dart';
import 'ot_home_dashboard_screen.dart';
import 'ot_counsellor_dashboard_screen.dart';
import 'ot_accountant_dashboard_screen.dart';
import 'ot_discharge_dashboard_screen.dart';
import 'ot_reports_screen.dart';
import 'ot_assistant_dashboard_screen.dart';
import 'ot_ward_queue_screen.dart';
import 'patients_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'roles_screen.dart';
import 'settings_screen.dart';
import 'share_history_screen.dart';
import 'users_screen.dart';
import '../utils/medicines_tab.dart';
import '../widgets/receptionist_quick_bubble.dart';
import '../widgets/retry_network_image.dart';

/// Tablet app shell — persistent left NavigationRail replacing mobile's
/// bottom-nav + drawer combo. See EYE_CARE_TAB_PRD.md §4.
class TabletShell extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const TabletShell({super.key, required this.user, required this.hospital});

  @override
  State<TabletShell> createState() => _TabletShellState();
}

class _TabletShellState extends State<TabletShell> with WidgetsBindingObserver {
  String _selected = 'dashboard';
  late UserInfo _user;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Reused across whichever rail entry is currently shown — lets
  // _silentRefresh() reach that screen's own reload method on app resume.
  // Only the small set of screens that implement Refreshable respond; all
  // others no-op safely (the `is` check below just fails).
  // See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 4.
  GlobalKey _contentKey = GlobalKey();
  // null = follow width breakpoint automatically; set once the user taps the
  // rail's manual expand/collapse toggle, and sticks until toggled again.
  bool? _expandOverride;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    receptionBubbleRefresh = () async {
      final contentState = _contentKey.currentState;
      if (contentState is Refreshable) await (contentState as Refreshable).refreshSilently();
    };
    WidgetsBinding.instance.addObserver(this);
    PermissionService.instance.addListener(_onPermissionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    if (!await OnboardingService.instance.shouldShow()) return;
    final slides = OnboardingService.instance.slidesForCurrentUser(roleSlug: _user.role?.slug);
    if (slides == null || !mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => OnboardingScreen(slides: slides, onDone: () => Navigator.of(context).pop()),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    if (receptionBubbleRefresh != null) receptionBubbleRefresh = null;
    PermissionService.instance.removeListener(_onPermissionsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Throttled + single-flight inside AuthService. refreshSession() routes a
    // lost session to login itself; a network error keeps current permissions.
    if (state == AppLifecycleState.resumed) {
      AuthService.instance.refreshMe(fromResume: true);
    }
  }

  /// Runs whenever PermissionService actually changes (resume, a newer
  /// X-Permissions-Version header, or a 403) — rebuilds rail + pane in place.
  void _onPermissionsChanged() {
    if (!mounted || !PermissionService.instance.isLoaded) return;
    final user = AuthService.instance.activeUser;
    if (user != null) {
      // Doctor and non-doctor build different widgets for the same ids;
      // a fresh key avoids reusing one GlobalKey across both types.
      if (_user.role?.slug != user.role?.slug) {
        _contentKey = GlobalKey();
        _selected = 'dashboard';
      }
      _user = user;
    }
    if (!_canShow(_selected)) _selected = 'dashboard';

    // Pane content is often const, so setState alone would not re-run the
    // screens' permission checks.
    setState(() {});
    rebuildPermissionSubtree(context);

    final contentState = _contentKey.currentState;
    if (contentState is Refreshable) (contentState as Refreshable).refreshSilently();
  }

  /// Whether pane [id] is still reachable with the current permissions.
  /// 'profile' and 'doctor_ot_list' are opened from the header / doctor
  /// dashboard rather than the rail, so they are checked separately.
  bool _canShow(String id) {
    final p = PermissionService.instance;
    switch (id) {
      case 'dashboard':
      case 'profile':
        return true;
      case 'doctor_ot_list':
        return p.canAny([Perm.opdExamSecondary, Perm.otPatientList, Perm.otSurgeryRecommend]);
      default:
        return _visibleEntries().any((e) => e.id == id);
    }
  }

  bool get _isDoctor => _user.role?.slug == 'doctor';
  bool get _isAdmin => _user.role?.slug == 'hospital_admin';

  Future<void> _logout() async {
    PermissionService.instance.clear();
    // Best-effort — don't let a stale patients cache linger for whichever
    // account logs in next on this device. See
    // ROLES_PERMISSIONS_DEEP_AUDIT_ROUND2.md Part B.
    await PatientService.instance.clearCache(
      PatientService.scopeFor(hospitalSlug: widget.hospital.slug, userId: _user.id),
    );
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Rail item groups (mirrors app_drawer.dart + home_screen.dart) ────────

  List<_RailGroup> _visibleGroups() {
    final p = PermissionService.instance;

    // Web doctor shell (hospital/layouts/app.blade.php's `.black-menu-bar`,
    // confirmed against the actual blade markup 2026-09-21): a top navbar
    // with exactly 4 items in this order — Dashboards | Diagnosis Master |
    // Medicine Master | History. Labels/order below match web verbatim,
    // including "Dashboards" (plural, doctor-only — every other role's
    // dashboard entry stays "Dashboard") and Medicine Master's exact
    // web copy/order (Dosage, Medicine Type, Medicine Category, Mode,
    // Medicines, Medicine Groups — web calls the route-of-admin field
    // "Mode" specifically in this menu, singular labels throughout,
    // NOT the same order/wording as the non-doctor "Medicines" section
    // below). Web's "Diagnosis Master" is itself a 2-level flyout
    // (C/O, KCO, H/O, O/E→10 sub-items, FUNDUS→2 sub-items, DIAGNOSIS,
    // ADVICE) but every one of those already lives together as tiles on
    // the existing Masters screen — kept as a single direct link here
    // rather than rebuilding a 2-level flyout for content that's one tap
    // away either way; better tablet UX, same destination/permissions.
    if (_isDoctor) {
      return [
        _RailGroup(null, [
          const _RailEntry('dashboard', Icons.grid_view_rounded, 'Dashboards'),
        ]),
        // Web gates both menus by @hasanypermission across all CRUD verbs
        // (view|add|edit|manage), not view-only — canFeature() mirrors that;
        // p.can(Perm.masterEyeExam)/(Perm.masterMedicines) would incorrectly
        // hide the menu for a role granted only add/edit/manage.
        if (p.canAccessEyeExamMasters)
          _RailGroup(null, [
            const _RailEntry('masters', Icons.remove_red_eye_rounded, 'Diagnosis Master'),
          ]),
        if (p.canFeature('master', 'medicine'))
          _RailGroup('Medicine Master', [
            const _RailEntry('dosages', Icons.science_rounded, 'Dosage'),
            const _RailEntry('medicine_types', Icons.label_rounded, 'Medicine Type'),
            const _RailEntry('medicine_categories', Icons.folder_rounded, 'Medicine Category'),
            const _RailEntry('route_admin', Icons.alt_route_rounded, 'Mode'),
            const _RailEntry('medicines', Icons.local_pharmacy_rounded, 'Medicines'),
            const _RailEntry('medicine_groups', Icons.folder_special_rounded, 'Medicine Groups'),
            const _RailEntry('ward_medicines', Icons.local_hospital_rounded, 'Ward Medicine'),
          ], icon: Icons.medication_rounded),
        if (p.can(Perm.opdExamHistory))
          _RailGroup(null, [
            const _RailEntry('share_history', Icons.history_rounded, 'History'),
          ]),
      ].where((g) => g.entries.isNotEmpty).toList();
    }

    return [
      _RailGroup(null, [
        const _RailEntry('dashboard', Icons.grid_view_rounded, 'Dashboard'),
      ]),
      _RailGroup('OPD', [
        // Patients: web gates by patient_view. Share History: exam_history.
        if (p.can(Perm.opdPatientView))
          const _RailEntry('patients', Icons.people_alt_rounded, 'Patients'),
        if (p.can(Perm.opdExamHistory))
          const _RailEntry('share_history', Icons.share_rounded, 'Share History'),
        // FOC Requests disabled at client's request — see foc_screen.dart.
        // if (p.can(Perm.opdFocCreate) || p.can(Perm.opdFocAccept))
        //   const _RailEntry('foc', Icons.receipt_long_rounded, 'FOC Requests'),
      ]),
      _RailGroup('Clinical', [
        if (p.can(Perm.opdExamPrimary) || p.can(Perm.opdExamSecondary))
          const _RailEntry('queue', Icons.queue_rounded, 'Queue Dashboard'),
      ]),
      _RailGroup('Department Hub (OT)', [
        if (p.can(Perm.otAppointmentView))
          const _RailEntry('ot_appointments', Icons.event_note_rounded, 'OT Appointments'),
        if (p.can(Perm.otCounsellingFill))
          const _RailEntry('ot_counsellor', Icons.support_agent_rounded, 'OT Counsellor'),
        if (p.can(Perm.otPaymentRecord))
          const _RailEntry('ot_billing', Icons.account_balance_wallet_rounded, 'Accountant / Billing'),
        if (p.can(Perm.otWardEntry))
          const _RailEntry('ot_ward', Icons.bed_rounded, 'Ward Management'),
        // Web has one merged "OT Assistant Dashboard" nav entry gated by
        // lens.record/lens.implant/surgery.ready/surgery.record combined —
        // no separate "Doctor Dashboard" (the old OT Doctor role's surgery
        // recording was absorbed into OT Assistant, see
        // ot_assistant_dashboard_screen.dart).
        // Matches web's $showAssistant exactly (4 keys — no otPatientList).
        if (p.can(Perm.otLensRecord) || p.can(Perm.otLensImplant) || p.can(Perm.otSurgeryReady) || p.can(Perm.otSurgeryRecord))
          const _RailEntry('ot_assistant', Icons.handyman_rounded, 'Assistant Dashboard'),
        // Matches web: ot_discharge_generate | ot_billing_manage | ot_bill_print | ot_certificate_print
        if (p.canAny([Perm.otDischargeGenerate, Perm.otBillingManage, Perm.otBillPrint, Perm.otCertificatePrint]))
          const _RailEntry('ot_discharge', Icons.receipt_long_rounded, 'Discharge & Invoices'),
      ]),
      _RailGroup('Reports', [
        // Web: OPD Reports = report_view|opd_reports_view; OT Reports = report_view.
        if (p.can(Perm.reportsView) || p.can(Perm.opdReportsView))
          const _RailEntry('reports', Icons.bar_chart_rounded, 'Reports'),
        if (p.can(Perm.reportsView) || p.can(Perm.otReportsView))
          const _RailEntry('ot_reports', Icons.insights_rounded, 'OT Reports'),
      ]),
      _RailGroup('Medicines', [
        if (p.canFeature('master', 'medicine')) ...[
          const _RailEntry('medicines', Icons.local_pharmacy_rounded, 'Medicines'),
          const _RailEntry('medicine_groups', Icons.folder_special_rounded, 'Medicine Groups'),
          const _RailEntry('ward_medicines', Icons.local_hospital_rounded, 'Ward Medicine'),
          const _RailEntry('medicine_types', Icons.label_rounded, 'Medicine Types'),
          const _RailEntry('medicine_categories', Icons.folder_rounded, 'Medicine Categories'),
          const _RailEntry('route_admin', Icons.alt_route_rounded, 'Route of Admin.'),
          const _RailEntry('dosages', Icons.science_rounded, 'Dosages'),
        ],
      ]),
      _RailGroup('Config', [
        if (p.canAccessMasters)
          const _RailEntry('masters', Icons.tune_rounded, 'Masters'),
        if (p.canFeature('setting', 'hospital'))
          const _RailEntry('settings', Icons.settings_outlined, 'Settings'),
        // Matches web's plain @haspermission('master.roles') — no doctor exclusion.
        if (p.canFeature('master', 'role'))
          const _RailEntry('roles', Icons.admin_panel_settings_rounded, 'Roles & Permissions'),
        if (p.canFeature('master', 'user_doctor') ||
            p.canFeature('master', 'user_reception') ||
            p.canFeature('master', 'user_ot_staff'))
          const _RailEntry('users', Icons.manage_accounts_rounded, 'Users'),
      ]),
    ].where((g) => g.entries.isNotEmpty).toList();
  }

  List<_RailEntry> _visibleEntries() => _visibleGroups().expand((g) => g.entries).toList();

  Widget _buildContent(String id) {
    switch (id) {
      case 'dashboard':
        return _isDoctor
            ? DoctorDashboardScreen(key: _contentKey, user: _user, hospital: widget.hospital, onNavigate: (id) => setState(() => _selected = id))
            : DashboardScreen(key: _contentKey, user: _user, hospital: widget.hospital, onNavigate: (id) => setState(() => _selected = id));
      case 'doctor_ot_list':
        return const DoctorOtListScreen();
      case 'patients':
        return PatientsScreen(key: _contentKey, user: _user, hospital: widget.hospital);
      case 'queue':
        return ClinicalQueueScreen(key: _contentKey, user: _user, hospital: widget.hospital);
      case 'masters':
        return MastersScreen(eyeExamOnly: _isDoctor);
      case 'ot_appointments':
        return const OtAppointmentListScreen();
      case 'ot_dashboard':
        return OtHomeDashboardScreen(onNavigate: (id) => setState(() => _selected = id));
      case 'ot_counsellor':
        return const OtCounsellorDashboardScreen();
      case 'ot_ward':
        return const OtWardQueueScreen();
      case 'ot_assistant':
        return OtAssistantDashboardScreen(user: _user);
      case 'ot_billing':
        return const OtAccountantDashboardScreen();
      case 'ot_discharge':
        return const OtDischargeDashboardScreen();
      case 'ot_reports':
        return const OtReportsScreen();
      case 'medicines':
        return const MedicinesScreen(initialTab: MedicinesTab.medicines);
      case 'medicine_groups':
        return const MedicinesScreen(initialTab: MedicinesTab.groups);
      case 'ward_medicines':
        return const MedicinesScreen(initialTab: MedicinesTab.ward);
      case 'medicine_types':
        return const MedicinesScreen(initialTab: MedicinesTab.types);
      case 'medicine_categories':
        return const MedicinesScreen(initialTab: MedicinesTab.categories);
      case 'route_admin':
        return const MedicinesScreen(initialTab: MedicinesTab.routeAdmin);
      case 'dosages':
        return const MedicinesScreen(initialTab: MedicinesTab.dosages);
      case 'reports':
        return ReportsScreen(key: _contentKey, user: _user, hospital: widget.hospital);
      case 'users':
        return UsersScreen(user: _user, hospital: widget.hospital);
      case 'roles':
        return RolesScreen(user: _user, hospital: widget.hospital);
      // FOC Requests disabled at client's request — see foc_screen.dart.
      // case 'foc':
      //   return FocScreen(user: widget.user, hospital: widget.hospital);
      case 'settings':
        return SettingsScreen(user: _user, hospital: widget.hospital);
      case 'profile':
        return ProfileScreen(user: _user, hospital: widget.hospital);
      case 'share_history':
        return ShareHistoryScreen(user: _user, hospital: widget.hospital);
      default:
        final entry = _visibleEntries().where((e) => e.id == id).firstOrNull;
        return ComingSoonPane(
          icon: entry?.icon ?? Icons.dashboard_customize_rounded,
          title: entry?.label ?? id,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selected == 'dashboard',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = 'dashboard');
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (AppBreakpoints.isCompact(width)) {
            // Doctor keeps the same drawer fallback as every other role at
            // narrow/portrait width — web has no defined responsive
            // behavior for its navbar at all (confirmed: it just wraps),
            // so there's no web pattern to mirror here; the existing
            // drawer is already the sensible tablet-appropriate fallback.
            return _buildCompactShell();
          }
          if (_isDoctor) {
            return _buildDoctorTopNavShell();
          }
          final extended = _expandOverride ?? AppBreakpoints.isExpanded(width);
          return _buildRailShell(extended: extended);
        },
      ),
    );
  }

  // ── Doctor-only — one top bar instead of the left rail ───────────────────

  Widget _buildDoctorTopNavShell() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DoctorTopBar(
              hospital: widget.hospital,
              user: _user,
              groups: _visibleGroups(),
              selected: _selected,
              onSelect: (id) => setState(() => _selected = id),
              onProfile: () => setState(() => _selected = 'profile'),
              onLogout: _logout,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  layoutBuilder: topAlignedSwitcherLayout,
                  child: KeyedSubtree(
                    key: ValueKey(_selected),
                    child: _buildContent(_selected),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expanded / Medium — persistent rail ───────────────────────────────────

  Widget _buildRailShell({required bool extended}) {
    final railWidth = extended ? TabletSpacing.railWidthExpanded : TabletSpacing.railWidthCollapsed;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Row(
        // Without this, the Row's default CrossAxisAlignment.center gives
        // the content Expanded a loose height and then vertically centers
        // whatever comes out — invisible when a screen's content happens to
        // fill the viewport, but any screen shorter than full height (e.g.
        // the doctor dashboard with few queue patients) floats in the
        // middle with a blank gap above it instead of starting at the top.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabletRail(
            extended: extended,
            onToggleExpand: () => setState(() => _expandOverride = !extended),
            groups: _visibleGroups(),
            selected: _selected,
            user: _user,
            hospital: widget.hospital,
            isAdmin: _isAdmin,
            onSelect: (id) => setState(() => _selected = id),
            onProfile: () => setState(() => _selected = 'profile'),
            onLogout: _logout,
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  layoutBuilder: topAlignedSwitcherLayout,
                  child: KeyedSubtree(
                    key: ValueKey(_selected),
                    child: _buildContent(_selected),
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: railWidth - 16,
            top: 0,
            bottom: 0,
            width: 32,
            child: Center(
              child: _RailEdgeToggle(
                extended: extended,
                onTap: () => setState(() => _expandOverride = !extended),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact / portrait — rail becomes a drawer ────────────────────────────

  Widget _buildCompactShell() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(widget.hospital.name),
        actions: [
          if (_isDoctor && _selected == 'dashboard') ...[
            const DoctorDashTabSwitch(),
            const SizedBox(width: 12),
          ],
        ],
      ),
      drawer: Drawer(
        width: TabletSpacing.railWidthExpanded,
        child: _TabletRail(
          extended: true,
          groups: _visibleGroups(),
          selected: _selected,
          user: _user,
          hospital: widget.hospital,
          isAdmin: _isAdmin,
          onSelect: (id) {
            Navigator.pop(context);
            setState(() => _selected = id);
          },
          onProfile: () {
            Navigator.pop(context);
            setState(() => _selected = 'profile');
          },
          onLogout: _logout,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: topAlignedSwitcherLayout,
          child: KeyedSubtree(key: ValueKey(_selected), child: _buildContent(_selected)),
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────

class _RailEntry {
  final String id;
  final IconData icon;
  final String label;
  const _RailEntry(this.id, this.icon, this.label);
}

class _RailGroup {
  final String? label;
  final List<_RailEntry> entries;
  // Only read by the doctor top bar's dropdown buttons (_DoctorTopBar) —
  // the left rail never shows a group-level icon, so this is null/unused
  // for every non-doctor group.
  final IconData? icon;
  const _RailGroup(this.label, this.entries, {this.icon});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ── Rail widget ──────────────────────────────────────────────────────────

class _RailEdgeToggle extends StatelessWidget {
  final bool extended;
  final VoidCallback onTap;

  const _RailEdgeToggle({required this.extended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: extended ? 'Collapse sidebar' : 'Expand sidebar',
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x33000000),
        shape: CircleBorder(side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(extended ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _TabletRail extends StatelessWidget {
  final bool extended;
  final List<_RailGroup> groups;
  final String selected;
  final UserInfo user;
  final HospitalInfo hospital;
  final bool isAdmin;
  final void Function(String id) onSelect;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  /// Manual expand/collapse toggle — null when the rail is shown inside a
  /// Drawer (compact layout), where it's always fully expanded and there's
  /// nothing to toggle.
  final VoidCallback? onToggleExpand;

  const _TabletRail({
    required this.extended,
    required this.groups,
    required this.selected,
    required this.user,
    required this.hospital,
    required this.isAdmin,
    required this.onSelect,
    required this.onProfile,
    required this.onLogout,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final width = extended ? TabletSpacing.railWidthExpanded : TabletSpacing.railWidthCollapsed;
    Widget rail = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.primaryA08)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  for (final group in groups) ...[
                    if (group.label != null) extended ? _sectionLabel(group.label!) : _collapsedGroupDivider(),
                    for (final entry in group.entries)
                      _railTile(entry, active: selected == entry.id, onTap: () => onSelect(entry.id)),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
    if (onToggleExpand == null) return rail;
    // Swipe right (left-to-right) to expand, swipe left to collapse — same
    // toggle the chevron button drives, just gesture-triggered.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 250 && !extended) onToggleExpand!();
        if (v < -250 && extended) onToggleExpand!();
      },
      child: rail,
    );
  }

  Widget _collapsedGroupDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        child: Divider(height: 1, thickness: 1, color: AppColors.primaryA12),
      );

  Widget _buildHeader(BuildContext context) {
    final initials = hospital.name.isNotEmpty
        ? hospital.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    // Hidden dev entry: tap the header 5x within 2s to reset onboarding —
    // same secret-gesture pattern as the login screen's logo, so it works
    // in release builds without ever being a visibly discoverable button.
    return SecretTapArea(
      onTrigger: () async {
        await OnboardingService.instance.resetForTesting();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding will show again on next app open.')));
      },
      child: Container(
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: extended
            ? Row(
                children: [
                  _initialsBadge(initials),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hospital.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ],
              )
            : Center(child: _initialsBadge(initials)),
      ),
    );
  }

  Widget _initialsBadge(String initials) => _HospitalLogoBadge(hospital: hospital, initials: initials);

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.textSecondary.withValues(alpha: 0.65),
          ),
        ),
      );

  Widget _railTile(_RailEntry entry, {required bool active, required VoidCallback onTap}) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? AppColors.primaryA12 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 0, vertical: 12),
            child: extended
                ? Row(
                    children: [
                      Icon(entry.icon, size: 20, color: active ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(entry.icon, size: 22, color: active ? AppColors.primary : AppColors.textSecondary),
                  ),
          ),
        ),
      ),
    );
    return extended ? tile : Tooltip(message: entry.label, child: tile);
  }

  Widget _buildFooter(BuildContext context) {
    final initials = _userInitials(user.name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: extended
                    ? Row(
                        children: [
                          _smallAvatar(initials),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                if (user.role != null)
                                  Text(user.role!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(child: _smallAvatar(initials)),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: extended
                    ? Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                          const SizedBox(width: 10),
                          Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red)),
                        ],
                      )
                    : Center(child: Icon(Icons.logout_rounded, size: 20, color: AppColors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallAvatar(String initials) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
      );

  String _userInitials(String name) => _initialsOf(name);
}

/// Shared by both the left rail's footer avatar and the doctor top-nav's
/// avatar menu — one implementation instead of two copies of the same
/// "first letter(s) of name" rule.
String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ── Hospital brand mark — shared by the left rail's header and the doctor
// top-nav's header. Mirrors web's rule: the bg-removed logo (with a
// white-silhouette tint) is only used when style is 'white' and a nobg
// version exists AND the badge sits on a dark background ([onDark]); on a
// light background the plain logo renders as-is (forcing it white would be
// invisible). 'original_blur' shows the plain logo in a frosted box;
// hospitals with no logo at all keep an initials avatar. ──────────────────

class _HospitalLogoBadge extends StatelessWidget {
  static const double _size = 38;

  final HospitalInfo hospital;
  final String initials;
  final bool onDark;

  const _HospitalLogoBadge({required this.hospital, required this.initials, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    // Read the live session cache, not the `hospital` constructor param —
    // that's a snapshot frozen at login/launch and never updates in-place
    // when a logo is changed elsewhere mid-session (same reasoning as
    // currentCurrencySymbol() in currency_format.dart).
    final live = AuthService.instance.cachedHospital;
    final logoUrl = live?.logoUrl ?? hospital.logoUrl;
    final logoNobgUrl = live?.logoNobgUrl ?? hospital.logoNobgUrl;
    final logoSidebarStyle = live?.logoSidebarStyle ?? hospital.logoSidebarStyle;

    final fallbackBg = onDark ? Colors.white.withValues(alpha: 0.18) : AppColors.primaryA10;
    final fallbackFg = onDark ? Colors.white : AppColors.primary;

    if (logoUrl.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(color: fallbackBg, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(initials, style: TextStyle(color: fallbackFg, fontWeight: FontWeight.w900, fontSize: 13)),
      );
    }

    final useNobg = onDark && logoSidebarStyle == 'white' && logoNobgUrl.isNotEmpty;
    final logoSrc = useNobg ? logoNobgUrl : logoUrl;
    final image = RetryNetworkImage(
      url: logoSrc,
      fit: BoxFit.contain,
      fallbackBuilder: (_) => Text(initials, style: TextStyle(color: fallbackFg, fontWeight: FontWeight.w900, fontSize: 13)),
    );

    if (logoSidebarStyle == 'original_blur') {
      return Container(
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: onDark ? Colors.white.withValues(alpha: 0.20) : AppColors.primaryA08, borderRadius: BorderRadius.circular(10)),
        child: image,
      );
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: useNobg
            ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcATop), child: image)
            : image,
      ),
    );
  }
}

// ── Doctor top bar — one navy row: hospital, page links, doctor menu.
// Replaces the old white hospital strip stacked on a separate navy menu,
// so the dashboard content gets that height back. Other roles keep the rail.

class _DoctorTopBar extends StatelessWidget {
  final HospitalInfo hospital;
  final UserInfo user;
  final List<_RailGroup> groups;
  final String selected;
  final void Function(String id) onSelect;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _DoctorTopBar({
    required this.hospital,
    required this.user,
    required this.groups,
    required this.selected,
    required this.onSelect,
    required this.onProfile,
    required this.onLogout,
  });

  bool _groupActive(_RailGroup g) => g.entries.any((e) => e.id == selected);

  @override
  Widget build(BuildContext context) {
    final initials = hospital.name.isNotEmpty
        ? hospital.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _HospitalLogoBadge(hospital: hospital, initials: initials, onDark: true),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            hospital.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final g in groups)
                        if (g.entries.length == 1 && g.label == null) _menuLink(g.entries.first) else _menuDropdown(g),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        if (selected == 'dashboard') ...[
          const DoctorDashTabSwitch(),
          const SizedBox(width: 16),
        ],
        _DoctorAvatarMenu(user: user, onDark: true, onProfile: onProfile, onLogout: onLogout),
      ]),
    );
  }

  Widget _menuLink(_RailEntry e) {
    final active = selected == e.id;
    return InkWell(
      onTap: () => onSelect(e.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? Colors.white : Colors.transparent, width: 3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(e.icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(e.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _menuDropdown(_RailGroup g) {
    final active = _groupActive(g);
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final e in g.entries)
          PopupMenuItem(
            value: e.id,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(e.icon, size: 16, color: selected == e.id ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(e.label, style: TextStyle(fontWeight: selected == e.id ? FontWeight.w800 : FontWeight.w600, color: selected == e.id ? AppColors.primary : AppColors.textPrimary)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? Colors.white : Colors.transparent, width: 3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(g.icon ?? Icons.menu_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(g.label!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
        ]),
      ),
    );
  }
}

class _DoctorAvatarMenu extends StatelessWidget {
  final UserInfo user;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final bool onDark;

  const _DoctorAvatarMenu({required this.user, required this.onProfile, required this.onLogout, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    // Mirrors web's user-dropdown exactly: My Profile, a divider, then
    // Logout — nothing else (no settings/notifications in this menu).
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: (v) {
        if (v == 'profile') onProfile();
        if (v == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('My Profile'),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'logout',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
            const SizedBox(width: 10),
            Text('Logout', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: onDark ? Colors.white : AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.person_rounded, color: onDark ? AppColors.primary : Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onDark ? Colors.white : AppColors.primary)),
                if (user.role != null)
                  Text(user.role!.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: onDark ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary, letterSpacing: 0.4)),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: onDark ? Colors.white : AppColors.textSecondary),
        ],
      ),
    );
  }
}
