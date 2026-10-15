import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../constants/app_colors.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/user_permission_policy.dart';
import '../services/masters_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_row_action.dart';
import '../widgets/table_tools_bar.dart';
import 'user_form_pane.dart';

/// Tablet Staff Users — web-parity table redesign (2026-09-21), matching
/// `hospital/users/index.blade.php` exactly: a colored panel header
/// ("Staff Users" + subtitle + a "N total" pill + "+ Add User"), Show
/// entries + search, a single full-page table (Name / Email / Role /
/// Contact / [Password, Hospital-Admin-only] / Status / Action) with
/// "Showing X to Y of Z entries" pagination — reusing the exact same
/// `OtPanelHeader`/`ScaledDataTable`/`TableToolsBar`/`TablePaginationFooter`
/// widgets every other OT/Patients/Reports table screen in this app
/// already uses, instead of a hand-duplicated copy of that scaffolding.
///
/// Replaces the previous Pattern A (list + detail split-pane): web has no
/// separate "view profile" page for a user — only Edit (which shows every
/// field, including doctor-specific ones) and Delete — so the split-pane's
/// `_UserDetailView` is gone; Add/Edit now open [UserFormPane] in a modal
/// `Dialog`, the same `showDialog` + `ConstrainedBox` pattern already used
/// for every other OT form (`OtAppointmentFormPane`, the counselling pane,
/// etc.) — mirrors web's own same-page modal for Add/Edit exactly.
///
/// **Password column, confirmed against web + the mobile API**: it is NOT
/// a live/current password — it's `original_password`, a plaintext
/// snapshot of whatever an admin last set (at creation, or via Edit's
/// password field) — never cleared when a user changes their own password
/// via self-service, so it can go stale. Web gates the ENTIRE column
/// (header + cell, not just the value) on `role.is_super` (Hospital Admin
/// only) — matched here via `PermissionService.instance.isSuper`, same
/// gate this screen's previous detail view already used correctly.
///
/// **Status pill is non-interactive on web** (only changeable via the Edit
/// form's status field) — but this app's tap-to-toggle behavior predates
/// this redesign and calls a real, permission-gated backend endpoint
/// (`toggleStatus`), not an invented one — kept as a deliberate
/// tablet-appropriate UX improvement, not a web-parity gap.
class UsersScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  /// Web parity: the dashboard's Doctor/Reception cards link to
  /// `hospital.users.index?role=doctor` etc., pre-filtered to just that
  /// role — not the full unfiltered list. Resolved to a role_id (the only
  /// filter the API accepts) once the roles list loads.
  final String? initialRoleSlug;

  const UsersScreen({super.key, required this.user, required this.hospital, this.initialRoleSlug});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  int _perPage = 25;

  final _p = PermissionService.instance;
  bool get _canAdd => _p.canAny(const [
        Perm.masterDoctorAdd,
        Perm.masterReceptionAdd,
        Perm.masterOtStaffAdd,
      ]);
  bool _canForUser(HospitalUserModel user, String action) {
    final role = user.role;
    if (role == null) return false;
    // The API refuses to manage super-role accounts for every viewer.
    if (role.isSuper) return false;
    final category = UserPermissionPolicy.categoryFor(
      userCategory: role.userCategory,
      roleSlug: role.slug,
      roleName: role.name,
    );
    return _p.can(UserPermissionPolicy.permissionKey(category, action));
  }

  List<HospitalUserModel> _users = [];
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  int? _roleFilterId;
  String? _roleFilterLabel;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoleSlug != null) {
      _applyInitialRoleFilter();
    } else {
      _load(refresh: true);
    }
  }

  /// Resolves the dashboard's role-slug link (e.g. "doctor") to a role_id —
  /// the only filter `fetchUsers` accepts — before the first load.
  Future<void> _applyInitialRoleFilter() async {
    try {
      final formData = await UserService.instance.fetchFormData();
      UserRole? role;
      for (final r in formData.roles) {
        if (r.slug == widget.initialRoleSlug) { role = r; break; }
      }
      final found = role;
      if (found != null && mounted) {
        setState(() { _roleFilterId = found.id; _roleFilterLabel = found.name; });
      }
    } catch (_) {
      // Filter is a convenience — fall through to an unfiltered list rather
      // than blocking the screen on a failed lookup.
    }
    if (mounted) _load(refresh: true);
  }

  void _clearRoleFilter() {
    setState(() { _roleFilterId = null; _roleFilterLabel = null; });
    _load(refresh: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    final page = refresh ? 1 : _currentPage;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await UserService.instance.fetchUsers(
        page: page,
        perPage: _perPage <= 0 ? 9999 : _perPage,
        search: _search.isEmpty ? null : _search,
        roleId: _roleFilterId,
      );
      if (!mounted) return;
      setState(() {
        _users = resp.users;
        _currentPage = resp.currentPage;
        _lastPage = resp.lastPage;
        _total = resp.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search != val) {
        setState(() => _search = val);
        _load(refresh: true);
      }
    });
  }

  void _onPerPageChanged(int v) {
    setState(() => _perPage = v);
    _load(refresh: true);
  }

  Future<void> _openAdd() async {
    await showPaneDialog<void>(
      context,
      wide: true,
      barrierDismissible: false,
      builder: (dCtx) => UserFormPane(
        key: const ValueKey('user_form_add'),
        mode: UserFormMode.add,
        onSaved: (saved) { Navigator.pop(dCtx); _onFormSaved(); },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openEdit(HospitalUserModel u) async {
    await showPaneDialog<void>(
      context,
      wide: true,
      barrierDismissible: false,
      builder: (dCtx) => UserFormPane(
        key: ValueKey('user_form_edit_${u.id}'),
        mode: UserFormMode.edit,
        editUser: u,
        onSaved: (saved) { Navigator.pop(dCtx); _onFormSaved(); },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  void _onFormSaved() {
    _load();
    showAppSnackBar(context, 'Saved.', isSuccess: true);
  }

  Future<void> _confirmDelete(HospitalUserModel u) async {
    final ok = await showAppConfirmDialog(context, title: 'Delete User', message: 'Delete "${u.name}"? This cannot be undone.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    try {
      await UserService.instance.deleteUser(u.id);
      // See user_form_pane.dart's save() for why this matters — an
      // inactive/deleted doctor must not keep showing up in other screens'
      // doctor dropdowns for the rest of the app session.
      MastersService.instance.clearCache();
      if (!mounted) return;
      showAppSnackBar(context, '"${u.name}" deleted successfully', isSuccess: true);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _toggleStatus(HospitalUserModel u) async {
    try {
      final newStatus = await UserService.instance.toggleStatus(u.id);
      MastersService.instance.clearCache();
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((x) => x.id == u.id);
        if (idx >= 0) {
          _users[idx] = HospitalUserModel(
            id: u.id, name: u.name, email: u.email, contact: u.contact, status: newStatus, role: u.role, focPermission: u.focPermission,
            lastLoginAt: u.lastLoginAt, doctorType: u.doctorType, doctorPrefix: u.doctorPrefix, registrationNo: u.registrationNo,
            experienceYears: u.experienceYears, signatureUrl: u.signatureUrl, profilePhotoUrl: u.profilePhotoUrl, originalPassword: u.originalPassword,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      _load();
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (!_p.canFeature('master', 'user_doctor') &&
        !_p.canFeature('master', 'user_reception') &&
        !_p.canFeature('master', 'user_ot_staff')) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primaryA25),
          const SizedBox(height: 16),
          Text('No Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryA50)),
          const SizedBox(height: 6),
          Text('You do not have permission to manage users.', style: TextStyle(fontSize: 13, color: AppColors.primaryA35)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          if (_roleFilterLabel != null) _buildRoleFilterChip(),
          TableToolsBar(
            perPage: _perPage,
            onPerPageChanged: _onPerPageChanged,
            searchCtrl: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            searchHint: 'Search by name, email or contact...',
          ),
          Expanded(child: _buildTableArea()),
          _buildPaginationFooter(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return OtPanelHeader(
      icon: Icons.badge_rounded,
      title: 'Staff Users',
      subtitle: 'Review team accounts and keep access information current.',
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Text('$_total TOTAL', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
        ),
        if (_canAdd) ...[
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _openAdd,
            icon: Icon(Icons.person_add_alt_1_rounded, size: 15, color: AppColors.primary),
            label: Text('Add User', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
          ),
        ],
      ],
    );
  }

  /// Shown when arriving from the dashboard's Doctor/Reception cards —
  /// makes the applied filter visible and lets the admin clear it to see
  /// everyone, instead of silently hiding other roles with no indication.
  Widget _buildRoleFilterChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryA08,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.primaryA18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(_roleFilterLabel!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 2),
              InkWell(
                onTap: _clearRoleFilter,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 14, color: AppColors.primaryA55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────

  List<ScaledTableColumn> get _columns => [
        const ScaledTableColumn('NAME', 170),
        const ScaledTableColumn('EMAIL', 190),
        const ScaledTableColumn('ROLE', 130),
        const ScaledTableColumn('CONTACT', 120),
        if (_p.isSuper) const ScaledTableColumn('PASSWORD', 140),
        const ScaledTableColumn('STATUS', 100),
        const ScaledTableColumn('ACTION', 100, headerAlign: TextAlign.right),
      ];

  Widget _buildTableArea() {
    if (_loading) return const AppSkeletonList();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => _load(), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Retry')),
          ]),
        ),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ScaledDataTable(
          columns: _columns,
          rows: _users.map(_rowCells).toList(),
          emptyMessage: _search.isNotEmpty ? 'No users match your search.' : 'No users yet.',
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final start = _perPage <= 0 ? (_total == 0 ? 0 : 1) : ((_currentPage - 1) * _perPage) + 1;
    final end = _perPage <= 0 ? _total : (_currentPage * _perPage).clamp(0, _total);
    return TablePaginationFooter(
      total: _total,
      currentPage: _currentPage,
      lastPage: _lastPage,
      start: start,
      end: end,
      onPrev: () { _currentPage--; _load(); },
      onNext: () { _currentPage++; _load(); },
    );
  }

  List<Widget> _rowCells(HospitalUserModel u) {
    final roleColor = u.role?.parsedColor ?? AppColors.primary;
    final isActive = u.status == 'active';
    final canEdit = _canForUser(u, 'edit');
    final canDelete = _canForUser(u, 'delete');

    final cells = <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(_initials(u.name), style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(u.name, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      ]),
      Text(u.email, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      u.role != null
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(child: Text(u.role!.name, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ])
          : const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(u.contact.isNotEmpty ? u.contact : '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      if (_p.isSuper) _passwordCell(u),
      _statusCell(isActive, canEdit, u),
      Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
        if (canEdit) TableIconAction(icon: Icons.edit_outlined, tooltip: 'Edit', kind: TableActionKind.edit, onTap: () => _openEdit(u)),
        if (canEdit && canDelete) const SizedBox(width: 4),
        if (canDelete) TableIconAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', kind: TableActionKind.delete, onTap: () => _confirmDelete(u)),
      ]),
    ];
    return cells;
  }

  Widget _passwordCell(HospitalUserModel u) {
    final pw = u.originalPassword;
    if (pw == null || pw.isEmpty) {
      return Text('Set via Edit', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textDisabled));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(pw, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.textPrimary))),
      const SizedBox(width: 4),
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          Clipboard.setData(ClipboardData(text: pw));
          showAppSnackBar(context, 'Password copied.', isSuccess: true);
        },
        child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.copy_rounded, size: 13, color: AppColors.primaryA55)),
      ),
    ]);
  }

  Widget _statusCell(bool isActive, bool canEdit, HospitalUserModel u) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (isActive ? AppColors.green : AppColors.textDisabled).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isActive ? AppColors.green : AppColors.textDisabled, letterSpacing: 0.3)),
    );
    if (!canEdit) return Align(alignment: Alignment.centerLeft, child: pill);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(borderRadius: BorderRadius.circular(AppRadius.full), onTap: () => _toggleStatus(u), child: pill),
    );
  }

}
