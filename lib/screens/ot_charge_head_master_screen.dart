import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../services/ot_charge_head_service.dart';
import '../utils/app_dialogs.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet OT Charge Heads master — name + percentage + active toggle.
/// Ported from eye_care_app/lib/screens/ot_charge_head_master_screen.dart.
class OtChargeHeadMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtChargeHeadMasterScreen({super.key, required this.accentColor});

  @override
  State<OtChargeHeadMasterScreen> createState() =>
      _OtChargeHeadMasterScreenState();
}

class _OtChargeHeadMasterScreenState extends State<OtChargeHeadMasterScreen> {
  final _p = PermissionService.instance;
  List<OtChargeHeadItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterOtChargeAdd);
  bool get _canEdit => _p.can(Perm.masterOtChargeEdit);
  bool get _canDelete => _p.can(Perm.masterOtChargeDelete);

  List<OtChargeHeadItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) => i.chargeName.toLowerCase().contains(_query.toLowerCase()),
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
      final items = await OtChargeHeadService.instance.fetchAll();
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

  Future<void> _delete(OtChargeHeadItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Charge Head',
      message: 'Delete "${item.chargeName}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await OtChargeHeadService.instance.delete(item.id);
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

  Future<void> _openDialog({OtChargeHeadItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _OtChargeHeadDialog(item: item, accentColor: widget.accentColor),
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
            Icon(Icons.payments_rounded, color: widget.accentColor, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'OT Charge Heads',
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
            hintText: 'Search charge heads...',
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
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 68);
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
          _query.isNotEmpty ? 'No results' : 'No charge heads yet.',
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
                    item.chargeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!item.isActive)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.redA70.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  '${item.percentage.toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
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

class _OtChargeHeadDialog extends StatefulWidget {
  final OtChargeHeadItem? item;
  final Color accentColor;

  const _OtChargeHeadDialog({required this.item, required this.accentColor});

  @override
  State<_OtChargeHeadDialog> createState() => _OtChargeHeadDialogState();
}

class _OtChargeHeadDialogState extends State<_OtChargeHeadDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _pctCtrl;
  late bool _active;
  bool _saving = false;
  String? _nameErr;
  String? _pctErr;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.chargeName ?? '');
    _pctCtrl = TextEditingController(
      text: item != null
          ? (item.percentage == item.percentage.toInt()
                ? item.percentage.toInt().toString()
                : item.percentage.toString())
          : '',
    );
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pctCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final pct = double.tryParse(_pctCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _nameErr = 'Required');
      return;
    }
    if (pct == null) {
      setState(() => _pctErr = 'Invalid');
      return;
    }
    setState(() {
      _saving = true;
      _nameErr = null;
      _pctErr = null;
    });
    try {
      final item = widget.item;
      if (item == null) {
        await OtChargeHeadService.instance.create(name, pct, _active);
      } else {
        await OtChargeHeadService.instance.update(item.id, name, pct, _active);
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
        title: isEdit ? 'Edit Charge Head' : 'Add Charge Head',
        subtitle: isEdit ? widget.item!.chargeName : 'OT master',
        colors: [widget.accentColor, widget.accentColor],
        onClose: _saving ? null : () => Navigator.pop(context, false),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFormRow(
            flex: const [3, 2],
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: !isEdit,
                textInputAction: TextInputAction.next,
                decoration: appFieldDecoration(
                  'Charge Name',
                ).copyWith(errorText: _nameErr),
              ),
              TextFormField(
                controller: _pctCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_saving) _save();
                },
                decoration:
                    appFieldDecoration(
                      'Percentage',
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          '%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryA55,
                          ),
                        ),
                      ),
                    ).copyWith(
                      errorText: _pctErr,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppSwitchTile(
            label: 'Active',
            value: _active,
            color: widget.accentColor,
            onChanged: _saving ? null : (v) => setState(() => _active = v),
          ),
        ],
      ),
      actions: [
        AppSecondaryButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
        ),
        AppPrimaryButton(
          label: isEdit ? 'Update' : 'Save',
          color: widget.accentColor,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
