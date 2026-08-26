import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/ot_inventory_service.dart';
import '../models/ot_inventory_models.dart';
import '../widgets/app_animations.dart';

/// Tablet Lens Powers master (Round 3 Phase 7).
/// Ported from eye_care_app/lib/screens/ot_lens_power_master_screen.dart.
class OtLensPowerMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtLensPowerMasterScreen({super.key, required this.accentColor});

  @override
  State<OtLensPowerMasterScreen> createState() => _OtLensPowerMasterScreenState();
}

class _OtLensPowerMasterScreenState extends State<OtLensPowerMasterScreen> {
  List<LensPowerItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<LensPowerItem> get _filtered => _query.isEmpty ? _all : _all.where((i) => i.value.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await OtInventoryService.instance.fetchLensPowers();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _delete(LensPowerItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.value}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await OtInventoryService.instance.deleteLensPower(item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openDialog({LensPowerItem? item}) async {
    final valueCtrl = TextEditingController(text: item?.value ?? '');
    bool isFavourite = item?.isFavourite ?? false;
    bool saving = false;
    String? valueErr;

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        final value = valueCtrl.text.trim();
        if (value.isEmpty) { ss(() => valueErr = 'Required'); return; }
        ss(() { saving = true; valueErr = null; });
        try {
          if (item == null) {
            await OtInventoryService.instance.createLensPower(value, isFavourite);
          } else {
            await OtInventoryService.instance.updateLensPower(item.id, value, isFavourite);
          }
          if (mounted) Navigator.pop(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add Lens Power' : 'Edit Lens Power'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: valueCtrl, decoration: InputDecoration(labelText: 'Power (e.g. +10.0D)', errorText: valueErr, border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          SwitchListTile(value: isFavourite, onChanged: (v) => ss(() => isFavourite = v), activeThumbColor: Colors.amber, title: const Text('Favourite'), contentPadding: EdgeInsets.zero),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    valueCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.lens_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Lens Powers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search lens powers...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results' : 'No lens powers yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            if (item.isFavourite) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.star_rounded, size: 16, color: Colors.amber)),
            Expanded(child: Text(item.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
          ]),
        );
      },
    );
  }
}
