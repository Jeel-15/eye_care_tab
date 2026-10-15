import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/role_models.dart';
import '../services/permission_service.dart';
import '../services/roles_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/form_kit.dart';
import '../widgets/permission_tree_editor.dart';
import '../widgets/split_pane_scaffold.dart';
import '../widgets/table_row_action.dart';
import '../widgets/skeleton.dart';

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

  bool get _canAdd => _p.can(Perm.masterRoleAdd);
  bool get _canEdit => _p.can(Perm.masterRoleEdit);
  bool get _canDelete => _p.can(Perm.masterRoleDelete);

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
      if (mounted)
        setState(() {
          _roles = roles;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete Role',
      message: 'Delete role "${role.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await RolesService.instance.deleteRole(role.id);
      if (_selectedId == role.id) setState(() => _paneMode = _PaneMode.empty);
      _load();
      if (mounted)
        showAppSnackBar(
          context,
          'Role "${role.name}" deleted.',
          isSuccess: true,
        );
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplitPaneScaffold(
      showDetail: _paneMode == _PaneMode.editor,
      onBack: _cancelEditor,
      listPane: _buildListPane(),
      detailPane: _buildDetailPane(),
      listPaneWidth: 360,
    );
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Roles & Permissions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
                if (_canAdd)
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: 'New Role',
                    onPressed: _openNew,
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 70);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_roles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.shield_outlined,
        message: 'No roles found.',
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _roles.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.primaryA08),
        itemBuilder: (_, i) => _RoleListTile(
          role: _roles[i],
          selected:
              _roles[i].id == _selectedId && _paneMode == _PaneMode.editor,
          canView: _p.canAny(const [Perm.masterRoles, Perm.masterRoleEdit]),
          canDelete: _canDelete,
          onTap: () => _openEdit(_roles[i]),
          onDelete: () => _confirmDelete(_roles[i]),
        ),
      ),
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.empty) {
      return _panelBox(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: AppColors.primaryA22,
              ),
              const SizedBox(height: 12),
              Text(
                'Select a role to view or edit permissions',
                style: TextStyle(fontSize: 13, color: AppColors.primaryA55),
              ),
            ],
          ),
        ),
      );
    }
    final existing = _creating
        ? null
        : _roles.where((r) => r.id == _selectedId).firstOrNull;
    return _panelBox(
      child: _RoleEditorPane(
        key: ValueKey(_creating ? 'new' : _selectedId),
        existing: existing,
        editable: _creating ? _canAdd : _canEdit,
        onSaved: _onSaved,
        onCancel: _cancelEditor,
      ),
    );
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: child,
    );
  }
}

// ── List tile ──────────────────────────────────────────────────────────

class _RoleListTile extends StatelessWidget {
  final RoleModel role;
  final bool selected;
  final bool canView;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RoleListTile({
    required this.role,
    required this.selected,
    required this.canView,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
  });

