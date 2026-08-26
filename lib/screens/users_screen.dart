import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../widgets/app_animations.dart';
import 'user_form_pane.dart';

enum _PaneMode { view, add, edit }

/// Tablet Users module — Pattern A (list + detail split), matching Patients
/// and Masters. Left pane: search + paginated list. Right pane: selected
/// user's profile, or [UserFormPane] (Pattern C) when adding/editing.
/// Business logic ported from eye_care_app/lib/screens/users_screen.dart.
class UsersScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const UsersScreen({super.key, required this.user, required this.hospital});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  List<HospitalUserModel> _users = [];
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  String? _error;

  int? _selectedId;
  _PaneMode _paneMode = _PaneMode.view;

  @override
  void initState() {
    super.initState();
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
      final resp = await UserService.instance.fetchUsers(page: page, search: _search.isEmpty ? null : _search);
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

  void _selectUser(HospitalUserModel u) => setState(() {
        _selectedId = u.id;
        _paneMode = _PaneMode.view;
      });

  void _openAdd() => setState(() {
        _selectedId = null;
        _paneMode = _PaneMode.add;
      });

  void _openEdit(HospitalUserModel u) => setState(() {
        _selectedId = u.id;
        _paneMode = _PaneMode.edit;
      });

  void _cancelForm() => setState(() => _paneMode = _PaneMode.view);

  void _onFormSaved(HospitalUserModel saved) {
    setState(() {
      _paneMode = _PaneMode.view;
      _selectedId = saved.id;
    });
    _load();
    showAppSnackBar(context, 'Saved.', isSuccess: true);
  }

  Future<void> _confirmDelete(HospitalUserModel u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Delete User', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
        content: Text('Delete "${u.name}"? This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await UserService.instance.deleteUser(u.id);
      if (!mounted) return;
      showAppSnackBar(context, '"${u.name}" deleted successfully', isSuccess: true);
      if (_selectedId == u.id) setState(() => _selectedId = null);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _toggleStatus(HospitalUserModel u) async {
    try {
      final newStatus = await UserService.instance.toggleStatus(u.id);
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((x) => x.id == u.id);
        if (idx >= 0) {
          _users[idx] = HospitalUserModel(
            id: u.id, name: u.name, email: u.email, contact: u.contact, status: newStatus, role: u.role, focPermission: u.focPermission,
            lastLoginAt: u.lastLoginAt, doctorType: u.doctorType, doctorPrefix: u.doctorPrefix, registrationNo: u.registrationNo,
            experienceYears: u.experienceYears, signatureUrl: u.signatureUrl, profilePhotoUrl: u.profilePhotoUrl,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PermissionService.instance;
    if (!p.can(Perm.masterDoctors) && !p.can(Perm.masterReceptions) && !p.can(Perm.masterOtStaff)) {
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
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (!splitView) {
        return _selectedId != null || _paneMode != _PaneMode.view
            ? Column(children: [
                TextButton.icon(onPressed: () => setState(() { _selectedId = null; _paneMode = _PaneMode.view; }), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 380, child: listPane),
          const SizedBox(width: 20),
          Expanded(child: detailPane),
        ],
      );
    });
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Users', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                if (!_loading && _error == null) Text('$_total member${_total == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ]),
              const Spacer(),
              IconButton(icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20), tooltip: 'Add User', onPressed: _openAdd),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildSearchBar()),
          const SizedBox(height: 6),
          Expanded(child: _buildList()),
          if (_lastPage > 1) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search by name, email or contact...',
        hintStyle: TextStyle(fontSize: 13, color: AppColors.primaryA45),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryA55, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primaryA55, size: 18), onPressed: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              })
            : null,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
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
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.manage_accounts_rounded, size: 48, color: AppColors.primaryA22),
            const SizedBox(height: 10),
            Text(_search.isEmpty ? 'No users yet.\nTap + to add the first user.' : 'No users match "$_search"', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _users.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
      itemBuilder: (_, i) {
        final u = _users[i];
        return _UserListTile(user: u, selected: u.id == _selectedId, onTap: () => _selectUser(u));
      },
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), iconSize: 20, onPressed: _currentPage > 1 ? () { _currentPage--; _load(); } : null),
        Text('Page $_currentPage / $_lastPage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), iconSize: 20, onPressed: _currentPage < _lastPage ? () { _currentPage++; _load(); } : null),
      ]),
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.add) {
      return _panelBox(child: UserFormPane(mode: UserFormMode.add, onSaved: _onFormSaved, onCancel: _cancelForm));
    }
    final selected = _users.where((u) => u.id == _selectedId).firstOrNull;
    if (_paneMode == _PaneMode.edit && selected != null) {
      return _panelBox(child: UserFormPane(mode: UserFormMode.edit, editUser: selected, onSaved: _onFormSaved, onCancel: _cancelForm));
    }
    if (selected == null) {
      return _panelBox(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.manage_accounts_rounded, size: 56, color: AppColors.primaryA22),
            const SizedBox(height: 12),
            Text('Select a user to view details', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return _panelBox(child: _UserDetailView(user: selected, onEdit: () => _openEdit(selected), onDelete: () => _confirmDelete(selected), onToggleStatus: () => _toggleStatus(selected)));
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
    );
  }
}

