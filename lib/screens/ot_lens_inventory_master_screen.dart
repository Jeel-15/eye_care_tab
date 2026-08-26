import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/ot_inventory_service.dart';
import '../models/ot_inventory_models.dart';
import '../widgets/app_animations.dart';

/// Tablet Lens Inventory master (Round 3 Phase 7) — stock-tracked lens
/// master. Ported from eye_care_app/lib/screens/ot_lens_inventory_master_screen.dart.
class OtLensInventoryMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtLensInventoryMasterScreen({super.key, required this.accentColor});

  @override
  State<OtLensInventoryMasterScreen> createState() => _OtLensInventoryMasterScreenState();
}

class _OtLensInventoryMasterScreenState extends State<OtLensInventoryMasterScreen> {
  List<LensInventoryItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<LensInventoryItem> get _filtered => _query.isEmpty
      ? _all
      : _all.where((i) => i.lensName.toLowerCase().contains(_query.toLowerCase()) || i.lensCode.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await OtInventoryService.instance.fetchLensInventory();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _delete(LensInventoryItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.lensName}" (${item.lensCode})?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await OtInventoryService.instance.deleteLensInventory(item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Color _stockColor(int stock) => stock == 0 ? AppColors.red : (stock < 5 ? AppColors.orange : AppColors.green);

  Future<void> _openDialog({LensInventoryItem? item}) async {
    final codeCtrl = TextEditingController(text: item?.lensCode ?? '');
    final nameCtrl = TextEditingController(text: item?.lensName ?? '');
    final manufacturerCtrl = TextEditingController(text: item?.manufacturer ?? '');
    final powerCtrl = TextEditingController(text: item?.power ?? '');
    final batchCtrl = TextEditingController(text: item?.batchNumber ?? '');
    final serialCtrl = TextEditingController(text: item?.serialNumber ?? '');
    final mrpCtrl = TextEditingController(text: item != null ? item.mrp.toStringAsFixed(2) : '');
    final purchaseCostCtrl = TextEditingController(text: item?.purchaseCost != null ? item!.purchaseCost!.toStringAsFixed(2) : '');
    final supplierCtrl = TextEditingController(text: item?.supplier ?? '');
    final stockCtrl = TextEditingController(text: item != null ? '${item.availableStock}' : '');
    String? type = item?.type;
    DateTime? expiryDate = item?.expiryDate != null && item!.expiryDate!.isNotEmpty ? DateTime.tryParse(item.expiryDate!) : null;
    bool saving = false;
    String? codeErr, nameErr, typeErr, mrpErr, stockErr;

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> pickExpiry() async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: dCtx, initialDate: expiryDate ?? now, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 365 * 10)));
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
        if (codeErr != null || nameErr != null || typeErr != null || mrpErr != null || stockErr != null) return;
        ss(() => saving = true);
        try {
          final draft = LensInventoryItem(
            id: item?.id ?? 0,
            lensCode: codeCtrl.text.trim(),
            manufacturer: manufacturerCtrl.text.trim().isEmpty ? null : manufacturerCtrl.text.trim(),
            lensName: nameCtrl.text.trim(),
            type: type!,
            power: powerCtrl.text.trim().isEmpty ? null : powerCtrl.text.trim(),
            batchNumber: batchCtrl.text.trim().isEmpty ? null : batchCtrl.text.trim(),
            serialNumber: serialCtrl.text.trim().isEmpty ? null : serialCtrl.text.trim(),
            mrp: mrp!,
            purchaseCost: double.tryParse(purchaseCostCtrl.text.trim()),
            supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
            expiryDate: expiryDate == null ? null : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
            availableStock: stock!,
          );
          if (item == null) {
            await OtInventoryService.instance.createLensInventory(draft);
          } else {
            await OtInventoryService.instance.updateLensInventory(item.id, draft);
          }
          if (mounted) Navigator.pop(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }

      final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add Lens Stock' : 'Edit Lens Stock'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextFormField(controller: codeCtrl, decoration: InputDecoration(labelText: 'SKU / Lens Code *', errorText: codeErr, border: const OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: manufacturerCtrl, decoration: const InputDecoration(labelText: 'Manufacturer', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Lens Name *', errorText: nameErr, border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: type, isExpanded: true, decoration: InputDecoration(labelText: 'Lens Type *', errorText: typeErr, border: const OutlineInputBorder()), items: kOtLensTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => ss(() => type = v)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: powerCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Power', suffixText: 'D', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: stockCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Available Stock *', errorText: stockErr, border: const OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: batchCtrl, decoration: const InputDecoration(labelText: 'Batch Number', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: serialCtrl, decoration: const InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: mrpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: InputDecoration(labelText: 'MRP *', errorText: mrpErr, prefixText: '₹', border: const OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: purchaseCostCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: const InputDecoration(labelText: 'Purchase Cost', prefixText: '₹', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              InkWell(
                onTap: pickExpiry,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expiry Date', border: OutlineInputBorder()),
                  child: Text(expiryDate == null ? 'Select date (optional)' : '${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    for (final c in [codeCtrl, nameCtrl, manufacturerCtrl, powerCtrl, batchCtrl, serialCtrl, mrpCtrl, purchaseCostCtrl, supplierCtrl, stockCtrl]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.inventory_2_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Lens Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search by name or SKU...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results' : 'No lens stock yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.lensName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${item.lensCode} · ${item.type}${item.power != null && item.power!.isNotEmpty ? ' · ${item.power}D' : ''} · MRP ₹${item.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _stockColor(item.availableStock).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Text('${item.availableStock} in stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _stockColor(item.availableStock)))),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
          ]),
        );
      },
    );
  }
}
