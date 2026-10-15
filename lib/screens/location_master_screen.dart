import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/location_service.dart';
import '../services/masters_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet Locations master — city/district/state, full add/edit/delete.
/// Was previously hardcoded read-only under the mistaken assumption this
/// data is platform-managed; web (Hospital\Master\BasicMasterController)
/// has always let a Hospital Admin manage it. See
/// OT_BUGS_ROUND4_FIX_PLAN.md "Locations master read-only" follow-up.
/// Ported from eye_care_app/lib/screens/location_master_screen.dart.
class LocationMasterScreen extends StatefulWidget {
  final Color accentColor;
  const LocationMasterScreen({super.key, required this.accentColor});

  @override
  State<LocationMasterScreen> createState() => _LocationMasterScreenState();
}

class _LocationMasterScreenState extends State<LocationMasterScreen> {
  final _p = PermissionService.instance;
  List<LocationItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterLocationAdd);
  bool get _canEdit => _p.can(Perm.masterLocationEdit);
  bool get _canDelete => _p.can(Perm.masterLocationDelete);

  List<LocationItem> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where(
          (i) =>
              i.city.toLowerCase().contains(q) ||
              (i.district ?? '').toLowerCase().contains(q) ||
              (i.state ?? '').toLowerCase().contains(q),
        )
        .toList();
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
      final items = await LocationService.instance.fetchAll();
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

  Future<void> _delete(LocationItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Location',
      message: 'Delete "${item.city}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await LocationService.instance.delete(item.id);
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

  Future<void> _openDialog({LocationItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _LocationDialog(item: item, accentColor: widget.accentColor),
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
              Icons.location_on_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Locations',
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
            hintText: 'Search city, district, or state...',
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _query.isNotEmpty
                ? '${_filtered.length} of ${_all.length} locations'
                : '${_all.length} locations',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 70);
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
          _query.isNotEmpty ? 'No results for "$_query"' : 'No locations yet.',
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryA08),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.city,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.subtitle.isNotEmpty)
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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
            ),
          );
        },
      ),
    );
  }
}

class _LocationDialog extends StatefulWidget {
  final LocationItem? item;
  final Color accentColor;

  const _LocationDialog({required this.item, required this.accentColor});

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _stateCtrl;
  bool _saving = false;
  String? _cityErr;
  String? _stateErr;

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.item?.city ?? '');
    _districtCtrl = TextEditingController(text: widget.item?.district ?? '');
    _stateCtrl = TextEditingController(text: widget.item?.state ?? '');
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    setState(() {
      _cityErr = city.isEmpty ? 'Required' : null;
      _stateErr = state.isEmpty ? 'Required' : null;
    });
    if (_cityErr != null || _stateErr != null) return;

    setState(() => _saving = true);
    try {
      final district = _districtCtrl.text.trim();
      final item = widget.item;
      if (item == null) {
        await LocationService.instance.create(
          city: city,
          state: state,
          district: district.isEmpty ? null : district,
        );
      } else {
        await LocationService.instance.update(
          item.id,
          city: city,
          state: state,
          district: district.isEmpty ? null : district,
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
        title: isEdit ? 'Edit Location' : 'Add Location',
        colors: [widget.accentColor, widget.accentColor],
        onClose: _saving ? null : () => Navigator.pop(context, false),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _cityCtrl,
            autofocus: !isEdit,
            decoration: appFieldDecoration(
              'City *',
            ).copyWith(errorText: _cityErr),
          ),
          const SizedBox(height: 14),
          AppFormRow(
            children: [
              TextFormField(
                controller: _districtCtrl,
                decoration: appFieldDecoration('District (optional)'),
              ),
              TextFormField(
                controller: _stateCtrl,
                decoration: appFieldDecoration(
                  'State *',
                ).copyWith(errorText: _stateErr),
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
