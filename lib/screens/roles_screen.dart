import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/role_models.dart';
import '../services/permission_service.dart';
import '../services/roles_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';

/// Tablet Roles & Permissions module — Pattern A (role list left, permission
/// editor right) replacing mobile's list + full-screen editor route. The
/// permission editor is the deliberate tablet win the PRD calls for: modules
/// render as always-expanded cards in a responsive grid instead of mobile's
/// ExpansionTile accordion, so every permission is visible and toggleable at
/// once — width mobile never had. Business logic (fetch/create/update/delete,
/// permission diffing) ported unchanged from
/// eye_care_app/lib/screens/roles_screen.dart.
class RolesScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const RolesScreen({super.key, required this.user, required this.hospital});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

enum _PaneMode { empty, editor }

class _RolesScreenState extends State<RolesScreen> {
  final _p = PermissionService.instance;

  bool _loading = false;
  String? _error;
  List<RoleModel> _roles = [];

  int? _selectedId;
  bool _creating = false;
  _PaneMode _paneMode = _PaneMode.empty;

  bool get _canManage => _p.can(Perm.masterRoles);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await RolesService.instance.fetchRoles();
      if (mounted) setState(() { _roles = roles; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _openNew() => setState(() {
        _selectedId = null;
        _creating = true;
        _paneMode = _PaneMode.editor;
      });

  void _openEdit(RoleModel role) => setState(() {
        _selectedId = role.id;
        _creating = false;
        _paneMode = _PaneMode.editor;
      });

  void _cancelEditor() => setState(() => _paneMode = _PaneMode.empty);

  void _onSaved() {
    setState(() => _paneMode = _PaneMode.empty);
    _load();
    showAppSnackBar(context, 'Role saved.', isSuccess: true);
  }

  Future<void> _confirmDelete(RoleModel role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Role'),
        content: Text('Delete role "${role.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await RolesService.instance.deleteRole(role.id);
      if (_selectedId == role.id) setState(() => _paneMode = _PaneMode.empty);
      _load();
      if (mounted) showAppSnackBar(context, 'Role "${role.name}" deleted.', isSuccess: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (!splitView) {
        return _paneMode == _PaneMode.editor
            ? Column(children: [
                TextButton.icon(onPressed: _cancelEditor, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 360, child: listPane),
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
              Text('Roles & Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Spacer(),
              IconButton(icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh', onPressed: _load),
              if (_canManage) IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22), tooltip: 'New Role', onPressed: _openNew),
            ]),
          ),
          Expanded(child: _buildList()),
        ],
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
            ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_roles.isEmpty) {
      return const AppEmptyState(icon: Icons.shield_outlined, message: 'No roles found.');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _roles.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
      itemBuilder: (_, i) => _RoleListTile(role: _roles[i], selected: _roles[i].id == _selectedId && _paneMode == _PaneMode.editor, canManage: _canManage, onTap: () => _openEdit(_roles[i]), onDelete: () => _confirmDelete(_roles[i])),
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.empty) {
      return _panelBox(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_outlined, size: 56, color: AppColors.primaryA22),
            const SizedBox(height: 12),
            Text('Select a role to view or edit permissions', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    final existing = _creating ? null : _roles.where((r) => r.id == _selectedId).firstOrNull;
    return _panelBox(child: _RoleEditorPane(key: ValueKey(_creating ? 'new' : _selectedId), existing: existing, onSaved: _onSaved, onCancel: _cancelEditor));
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

class _RoleListTile extends StatelessWidget {
  final RoleModel role;
  final bool selected;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoleListTile({required this.role, required this.selected, required this.canManage, required this.onTap, required this.onDelete});

  Color get _color {
    try {
      return Color(int.parse('FF${role.color.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
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
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.shield_outlined, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                  Text(role.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                  if (role.isSuper) _badge('Super', AppColors.teal),
                  if (role.isSystem) _badge('System', AppColors.textDisabled),
                ]),
                Text('${role.usersCount} user${role.usersCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppColors.primaryA55)),
              ]),
            ),
            if (canManage && role.isDeletable) IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), color: AppColors.red, tooltip: 'Delete', onPressed: onDelete),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      );
}

// ── Role editor pane ─────────────────────────────────────────────────────

class _RoleEditorPane extends StatefulWidget {
  final RoleModel? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _RoleEditorPane({super.key, this.existing, required this.onSaved, required this.onCancel});

  @override
  State<_RoleEditorPane> createState() => _RoleEditorPaneState();
}

class _RoleEditorPaneState extends State<_RoleEditorPane> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, List<RolePermissionItem>> _permissions = {};

  bool get _isEdit => widget.existing != null;
  bool get _isSuper => widget.existing?.isSuper ?? false;
  bool get _isSystem => widget.existing?.isSystem ?? false;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description ?? '';
    }
    _loadPermissions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isEdit) {
        final role = await RolesService.instance.fetchRole(widget.existing!.id);
        if (mounted) setState(() { _permissions = _deepCopy(role.permissions); _loading = false; });
      } else {
        final all = await RolesService.instance.fetchAllPermissions();
        if (mounted) setState(() { _permissions = _deepCopy(all.modules); _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Map<String, List<RolePermissionItem>> _deepCopy(Map<String, List<RolePermissionItem>> src) =>
      {for (final e in src.entries) e.key: e.value.map((p) => p.copyWith()).toList()};

  List<int> get _grantedIds => _permissions.values.expand((l) => l).where((p) => p.isGranted).map((p) => p.id).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await RolesService.instance.updateRole(id: widget.existing!.id, name: _isSystem ? null : _nameCtrl.text.trim(), description: _descCtrl.text.trim(), permissionIds: _isSuper ? null : _grantedIds);
      } else {
        await RolesService.instance.createRole(name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(), permissionIds: _grantedIds);
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  String _moduleLabel(String module) {
    const labels = {'opd': 'OPD', 'ot': 'OT (Operation Theatre)', 'master': 'Masters', 'settings': 'Settings', 'reports': 'Reports'};
    return labels[module] ?? (module.isEmpty ? module : module[0].toUpperCase() + module.substring(1));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _loadPermissions, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
          ]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameCard(),
                  const SizedBox(height: 16),
                  if (_isSuper) _buildSuperBanner() else _buildPermissionGrid(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Cancel'),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(_isEdit ? Icons.edit_rounded : Icons.add_moderator_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isEdit ? 'Edit Role' : 'New Role', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Name, description and module permissions', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildNameCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA07), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 10, offset: const Offset(0, 3))]),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        final name = TextFormField(
          controller: _nameCtrl,
          enabled: !_isSystem,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Role name is required' : null,
          decoration: InputDecoration(labelText: 'Role Name', hintText: 'e.g. Nurse', border: const OutlineInputBorder(), helperText: _isSystem ? 'System role name cannot be changed.' : null),
        );
        final desc = TextFormField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()));
        if (!wide) return Column(children: [name, const SizedBox(height: 12), desc]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: name), const SizedBox(width: 16), Expanded(child: desc)]);
      }),
    );
  }

  Widget _buildSuperBanner() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA07)),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.verified_user_rounded, color: AppColors.teal, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text('Super Admin bypasses all permission checks — permissions cannot be edited for this role.', style: TextStyle(color: AppColors.textSecondary))),
      ]),
    );
  }

  Widget _buildPermissionGrid() {
    return LayoutBuilder(builder: (context, c) {
      final twoColumn = c.maxWidth >= 720;
      final cardWidth = twoColumn ? (c.maxWidth - 16) / 2 : c.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _permissions.entries.map((entry) => SizedBox(width: cardWidth, child: _buildModuleCard(entry.key, entry.value))).toList(),
      );
    });
  }

  Widget _buildModuleCard(String module, List<RolePermissionItem> perms) {
    final grantedCount = perms.where((p) => p.isGranted).length;
    final allGranted = perms.isNotEmpty && perms.every((p) => p.isGranted);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA07), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Text(_moduleLabel(module), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: grantedCount > 0 ? AppColors.green.withValues(alpha: 0.10) : AppColors.primaryA08, borderRadius: BorderRadius.circular(10)),
                child: Text('$grantedCount / ${perms.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: grantedCount > 0 ? AppColors.green : AppColors.textSecondary)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  for (var i = 0; i < perms.length; i++) {
                    perms[i] = perms[i].copyWith(isGranted: !allGranted);
                  }
                }),
                child: Text(allGranted ? 'None' : 'All', style: TextStyle(fontSize: 12, color: AppColors.primary)),
              ),
            ]),
          ),
          Divider(height: 1, color: AppColors.primaryA08),
          ...perms.asMap().entries.map((e) {
            final idx = e.key;
            final perm = e.value;
            return CheckboxListTile(
              dense: true,
              value: perm.isGranted,
              activeColor: AppColors.primary,
              title: Text(perm.label, style: const TextStyle(fontSize: 13)),
              subtitle: perm.description.isNotEmpty ? Text(perm.description, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
              onChanged: (val) => setState(() => perms[idx] = perms[idx].copyWith(isGranted: val ?? false)),
            );
          }),
        ],
      ),
    );
  }
}
