import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../services/ot_inventory_service.dart';
import '../models/ot_inventory_models.dart';
import '../widgets/app_animations.dart';
import '../utils/currency_format.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Tablet OT Packages master (Round 3 Phase 7) — feeds Phase 1's
/// counselling package-lookup. Ported from
/// eye_care_app/lib/screens/ot_package_master_screen.dart.
class OtPackageMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtPackageMasterScreen({super.key, required this.accentColor});

  @override
  State<OtPackageMasterScreen> createState() => _OtPackageMasterScreenState();
}

class _OtPackageMasterScreenState extends State<OtPackageMasterScreen> {
  final _p = PermissionService.instance;
  List<OtPackageMasterItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterOtPackageAdd);
  bool get _canEdit => _p.can(Perm.masterOtPackageEdit);
  bool get _canDelete => _p.can(Perm.masterOtPackageDelete);

  List<OtPackageMasterItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) => i.packageName.toLowerCase().contains(_query.toLowerCase()),
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
      final items = await OtInventoryService.instance.fetchPackages();
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

  Future<void> _delete(OtPackageMasterItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Package',
      message: 'Delete "${item.packageName}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await OtInventoryService.instance.deletePackage(item.id);
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

  Future<void> _openDialog({OtPackageMasterItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.packageName ?? '');
    final otCtrl = TextEditingController(
      text: item != null ? item.otCharges.toStringAsFixed(2) : '0',
    );
    final surgeonCtrl = TextEditingController(
      text: item != null ? item.surgeonCharges.toStringAsFixed(2) : '0',
    );
    final nursingCtrl = TextEditingController(
      text: item != null ? item.nursingCharges.toStringAsFixed(2) : '0',
    );
    final consumablesCtrl = TextEditingController(
      text: item != null ? item.consumablesCharges.toStringAsFixed(2) : '0',
    );
    String roomCategory = item?.roomCategory ?? 'general';
    // Web's Add-Package form has an "Active" checkbox checked by default —
    // without sending this, the API silently defaults new packages to
    // inactive, which is why they never showed up in the Counselling form's
    // package dropdown (that dropdown only lists is_active=true rows).
    bool isActive = item?.isActive ?? true;
    bool saving = false;
    String? nameErr;

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, ss) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              ss(() => nameErr = 'Required');
              return;
            }
            ss(() {
              saving = true;
              nameErr = null;
            });
            try {
              final otCharges = double.tryParse(otCtrl.text.trim()) ?? 0;
              final surgeonCharges =
                  double.tryParse(surgeonCtrl.text.trim()) ?? 0;
              final nursingCharges =
                  double.tryParse(nursingCtrl.text.trim()) ?? 0;
              final consumablesCharges =
                  double.tryParse(consumablesCtrl.text.trim()) ?? 0;
              if (item == null) {
                await OtInventoryService.instance.createPackage(
                  packageName: name,
                  roomCategory: roomCategory,
                  otCharges: otCharges,
                  surgeonCharges: surgeonCharges,
                  nursingCharges: nursingCharges,
                  consumablesCharges: consumablesCharges,
                  isActive: isActive,
                );
              } else {
                await OtInventoryService.instance.updatePackage(
                  item.id,
                  packageName: name,
                  roomCategory: roomCategory,
                  otCharges: otCharges,
                  surgeonCharges: surgeonCharges,
                  nursingCharges: nursingCharges,
                  consumablesCharges: consumablesCharges,
                  isActive: isActive,
                );
              }
              if (mounted) Navigator.pop(dCtx);
              await _load();
            } catch (e) {
              ss(() => saving = false);
              if (mounted)
                showAppSnackBar(
                  context,
                  e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
            }
          }

          final numFmt = [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ];
          return AppDialog(
            size: AppDialogSize.medium,
            header: AppDialogHeader(
              icon: item == null ? Icons.add_rounded : Icons.edit_outlined,
              title: item == null ? 'Add Package' : 'Edit Package',
              colors: [widget.accentColor, widget.accentColor],
              onClose: saving ? null : () => Navigator.pop(dCtx),
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: appFieldDecoration(
                    'Package Name *',
                  ).copyWith(errorText: nameErr),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('General'),
                        selected: roomCategory == 'general',
                        onSelected: (_) => ss(() => roomCategory = 'general'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Private'),
                        selected: roomCategory == 'private',
                        onSelected: (_) => ss(() => roomCategory = 'private'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: otCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration(
                        'OT Charges',
                      ).copyWith(prefixText: currentCurrencySymbol()),
                    ),
                    TextFormField(
                      controller: surgeonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration(
                        'Surgeon Charges',
                      ).copyWith(prefixText: currentCurrencySymbol()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: nursingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration(
                        'Nursing Charges',
                      ).copyWith(prefixText: currentCurrencySymbol()),
                    ),
                    TextFormField(
                      controller: consumablesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration(
                        'Consumables',
                      ).copyWith(prefixText: currentCurrencySymbol()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppSwitchTile(
                  label: 'Active',
                  value: isActive,
                  color: widget.accentColor,
                  onChanged: (v) => ss(() => isActive = v),
                ),
              ],
            ),
            actions: [
              AppSecondaryButton(
                onPressed: saving ? null : () => Navigator.pop(dCtx),
              ),
              AppPrimaryButton(
                label: 'Save',
                color: widget.accentColor,
                loading: saving,
                onPressed: save,
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [
        nameCtrl,
        otCtrl,
        surgeonCtrl,
        nursingCtrl,
        consumablesCtrl,
      ]) {
        c.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'OT Packages',
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
            hintText: 'Search packages...',
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
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 80);
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
          _query.isNotEmpty ? 'No results' : 'No packages yet.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.packageName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Total ${currentCurrencySymbol()}${item.totalPreview.toStringAsFixed(0)}  ·  OT ${currentCurrencySymbol()}${item.otCharges.toStringAsFixed(0)} · Surgeon ${currentCurrencySymbol()}${item.surgeonCharges.toStringAsFixed(0)} · Nursing ${currentCurrencySymbol()}${item.nursingCharges.toStringAsFixed(0)} · Consumables ${currentCurrencySymbol()}${item.consumablesCharges.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    item.roomCategory == 'private' ? 'Private' : 'General',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (item.isActive
                                ? AppColors.green
                                : AppColors.textDisabled)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    item.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
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
