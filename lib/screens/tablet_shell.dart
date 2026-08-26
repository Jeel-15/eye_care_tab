import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/coming_soon_pane.dart';
import '../widgets/secret_tap_area.dart';
import 'clinical_queue_screen.dart';
import 'dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'doctor_ot_list_screen.dart';
import 'foc_screen.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // null = follow width breakpoint automatically; set once the user taps the
  // rail's manual expand/collapse toggle, and sticks until toggled again.
  bool? _expandOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    if (!await OnboardingService.instance.shouldShow()) return;
    final slides = OnboardingService.instance.slidesForCurrentUser(roleSlug: widget.user.role?.slug);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _silentRefresh();
  }

  Future<void> _silentRefresh() async {
    try {
      final user = await AuthService.instance.refreshSession();
      if (!mounted) return;
      if (user == null) {
        PermissionService.instance.clear();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      PermissionService.instance.load(user.role);
      final visibleIds = _visibleEntries().map((e) => e.id).toSet();
      if (!visibleIds.contains(_selected)) {
        setState(() => _selected = 'dashboard');
      } else {
        setState(() {});
      }
    } catch (_) {
      // Network error — keep current state, don't disrupt user
    }
  }

  bool get _isDoctor => widget.user.role?.slug == 'doctor';
  bool get _isAdmin => widget.user.role?.slug == 'hospital_admin';

  Future<void> _logout() async {
    PermissionService.instance.clear();
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ── Rail item groups (mirrors app_drawer.dart + home_screen.dart) ────────

  List<_RailGroup> _visibleGroups() {
    final p = PermissionService.instance;

    return [
      _RailGroup(null, [
        const _RailEntry('dashboard', Icons.grid_view_rounded, 'Dashboard'),
      ]),
      _RailGroup('OPD', [
        if (p.can(Perm.opdPatientView)) ...[
          const _RailEntry('patients', Icons.people_alt_rounded, 'Patients'),
          const _RailEntry('share_history', Icons.share_rounded, 'Share History'),
        ],
        if (p.can(Perm.opdFocCreate) || p.can(Perm.opdFocAccept))
          const _RailEntry('foc', Icons.receipt_long_rounded, 'FOC Requests'),
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
        if (p.can(Perm.otLensRecord) || p.can(Perm.otLensImplant) || p.can(Perm.otPatientList) || p.can(Perm.otSurgeryReady) || p.can(Perm.otSurgeryRecord))
          const _RailEntry('ot_assistant', Icons.handyman_rounded, 'Assistant Dashboard'),
        if (p.can(Perm.otBillingManage))
          const _RailEntry('ot_discharge', Icons.receipt_long_rounded, 'Discharge & Invoices'),
      ]),
      _RailGroup('Reports', [
        if (!_isDoctor && p.can(Perm.reportsView))
          const _RailEntry('reports', Icons.bar_chart_rounded, 'Reports'),
        // Was reachable only via a dashboard quick-action tile — web lists
        // OPD Reports and OT Reports as sibling sidebar items, so this rail
        // needs its own entry too. Gated the same way 'reports' above is.
        if (!_isDoctor && p.can(Perm.reportsView) && p.canModule('ot'))
          const _RailEntry('ot_reports', Icons.insights_rounded, 'OT Reports'),
      ]),
      _RailGroup('Medicines', [
        if (p.can(Perm.masterMedicines)) ...[
          const _RailEntry('medicines', Icons.local_pharmacy_rounded, 'Medicines'),
          const _RailEntry('medicine_groups', Icons.folder_special_rounded, 'Medicine Groups'),
          const _RailEntry('medicine_types', Icons.label_rounded, 'Medicine Types'),
          const _RailEntry('medicine_categories', Icons.folder_rounded, 'Medicine Categories'),
          const _RailEntry('route_admin', Icons.alt_route_rounded, 'Route of Admin.'),
          const _RailEntry('dosages', Icons.science_rounded, 'Dosages'),
        ],
      ]),
      _RailGroup('Config', [
        if (p.can(Perm.masterCaseTypes) || p.can(Perm.masterEyeExam) || p.can(Perm.masterLocations))
          const _RailEntry('masters', Icons.tune_rounded, 'Masters'),
        if (!_isDoctor && p.can(Perm.settingsHospital))
          const _RailEntry('settings', Icons.settings_outlined, 'Settings'),
        if (!_isDoctor && p.can(Perm.masterRoles))
          const _RailEntry('roles', Icons.admin_panel_settings_rounded, 'Roles & Permissions'),
        if (!_isDoctor && (p.can(Perm.masterDoctors) || p.can(Perm.masterReceptions) || p.can(Perm.masterOtStaff)))
          const _RailEntry('users', Icons.manage_accounts_rounded, 'Users'),
      ]),
    ].where((g) => g.entries.isNotEmpty).toList();
  }

  List<_RailEntry> _visibleEntries() => _visibleGroups().expand((g) => g.entries).toList();

  Widget _buildContent(String id) {
    switch (id) {
      case 'dashboard':
        return _isDoctor
            ? DoctorDashboardScreen(user: widget.user, hospital: widget.hospital, onNavigate: (id) => setState(() => _selected = id))
            : DashboardScreen(user: widget.user, hospital: widget.hospital, onNavigate: (id) => setState(() => _selected = id));
      case 'doctor_ot_list':
        return const DoctorOtListScreen();
      case 'patients':
        return PatientsScreen(user: widget.user, hospital: widget.hospital);
      case 'queue':
        return ClinicalQueueScreen(user: widget.user, hospital: widget.hospital);
      case 'masters':
        return const MastersScreen();
      case 'ot_appointments':
        return const OtAppointmentListScreen();
      case 'ot_dashboard':
        return OtHomeDashboardScreen(onNavigate: (id) => setState(() => _selected = id));
      case 'ot_counsellor':
        return const OtCounsellorDashboardScreen();
      case 'ot_ward':
        return const OtWardQueueScreen();
      case 'ot_assistant':
        return OtAssistantDashboardScreen(user: widget.user);
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
      case 'medicine_types':
        return const MedicinesScreen(initialTab: MedicinesTab.types);
      case 'medicine_categories':
        return const MedicinesScreen(initialTab: MedicinesTab.categories);
      case 'route_admin':
        return const MedicinesScreen(initialTab: MedicinesTab.routeAdmin);
      case 'dosages':
        return const MedicinesScreen(initialTab: MedicinesTab.dosages);
      case 'reports':
        return ReportsScreen(user: widget.user, hospital: widget.hospital);
      case 'users':
        return UsersScreen(user: widget.user, hospital: widget.hospital);
      case 'roles':
        return RolesScreen(user: widget.user, hospital: widget.hospital);
      case 'foc':
        return FocScreen(user: widget.user, hospital: widget.hospital);
      case 'settings':
        return SettingsScreen(user: widget.user, hospital: widget.hospital);
      case 'profile':
        return ProfileScreen(user: widget.user, hospital: widget.hospital);
      case 'share_history':
        return ShareHistoryScreen(user: widget.user, hospital: widget.hospital);
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
            return _buildCompactShell();
          }
          final extended = _expandOverride ?? AppBreakpoints.isExpanded(width);
          return _buildRailShell(extended: extended);
        },
      ),
    );
  }

  // ── Expanded / Medium — persistent rail ───────────────────────────────────

  Widget _buildRailShell({required bool extended}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _TabletRail(
            extended: extended,
            onToggleExpand: () => setState(() => _expandOverride = !extended),
            groups: _visibleGroups(),
            selected: _selected,
            user: widget.user,
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
      ),
      drawer: Drawer(
        width: TabletSpacing.railWidthExpanded,
        child: _TabletRail(
          extended: true,
          groups: _visibleGroups(),
          selected: _selected,
          user: widget.user,
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
  const _RailGroup(this.label, this.entries);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ── Rail widget ──────────────────────────────────────────────────────────

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
            if (onToggleExpand != null) _buildToggle(),
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

  Widget _buildToggle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: extended ? 10 : 0),
      child: Align(
        alignment: extended ? Alignment.centerRight : Alignment.center,
        child: Tooltip(
          message: extended ? 'Collapse sidebar' : 'Expand sidebar',
          child: Material(
            color: AppColors.primaryA06,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(extended ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
              ),
            ),
          ),
        ),
      ),
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

  Widget _initialsBadge(String initials) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      );

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
          if (!isAdmin)
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

  String _userInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