  Color get _color {
    try {
      return Color(
        int.parse('FF${role.color.replaceFirst('#', '')}', radix: 16),
      );
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
        onTap: canView ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          role.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        if (role.isSuper) _badge('Super', AppColors.teal),
                        if (role.isSystem)
                          _badge('System', AppColors.textDisabled),
                      ],
                    ),
                    Text(
                      '${role.usersCount} user${role.usersCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryA55,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete && role.isDeletable)
                TableIconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  kind: TableActionKind.delete,
                  onTap: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

// ── Role editor pane ─────────────────────────────────────────────────────

class _RoleEditorPane extends StatefulWidget {
  final RoleModel? existing;
  final bool editable;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _RoleEditorPane({
    super.key,
    this.existing,
    required this.editable,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<_RoleEditorPane> createState() => _RoleEditorPaneState();
}

class _RoleEditorPaneState extends State<_RoleEditorPane> {
  // Web's default new-role color (`create.blade.php`'s native color input
  // default) — matches exactly so a brand-new role's color isn't an
  // arbitrary Flutter-side pick.
  static const _defaultColor = '#1B4F72';

  static const _colorPalette = [
    '#1B4F72',
    '#154360',
    '#2471A3',
    '#2980B9',
    '#006497',
    '#1ABC9C',
    '#0E9E82',
    '#27AE60',
    '#16A34A',
    '#E67E22',
    '#EA580C',
    '#DC3545',
    '#C0392B',
    '#8E44AD',
    '#7D3C98',
    '#2C3E50',
    '#7F8C8D',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String _colorHex;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  Map<String, PermissionModuleGroup> _permissions = {};

  bool get _isEdit => widget.existing != null;
  bool get _isSuper => widget.existing?.isSuper ?? false;
  bool get _isSystem => widget.existing?.isSystem ?? false;

  @override
  void initState() {
    super.initState();
    _colorHex = widget.existing?.color ?? _defaultColor;
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description ?? '';
    }
    _loadPermissions();
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _pickColor() async {
    String draft = _colorHex;
    final hexCtrl = TextEditingController(
      text: _colorHex.replaceFirst('#', ''),
    );
    final picked = await showDialog<String>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, ss) {
          return AppDialog(
            size: AppDialogSize.small,
            header: AppDialogHeader(
              icon: Icons.palette_rounded,
              title: 'Role Color',
              onClose: () => Navigator.pop(dCtx),
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorPalette.map((hex) {
                    final selected = draft.toUpperCase() == hex.toUpperCase();
                    return GestureDetector(
                      onTap: () => ss(() {
                        draft = hex;
                        hexCtrl.text = hex.replaceFirst('#', '');
                      }),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _hexToColor(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: hexCtrl,
                  maxLength: 6,
                  decoration: appFieldDecoration('Custom hex').copyWith(
                    prefixIcon: null,
                    prefixText: '#',
                    counterText: '',
                  ),
                  onChanged: (v) => draft = '#$v',
                ),
              ],
            ),
            actions: [
              AppSecondaryButton(onPressed: () => Navigator.pop(dCtx)),
              AppPrimaryButton(
                label: 'Select',
                onPressed: () => Navigator.pop(dCtx, draft),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null && mounted) setState(() => _colorHex = picked);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final role = await RolesService.instance.fetchRole(widget.existing!.id);
        if (mounted)
          setState(() {
            _permissions = _deepCopy(role.permissions);
            _loading = false;
          });
      } else {
        final all = await RolesService.instance.fetchAllPermissions();
        final perms = _deepCopy(all.modules);
        _applyNewRoleDefaults(perms);
        if (mounted)
          setState(() {
            _permissions = perms;
            _loading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Map<String, PermissionModuleGroup> _deepCopy(
    Map<String, PermissionModuleGroup> src,
  ) => {
    for (final me in src.entries)
      me.key: PermissionModuleGroup(
        label: me.value.label,
        features: {
          for (final fe in me.value.features.entries)
            fe.key: PermissionFeatureGroup(
              label: fe.value.label,
              permissions: fe.value.permissions
                  .map((p) => p.copyWith())
                  .toList(),
            ),
        },
      ),
  };

  /// Mirrors the web Role-create form's default: Dashboard widgets start
  /// checked for a brand-new role, everything else unchecked.
  void _applyNewRoleDefaults(Map<String, PermissionModuleGroup> perms) {
    final dashboard = perms['dashboard'];
    if (dashboard == null) return;
    for (final feature in dashboard.features.values) {
      for (var i = 0; i < feature.permissions.length; i++) {
        feature.permissions[i] = feature.permissions[i].copyWith(
          isGranted: true,
        );
      }
    }
  }

  List<int> get _grantedIds => _permissions.values
      .expand((m) => m.allPermissions)
      .where((p) => p.isGranted)
      .map((p) => p.id)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // Web parity: system roles lock the NAME only — color stays
        // editable regardless of is_system (`edit.blade.php`'s color
        // <input> has no readonly/disabled condition tied to is_system).
        await RolesService.instance.updateRole(
          id: widget.existing!.id,
          name: _isSystem ? null : _nameCtrl.text.trim(),
          color: _colorHex,
          description: _descCtrl.text.trim(),
          permissionIds: _isSuper ? null : _grantedIds,
        );
      } else {
        await RolesService.instance.createRole(
          name: _nameCtrl.text.trim(),
          color: _colorHex,
          description: _descCtrl.text.trim(),
          permissionIds: _grantedIds,
        );
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 70);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPermissions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
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
                  if (_isSuper)
                    _buildSuperBanner()
                  else
                    PermissionTreeEditor(
                      permissions: _permissions,
                      enabled: widget.editable,
                    ),
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
        IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.primary),
          onPressed: widget.onCancel,
          tooltip: 'Cancel',
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.blueLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            _isEdit ? Icons.edit_rounded : Icons.add_moderator_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit Role' : 'New Role',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Name, description and module permissions',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        if (widget.editable)
          SizedBox(
            width: 140,
            child: AppPrimaryButton(
              label: 'Save',
              loading: _saving,
              onPressed: _save,
            ),
          ),
      ],
    );
  }

  Widget _buildNameCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryA07),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryA05,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web parity (`edit.blade.php`'s card header): "Role Details" +
          // subtitle on the left, System Role / Super / user-count badges
          // on the right — badges only ever shown when editing an existing
          // role (web's create.blade.php renders none of them; a brand-new
          // role has no id/system flag/user count yet).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryA10,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Update access settings and permission coverage for this role.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEdit)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_isSystem)
                      _headerBadge('SYSTEM ROLE', AppColors.textDisabled),
                    if (_isSuper)
                      _headerBadge('SUPER — ALL PERMISSIONS', AppColors.orange),
                    _headerBadge(
                      '${widget.existing!.usersCount} USER(S)',
                      AppColors.blue,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.primaryA08),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 520;
              final name = TextFormField(
                controller: _nameCtrl,
                enabled: widget.editable && !_isSystem,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Role name is required'
                    : null,
                decoration: appFieldDecoration('Role Name', hint: 'e.g. Nurse')
                    .copyWith(
                      helperText: _isSystem
                          ? 'System role name cannot be changed.'
                          : null,
                    ),
              );
              final color = _buildColorField();
              final desc = TextFormField(
                controller: _descCtrl,
                enabled: widget.editable,
                maxLines: 2,
                decoration: appFieldDecoration('Description (optional)'),
              );
              if (!wide) {
                return Column(
                  children: [
                    name,
                    const SizedBox(height: 12),
                    color,
                    const SizedBox(height: 12),
                    desc,
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: name),
                      const SizedBox(width: 16),
                      SizedBox(width: 160, child: color),
                    ],
                  ),
                  const SizedBox(height: 12),
                  desc,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _buildColorField() {
    final swatch = _hexToColor(_colorHex);
    final labelColor = swatch.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.editable ? _pickColor : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: swatch,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primaryA10),
            ),
            alignment: Alignment.center,
            child: Text(
              _colorHex.toUpperCase(),
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuperBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryA07),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.teal, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Super Admin bypasses all permission checks — permissions cannot be edited for this role.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
