import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/duration_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet Durations master — uses durations-crud API (same as mobile).
class DurationMasterScreen extends StatefulWidget {
  final Color accentColor;
  const DurationMasterScreen({super.key, required this.accentColor});

  @override
  State<DurationMasterScreen> createState() => _DurationMasterScreenState();
}

class _DurationMasterScreenState extends State<DurationMasterScreen> {
  final _p = PermissionService.instance;
  List<DurationItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterDurationAdd);
  bool get _canEdit => _p.can(Perm.masterDurationEdit);
  bool get _canDelete => _p.can(Perm.masterDurationDelete);

  List<DurationItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) => i.duration.toLowerCase().contains(_query.toLowerCase()),
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
      final items = await DurationService.instance.fetchAll();
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

  Future<void> _delete(DurationItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Duration',
      message: 'Delete "${item.duration}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await DurationService.instance.delete(item.id);
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

  Future<void> _openDialog({DurationItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DurationDialog(item: item, accentColor: widget.accentColor),
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
              Icons.hourglass_bottom_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Durations',
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
            hintText: 'Search durations...',
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
          _query.isNotEmpty
              ? 'No results'
              : (_canAdd ? 'No durations yet.' : 'No durations yet.'),
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
                    item.duration,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

class _DurationDialog extends StatefulWidget {
  final DurationItem? item;
  final Color accentColor;

  const _DurationDialog({required this.item, required this.accentColor});

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  String? _fieldErr;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item?.duration ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _ctrl.text.trim();
    if (value.isEmpty) {
      setState(() => _fieldErr = 'Required');
      return;
    }
    setState(() {
      _saving = true;
      _fieldErr = null;
    });
    try {
      final item = widget.item;
      if (item == null) {
        await DurationService.instance.create(value);
      } else {
        await DurationService.instance.update(item.id, value);
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
        title: isEdit ? 'Edit Duration' : 'Add Duration',
        colors: [widget.accentColor, widget.accentColor],
        onClose: _saving ? null : () => Navigator.pop(context, false),
      ),
      body: TextFormField(
        controller: _ctrl,
        autofocus: !isEdit,
        decoration: appFieldDecoration(
          'Duration',
          hint: 'e.g. 1 Week, 15 Days',
        ).copyWith(errorText: _fieldErr),
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
