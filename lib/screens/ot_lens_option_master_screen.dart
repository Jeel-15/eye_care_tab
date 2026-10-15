import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../services/ot_lens_option_service.dart';
import '../models/ot_inventory_models.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet Lens Options master — corrected-permission route (Round 3.5).
/// Ported from eye_care_app/lib/screens/ot_lens_option_master_screen.dart.
class OtLensOptionMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtLensOptionMasterScreen({super.key, required this.accentColor});

  @override
  State<OtLensOptionMasterScreen> createState() =>
      _OtLensOptionMasterScreenState();
}

class _OtLensOptionMasterScreenState extends State<OtLensOptionMasterScreen> {
  final _p = PermissionService.instance;
  List<OtLensOptionItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterOtLensOptionAdd);
  bool get _canEdit => _p.can(Perm.masterOtLensOptionEdit);
  bool get _canDelete => _p.can(Perm.masterOtLensOptionDelete);

  List<OtLensOptionItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

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
      final items = await OtLensOptionService.instance.fetchAll();
      if (mounted)
        setState(() {
          _all = items;
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

  Future<void> _delete(OtLensOptionItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Lens Option',
      message: 'Delete "${item.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await OtLensOptionService.instance.delete(item.id);
      await _load();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  Future<void> _openDialog({OtLensOptionItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _OtLensOptionDialog(item: item, accentColor: widget.accentColor),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.remove_red_eye_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Lens Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              color: widget.accentColor,
              onPressed: _loading ? null : _load,
            ),
            const SizedBox(width: 4),
            if (_canAdd)
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search lens options...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.background,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 60);
    if (_error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    final items = _filtered;
    if (items.isEmpty)
      return Center(
        child: Text(
          _query.isNotEmpty ? 'No results' : 'No lens options yet.',
          style: const TextStyle(color: AppColors.textDisabled),
        ),
      );
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primaryA08),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (item.isActive
                                ? AppColors.green
                                : AppColors.textDisabled)
                            .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.isActive
                          ? AppColors.green
                          : AppColors.textDisabled,
                    ),
                  ),
                ),
                if (_canEdit)
                  TableIconAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    kind: TableActionKind.edit,
                    onTap: () => _openDialog(item: item),
                  ),
                if (_canDelete)
                  TableIconAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    kind: TableActionKind.delete,
                    onTap: () => _delete(item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OtLensOptionDialog extends StatefulWidget {
  final OtLensOptionItem? item;
  final Color accentColor;

  const _OtLensOptionDialog({required this.item, required this.accentColor});

  @override
  State<_OtLensOptionDialog> createState() => _OtLensOptionDialogState();
}

class _OtLensOptionDialogState extends State<_OtLensOptionDialog> {
  late final TextEditingController _nameCtrl;
  late bool _isActive;
  bool _saving = false;
  String? _nameErr;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    // Web add form defaults Active checkbox checked.
    _isActive = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'Required');
      return;
    }
    setState(() {
      _saving = true;
      _nameErr = null;
    });
    try {
      final item = widget.item;
      if (item == null) {
        await OtLensOptionService.instance.create(name, isActive: _isActive);
      } else {
        await OtLensOptionService.instance.update(
          item.id,
          name,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.item != null;
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: isEdit ? Icons.edit_outlined : Icons.add_rounded,
        title: isEdit ? 'Edit Lens Option' : 'Add Lens Option',
        colors: [widget.accentColor, widget.accentColor],
        onClose: _saving ? null : () => Navigator.pop(context, false),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameCtrl,
            autofocus: !isEdit,
            decoration: appFieldDecoration(
              'Name',
            ).copyWith(errorText: _nameErr),
          ),
          const SizedBox(height: 14),
          // Web parity: Active checkbox on add/edit modal
          AppSwitchTile(
            label: 'Active',
            subtitle: _isActive ? 'Shown as available' : 'Marked inactive',
            value: _isActive,
            color: widget.accentColor,
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ],
      ),
      actions: [
        AppSecondaryButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        AppPrimaryButton(
          label: 'Save',
          color: widget.accentColor,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
