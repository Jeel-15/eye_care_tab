import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/case_type_service.dart';
import '../services/masters_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';
import '../utils/currency_format.dart';

/// Tablet Case Types master — name + fee. Embedded as a Masters hub detail
/// pane. Ported from eye_care_app/lib/screens/case_type_master_screen.dart.
class CaseTypeMasterScreen extends StatefulWidget {
  final Color accentColor;
  const CaseTypeMasterScreen({super.key, required this.accentColor});

  @override
  State<CaseTypeMasterScreen> createState() => _CaseTypeMasterScreenState();
}

class _CaseTypeMasterScreenState extends State<CaseTypeMasterScreen> {
  final _p = PermissionService.instance;
  List<CaseTypeItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterCaseTypeAdd);
  bool get _canEdit => _p.can(Perm.masterCaseTypeEdit);
  bool get _canDelete => _p.can(Perm.masterCaseTypeDelete);

  List<CaseTypeItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) => i.caseType.toLowerCase().contains(_query.toLowerCase()),
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
      final items = await CaseTypeService.instance.fetchAll();
      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete(CaseTypeItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Case Type',
      message: 'Delete "${item.caseType}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await CaseTypeService.instance.delete(item.id);
      MastersService.instance.clearCache();
      await _load();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _openDialog({CaseTypeItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dCtx) =>
          _CaseTypeDialog(item: item, accentColor: widget.accentColor),
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
            Icon(
              Icons.folder_open_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Case Types',
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
            hintText: 'Search case types...',
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
    if (_loading) {
      return const AppSkeletonList(
        count: 6,
        itemHeight: 60,
        padding: EdgeInsets.zero,
      );
    }
    if (_error != null) {
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
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _query.isNotEmpty ? 'No results' : 'No case types yet.',
          style: const TextStyle(color: AppColors.textDisabled),
        ),
      );
    }
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
                    item.caseType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${currentCurrencySymbol()}${item.caseFee.toInt()}',
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

class _CaseTypeDialog extends StatefulWidget {
  final CaseTypeItem? item;
  final Color accentColor;

  const _CaseTypeDialog({required this.item, required this.accentColor});

  @override
  State<_CaseTypeDialog> createState() => _CaseTypeDialogState();
}

class _CaseTypeDialogState extends State<_CaseTypeDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _feeCtrl;
  bool _saving = false;
  String? _nameErr;
  String? _feeErr;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl = TextEditingController(text: item?.caseType ?? '');
    _feeCtrl = TextEditingController(
      text: item == null
          ? ''
          : (item.caseFee == item.caseFee.roundToDouble()
                ? '${item.caseFee.toInt()}'
                : item.caseFee.toStringAsFixed(2)),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final feeText = _feeCtrl.text.trim();
    final fee = double.tryParse(feeText);
    setState(() {
      _nameErr = name.isEmpty ? 'Required' : null;
      _feeErr = fee == null ? 'Invalid fee' : null;
    });
    if (_nameErr != null || _feeErr != null) return;

    setState(() => _saving = true);
    try {
      final item = widget.item;
      if (item == null) {
        await CaseTypeService.instance.create(name, fee!);
      } else {
        await CaseTypeService.instance.update(item.id, name, fee!);
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
        title: isEdit ? 'Edit Case Type' : 'Add Case Type',
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
              'Case Type',
            ).copyWith(errorText: _nameErr),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _feeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: appFieldDecoration(
              'Case Fee (${currentCurrencySymbol()})',
            ).copyWith(errorText: _feeErr),
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
