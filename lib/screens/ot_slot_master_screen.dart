import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/masters_service.dart';
import '../services/permission_service.dart';
import '../services/ot_slot_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet OT Slots master — name + start/end time (H:i via time picker).
class OtSlotMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtSlotMasterScreen({super.key, required this.accentColor});

  @override
  State<OtSlotMasterScreen> createState() => _OtSlotMasterScreenState();
}

class _OtSlotMasterScreenState extends State<OtSlotMasterScreen> {
  final _p = PermissionService.instance;
  List<OtSlotItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterOtSlotAdd);
  bool get _canEdit => _p.can(Perm.masterOtSlotEdit);
  bool get _canDelete => _p.can(Perm.masterOtSlotDelete);

  List<OtSlotItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) => i.slotName.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

  static String _fmt(String? t) {
    if (t == null || t.isEmpty) return '--:--';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

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
      final items = await OtSlotService.instance.fetchAll();
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

  Future<void> _delete(OtSlotItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete OT Slot',
      message: 'Delete "${item.slotName}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await OtSlotService.instance.delete(item.id);
      // MastersService's in-memory slot list (used by the OT Appointment/
      // Patient forms' slot dropdown) only refetches when empty — without
      // this it kept showing deleted/stale slots for the rest of the app
      // session, fixed only by a full app restart.
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

  Future<void> _openDialog({OtSlotItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _OtSlotDialog(item: item, accentColor: widget.accentColor),
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
            Icon(Icons.schedule_rounded, color: widget.accentColor, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'OT Slots',
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
            hintText: 'Search slots...',
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
          _query.isNotEmpty ? 'No results' : 'No OT slots yet.',
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
          final time = '${_fmt(item.startTime)} – ${_fmt(item.endTime)}';
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
                    item.slotName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _OtSlotDialog extends StatefulWidget {
  final OtSlotItem? item;
  final Color accentColor;

  const _OtSlotDialog({required this.item, required this.accentColor});

  @override
  State<_OtSlotDialog> createState() => _OtSlotDialogState();
}

class _OtSlotDialogState extends State<_OtSlotDialog> {
  late final TextEditingController _nameCtrl;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;
  String? _nameErr;
  String? _startErr;
  String? _endErr;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.slotName ?? '');
    _startTime = _parseTime(widget.item?.startTime);
    _endTime = _parseTime(widget.item?.endTime);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _toHHMM(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _startErr = null;
        } else {
          _endTime = picked;
          _endErr = null;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final startMin = _startTime != null
        ? _startTime!.hour * 60 + _startTime!.minute
        : null;
    final endMin = _endTime != null
        ? _endTime!.hour * 60 + _endTime!.minute
        : null;
    setState(() {
      _nameErr = name.isEmpty ? 'Required' : null;
      _startErr = _startTime == null ? 'Start time required' : null;
      _endErr = _endTime == null
          ? 'End time required'
          : (endMin != null && startMin != null && endMin <= startMin)
          ? 'End must be after start'
          : null;
    });
    if (_nameErr != null || _startErr != null || _endErr != null) return;

    setState(() => _saving = true);
    try {
      final start = _toHHMM(_startTime!);
      final end = _toHHMM(_endTime!);
      final item = widget.item;
      if (item == null) {
        await OtSlotService.instance.create(name, start, end);
      } else {
        await OtSlotService.instance.update(item.id, name, start, end);
      }
      MastersService.instance.clearCache();
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

  Widget _timeField({
    required String label,
    required TimeOfDay? value,
    required String? error,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: appFieldDecoration(
          label,
          suffix: const Icon(Icons.schedule_rounded, size: 18),
        ).copyWith(errorText: error),
        child: Text(
          value == null ? 'Select' : _toHHMM(value),
          style: TextStyle(
            fontSize: 14,
            color: value == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: isEdit ? Icons.edit_outlined : Icons.add_rounded,
        title: isEdit ? 'Edit OT Slot' : 'Add OT Slot',
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
              'Slot Name',
            ).copyWith(errorText: _nameErr),
          ),
          const SizedBox(height: 14),
          AppFormRow(
            children: [
              _timeField(
                label: 'Start',
                value: _startTime,
                error: _startErr,
                onTap: () => _pickTime(true),
              ),
              _timeField(
                label: 'End',
                value: _endTime,
                error: _endErr,
                onTap: () => _pickTime(false),
              ),
            ],
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
