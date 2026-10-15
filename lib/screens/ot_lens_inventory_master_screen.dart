import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_dialogs.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../services/permission_service.dart';
import '../services/ot_inventory_service.dart';
import '../models/ot_inventory_models.dart';
import '../widgets/app_animations.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';
import '../utils/app_date_picker.dart';

/// Tablet Lens Inventory master (Round 3 Phase 7) — stock-tracked lens
/// master. Ported from eye_care_app/lib/screens/ot_lens_inventory_master_screen.dart.
class OtLensInventoryMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtLensInventoryMasterScreen({super.key, required this.accentColor});

  @override
  State<OtLensInventoryMasterScreen> createState() =>
      _OtLensInventoryMasterScreenState();
}

class _OtLensInventoryMasterScreenState
    extends State<OtLensInventoryMasterScreen> {
  final _p = PermissionService.instance;
  List<LensInventoryItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  bool get _canAdd => _p.can(Perm.masterOtInventoryAdd);
  bool get _canEdit => _p.can(Perm.masterOtInventoryEdit);
  bool get _canDelete => _p.can(Perm.masterOtInventoryDelete);

  List<LensInventoryItem> get _filtered => _query.isEmpty
      ? _all
      : _all
            .where(
              (i) =>
                  i.lensName.toLowerCase().contains(_query.toLowerCase()) ||
                  i.lensCode.toLowerCase().contains(_query.toLowerCase()),
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
      final items = await OtInventoryService.instance.fetchLensInventory();
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

  Future<void> _delete(LensInventoryItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Lens Stock',
      message:
          'Delete "${item.lensName}" (${item.lensCode})? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await OtInventoryService.instance.deleteLensInventory(item.id);
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

  Color _stockColor(int stock) => stock == 0
      ? AppColors.red
      : (stock < 5 ? AppColors.orange : AppColors.green);

  Future<void> _openDialog({LensInventoryItem? item}) async {
    final codeCtrl = TextEditingController(text: item?.lensCode ?? '');
    final nameCtrl = TextEditingController(text: item?.lensName ?? '');
    final manufacturerCtrl = TextEditingController(
      text: item?.manufacturer ?? '',
    );
    final powerCtrl = TextEditingController(text: item?.power ?? '');
    final batchCtrl = TextEditingController(text: item?.batchNumber ?? '');
    final serialCtrl = TextEditingController(text: item?.serialNumber ?? '');
    final mrpCtrl = TextEditingController(
      text: item != null ? item.mrp.toStringAsFixed(2) : '',
    );
    final purchaseCostCtrl = TextEditingController(
      text: item?.purchaseCost != null
          ? item!.purchaseCost!.toStringAsFixed(2)
          : '',
    );
    final supplierCtrl = TextEditingController(text: item?.supplier ?? '');
    final stockCtrl = TextEditingController(
      text: item != null ? '${item.availableStock}' : '',
    );
    String? type = item?.type;
    DateTime? expiryDate =
        item?.expiryDate != null && item!.expiryDate!.isNotEmpty
        ? parseApiPlainDate(item.expiryDate!)
        : null;
    bool saving = false;
    String? codeErr, nameErr, typeErr, mrpErr, stockErr;

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, ss) {
          Future<void> pickExpiry() async {
            final now = DateTime.now();
            final picked = await showAppDatePicker(
              context: dCtx,
              initialDate: expiryDate ?? now,
              firstDate: now.subtract(const Duration(days: 365)),
              lastDate: now.add(const Duration(days: 365 * 10)),
            );
            if (picked != null) ss(() => expiryDate = picked);
          }

          Future<void> save() async {
            final mrp = double.tryParse(mrpCtrl.text.trim());
            final stock = int.tryParse(stockCtrl.text.trim());
            ss(() {
              codeErr = codeCtrl.text.trim().isEmpty ? 'Required' : null;
              nameErr = nameCtrl.text.trim().isEmpty ? 'Required' : null;
              typeErr = type == null ? 'Select a type' : null;
              mrpErr = mrp == null ? 'Invalid' : null;
              stockErr = stock == null || stock < 0 ? 'Invalid' : null;
            });
            if (codeErr != null ||
                nameErr != null ||
                typeErr != null ||
                mrpErr != null ||
                stockErr != null)
              return;
            ss(() => saving = true);
            try {
              final draft = LensInventoryItem(
                id: item?.id ?? 0,
                lensCode: codeCtrl.text.trim(),
                manufacturer: manufacturerCtrl.text.trim().isEmpty
                    ? null
                    : manufacturerCtrl.text.trim(),
                lensName: nameCtrl.text.trim(),
                type: type!,
                power: powerCtrl.text.trim().isEmpty
                    ? null
                    : powerCtrl.text.trim(),
                batchNumber: batchCtrl.text.trim().isEmpty
                    ? null
                    : batchCtrl.text.trim(),
                serialNumber: serialCtrl.text.trim().isEmpty
                    ? null
                    : serialCtrl.text.trim(),
                mrp: mrp!,
                purchaseCost: double.tryParse(purchaseCostCtrl.text.trim()),
                supplier: supplierCtrl.text.trim().isEmpty
                    ? null
                    : supplierCtrl.text.trim(),
                expiryDate: expiryDate == null ? null : toIsoDate(expiryDate!),
                availableStock: stock!,
              );
              if (item == null) {
                await OtInventoryService.instance.createLensInventory(draft);
              } else {
                await OtInventoryService.instance.updateLensInventory(
                  item.id,
                  draft,
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
              title: item == null ? 'Add Lens Stock' : 'Edit Lens Stock',
              colors: [widget.accentColor, widget.accentColor],
              onClose: saving ? null : () => Navigator.pop(dCtx),
            ),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: appFieldDecoration(
                        'SKU / Lens Code *',
                      ).copyWith(errorText: codeErr),
                    ),
                    TextFormField(
                      controller: manufacturerCtrl,
                      decoration: appFieldDecoration('Manufacturer'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: nameCtrl,
                  decoration: appFieldDecoration(
                    'Lens Name *',
                  ).copyWith(errorText: nameErr),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: appFieldDecoration(
                    'Lens Type *',
                  ).copyWith(errorText: typeErr),
                  items: kOtLensTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => ss(() => type = v),
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: powerCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: appFieldDecoration('Power', hint: 'D'),
                    ),
                    TextFormField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: appFieldDecoration(
                        'Available Stock *',
                      ).copyWith(errorText: stockErr),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: batchCtrl,
                      decoration: appFieldDecoration('Batch Number'),
                    ),
                    TextFormField(
                      controller: serialCtrl,
                      decoration: appFieldDecoration('Serial Number'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: mrpCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration('MRP *').copyWith(
                        errorText: mrpErr,
                        prefixText: currentCurrencySymbol(),
                      ),
                    ),
                    TextFormField(
                      controller: purchaseCostCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: numFmt,
                      decoration: appFieldDecoration(
                        'Purchase Cost',
                      ).copyWith(prefixText: currentCurrencySymbol()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppFormRow(
                  children: [
                    TextFormField(
                      controller: supplierCtrl,
                      decoration: appFieldDecoration('Supplier'),
                    ),
                    InkWell(
                      onTap: pickExpiry,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: appFieldDecoration(
                          'Expiry Date',
                          suffix: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                        ),
                        child: Text(
                          expiryDate == null
                              ? 'Select date (optional)'
                              : toDisplayDate(expiryDate!),
                        ),
                      ),
                    ),
                  ],
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
        codeCtrl,
        nameCtrl,
        manufacturerCtrl,
        powerCtrl,
        batchCtrl,
        serialCtrl,
        mrpCtrl,
        purchaseCostCtrl,
        supplierCtrl,
        stockCtrl,
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
              Icons.inventory_2_rounded,
              color: widget.accentColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Lens Inventory',
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
            hintText: 'Search by name or SKU...',
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
          _query.isNotEmpty ? 'No results' : 'No lens stock yet.',
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
                        item.lensName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.lensCode} · ${item.type}${item.power != null && item.power!.isNotEmpty ? ' · ${item.power}D' : ''} · MRP ${currentCurrencySymbol()}${item.mrp.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11.5,
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
                    color: _stockColor(
                      item.availableStock,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${item.availableStock} in stock',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _stockColor(item.availableStock),
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