// ── List tile ──────────────────────────────────────────────────────────

class _UserListTile extends StatelessWidget {
  final HospitalUserModel user;
  final bool selected;
  final VoidCallback onTap;

  const _UserListTile({required this.user, required this.selected, required this.onTap});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role?.parsedColor ?? AppColors.primary;
    final isActive = user.status == 'active';
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: roleColor.withValues(alpha: 0.25))),
              alignment: Alignment.center,
              child: Text(_initials(user.name), style: TextStyle(color: roleColor, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                Text([user.email, if (user.role != null) user.role!.name].join(' · '), style: TextStyle(fontSize: 11, color: AppColors.primaryA55), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: (isActive ? AppColors.green : AppColors.textDisabled).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? AppColors.green : AppColors.textDisabled)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Detail view ────────────────────────────────────────────────────────

class _UserDetailView extends StatelessWidget {
  final HospitalUserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _UserDetailView({required this.user, required this.onEdit, required this.onDelete, required this.onToggleStatus});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final u = user;
    final roleColor = u.role?.parsedColor ?? AppColors.primary;
    final isActive = u.status == 'active';
    final isDoctor = u.role?.isDoctorRole == true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: roleColor, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(_initials(u.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  GestureDetector(
                    onTap: onToggleStatus,
                    child: _chip(isActive ? 'Active' : 'Inactive', (isActive ? AppColors.green : AppColors.textDisabled).withValues(alpha: 0.12), isActive ? AppColors.green : AppColors.textDisabled),
                  ),
                  if (u.role != null) _roleChip(u.role!.name, roleColor),
                  if (isDoctor) _chip(u.doctorPrefix != null ? 'Dr. ${u.doctorPrefix}' : 'Doctor', AppColors.blueA12, AppColors.blue),
                ]),
              ]),
            ),
            Row(children: [
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', color: AppColors.primary),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete', color: AppColors.red),
            ]),
          ]),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 560;
            final contact = _infoCard(bg: AppColors.primaryA06, title: 'Contact', items: [
              _InfoRow(Icons.email_outlined, 'Email', u.email),
              _InfoRow(Icons.phone_outlined, 'Contact', u.contact.isNotEmpty ? u.contact : '—'),
              _InfoRow(Icons.login_rounded, 'Last Login', u.lastLoginAt ?? 'Never'),
            ]);
            if (!isDoctor) return contact;
            final doctor = _infoCard(bg: AppColors.blueA12, title: 'Doctor Details', items: [
              _InfoRow(Icons.medical_information_outlined, 'Type', u.doctorType == 'secondary' ? 'Secondary (Optometrist)' : 'Primary (Ophthalmologist)'),
              _InfoRow(Icons.badge_outlined, 'Registration No.', u.registrationNo ?? '—'),
              _InfoRow(Icons.work_history_outlined, 'Experience', u.experienceYears != null ? '${u.experienceYears} yrs' : '—'),
              _InfoRow(Icons.receipt_long_outlined, 'FOC Permission', u.focPermission ? 'Allowed' : 'Not allowed'),
            ]);
            if (!wide) return Column(children: [contact, const SizedBox(height: 12), doctor]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: contact), const SizedBox(width: 12), Expanded(child: doctor)]);
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _roleChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _infoCard({required Color bg, required String title, required List<_InfoRow> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        ...items,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
