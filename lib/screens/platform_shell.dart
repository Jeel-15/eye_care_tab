import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/platform_admin_models.dart';
import '../services/platform_auth_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/coming_soon_pane.dart';
import 'login_screen.dart';
import 'platform_audit_logs_screen.dart';
import 'platform_billing_screen.dart';
import 'platform_dashboard_screen.dart';
import 'platform_hospitals_screen.dart';
import 'platform_location_master_screen.dart';
import 'platform_medicine_master_screen.dart';
import 'platform_notifications_screen.dart';
import 'platform_plans_screen.dart';
import 'platform_profile_screen.dart';
import 'platform_settings_screen.dart';

/// Tablet Platform Super Admin shell — mirrors [TabletShell]'s grouped
/// NavigationRail pattern (same `_TabletRail`/breakpoint behavior) rather
/// than mobile's bottom-nav + drawer combo, for the same reasons: this is a
/// permanent workspace, not a quick-glance phone app. Kept as its own
/// private rail implementation (not shared with TabletShell) since the two
/// consoles have entirely separate auth/session models (PlatformAdmin vs
/// UserInfo/HospitalInfo) and no permission-gating — every super admin sees
/// every destination, matching mobile's own ungated drawer.
class PlatformShell extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformShell({super.key, required this.admin});

  @override
  State<PlatformShell> createState() => _PlatformShellState();
}

class _PlatformShellState extends State<PlatformShell> {
  String _selected = 'dashboard';
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // null = follow width breakpoint automatically; set once the user taps the
  // rail's manual expand/collapse toggle, and sticks until toggled again.
  bool? _expandOverride;

  Future<void> _logout() async {
    await PlatformAuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  static const _groups = [
    _RailGroup(null, [
      _RailEntry('dashboard', Icons.grid_view_rounded, 'Dashboard'),
    ]),
    _RailGroup('Tenants', [
      _RailEntry('hospitals', Icons.local_hospital_rounded, 'Hospitals'),
      _RailEntry('billing', Icons.receipt_long_rounded, 'Billing'),
    ]),
    _RailGroup('Oversight', [
      _RailEntry('audit_logs', Icons.history_rounded, 'Audit Logs'),
      _RailEntry('notifications', Icons.campaign_rounded, 'Notifications'),
    ]),
    _RailGroup('Platform Masters', [
      _RailEntry('plans', Icons.workspace_premium_rounded, 'Plans'),
      _RailEntry('location_master', Icons.public_rounded, 'Location Master'),
      _RailEntry('medicine_master', Icons.medication_rounded, 'Medicine Master'),
    ]),
    _RailGroup('System', [
      _RailEntry('settings', Icons.settings_rounded, 'Settings'),
    ]),
  ];

  static List<_RailEntry> get _allEntries => _groups.expand((g) => g.entries).toList();

  Widget _buildContent(String id) {
    switch (id) {
      case 'dashboard':
        return PlatformDashboardScreen(admin: widget.admin);
      case 'hospitals':
        return PlatformHospitalsScreen(admin: widget.admin);
      case 'billing':
        return PlatformBillingScreen(admin: widget.admin);
      case 'plans':
        return PlatformPlansScreen(admin: widget.admin);
      case 'location_master':
        return PlatformLocationMasterScreen(admin: widget.admin);
      case 'medicine_master':
        return PlatformMedicineMasterScreen(admin: widget.admin);
      case 'audit_logs':
        return PlatformAuditLogsScreen(admin: widget.admin);
      case 'notifications':
        return PlatformNotificationsScreen(admin: widget.admin);
      case 'settings':
        return PlatformSettingsScreen(admin: widget.admin);
      case 'profile':
        return PlatformProfileScreen(admin: widget.admin);
      default:
        final entry = _allEntries.where((e) => e.id == id).firstOrNull;
        return ComingSoonPane(icon: entry?.icon ?? Icons.dashboard_customize_rounded, title: entry?.label ?? id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selected == 'dashboard',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = 'dashboard');
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (AppBreakpoints.isCompact(width)) return _buildCompactShell();
        final extended = _expandOverride ?? AppBreakpoints.isExpanded(width);
        return _buildRailShell(extended: extended);
      }),
    );
  }

  Widget _buildRailShell({required bool extended}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _PlatformRail(
            extended: extended,
            onToggleExpand: () => setState(() => _expandOverride = !extended),
            groups: _groups,
            selected: _selected,
            admin: widget.admin,
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
                  child: KeyedSubtree(key: ValueKey(_selected), child: _buildContent(_selected)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactShell() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Platform Console'),
      ),
      drawer: Drawer(
        width: TabletSpacing.railWidthExpanded,
        child: _PlatformRail(
          extended: true,
          groups: _groups,
          selected: _selected,
          admin: widget.admin,
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

class _PlatformRail extends StatelessWidget {
  final bool extended;
  final List<_RailGroup> groups;
  final String selected;
  final PlatformAdmin admin;
  final void Function(String id) onSelect;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  /// Manual expand/collapse toggle — null when the rail is shown inside a
  /// Drawer (compact layout), where it's always fully expanded and there's
  /// nothing to toggle.
  final VoidCallback? onToggleExpand;

  const _PlatformRail({
    required this.extended,
    required this.groups,
    required this.selected,
    required this.admin,
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
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: AppColors.primaryA08))),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (onToggleExpand != null) _buildToggle(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  for (final group in groups) ...[
                    if (group.label != null) extended ? _sectionLabel(group.label!) : _collapsedGroupDivider(),
                    for (final entry in group.entries) _railTile(entry, active: selected == entry.id, onTap: () => onSelect(entry.id)),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
    if (onToggleExpand == null) return rail;
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

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: extended
          ? Row(children: [
              _iconBadge(),
              const SizedBox(width: 12),
              const Expanded(child: Text('SUPER ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
            ])
          : Center(child: _iconBadge()),
    );
  }

  Widget _iconBadge() => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
      );

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.textSecondary.withValues(alpha: 0.65))),
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
                ? Row(children: [
                    Icon(entry.icon, size: 20, color: active ? AppColors.primary : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.primary : AppColors.textPrimary))),
                  ])
                : Center(child: Icon(entry.icon, size: 22, color: active ? AppColors.primary : AppColors.textSecondary)),
          ),
        ),
      ),
    );
    return extended ? tile : Tooltip(message: entry.label, child: tile);
  }

  Widget _buildFooter() {
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
                    ? Row(children: [
                        _smallAvatar(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(admin.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            Text(admin.role.replaceAll('_', ' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ]),
                        ),
                      ])
                    : Center(child: _smallAvatar()),
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
                    ? Row(children: [
                        Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                        const SizedBox(width: 10),
                        Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.red)),
                      ])
                    : Center(child: Icon(Icons.logout_rounded, size: 20, color: AppColors.red)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallAvatar() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppColors.primaryA12, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(admin.initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
      );
}
