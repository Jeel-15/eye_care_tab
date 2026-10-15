import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/masters_service.dart';
import '../services/permission_service.dart';
import '../services/referrer_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet Referrers master — name + contact. Ported from
/// eye_care_app/lib/screens/referrer_master_screen.dart.
class ReferrerMasterScreen extends StatefulWidget {
  final Color accentColor;
  const ReferrerMasterScreen({super.key, required this.accentColor});

  @override
  State<ReferrerMasterScreen> createState() => _ReferrerMasterScreenState();
}

class _ReferrerMasterScreenState extends State<ReferrerMasterScreen> {
  final _p = PermissionService.instance;
  List<ReferrerItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterReferrerAdd);
  bool get _canEdit => _p.can(Perm.masterReferrerEdit);
  bool get _canDelete => _p.can(Perm.masterReferrerDelete);

  List<ReferrerItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) =>
                  i.name.toLowerCase().contains(_query.toLowerCase()) ||
                  (i.contact ?? '').contains(_query),
            )
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
      final items = await ReferrerService.instance.fetchAll();
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

  Future<void> _delete(ReferrerItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Referrer',
      message: 'Delete "${item.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ReferrerService.instance.delete(item.id);
      MastersService.instance.clearCache();
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

  Future<void> _openDialog({ReferrerItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReferrerDialog(item: item, accentColor: widget.accentColor),
    );
    if (saved == true && mounted) {
      MastersService.instance.clearCache();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_alt_rounded, color: widget.accentColor, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Referrers',
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
            if (_canAdd) ...[
              const SizedBox(width: 4),
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
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search referrers...',
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
    if (_loading)
      return const AppSkeletonList(
        count: 6,
        itemHeight: 60,
        padding: EdgeInsets.zero,
      );
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
          _query.isNotEmpty ? 'No results' : 'No referrers yet.',
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
          return AnimatedListItem(
            index: i,
            child: Container(
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
                  if (item.contact != null && item.contact!.isNotEmpty)
                    Text(
                      item.contact!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (_canEdit || _canDelete) const SizedBox(width: 12),
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
            ),
          );
        },
      ),
    );
  }
}

class _ReferrerDialog extends StatefulWidget {
  final ReferrerItem? item;
  final Color accentColor;

  const _ReferrerDialog({required this.item, required this.accentColor});

  @override
  State<_ReferrerDialog> createState() => _ReferrerDialogState();
}

class _ReferrerDialogState extends State<_ReferrerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  bool _saving = false;
  String? _nameErr;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _contactCtrl = TextEditingController(text: widget.item?.contact ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
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
      final contact = _contactCtrl.text.trim();
      final item = widget.item;
      if (item == null) {
        await ReferrerService.instance.create(
          name,
          contact.isEmpty ? null : contact,
        );
      } else {
        await ReferrerService.instance.update(
          item.id,
          name,
          contact.isEmpty ? null : contact,
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
        title: isEdit ? 'Edit Referrer' : 'Add Referrer',
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
          TextFormField(
            controller: _contactCtrl,
            keyboardType: TextInputType.phone,
            decoration: appFieldDecoration(
              'Contact (optional)',
              prefix: Icons.phone_outlined,
            ),
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
