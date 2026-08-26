import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/ot_charge_head_service.dart';
import '../widgets/app_animations.dart';

/// Tablet OT Charge Heads master — name + percentage + active toggle.
/// Ported from eye_care_app/lib/screens/ot_charge_head_master_screen.dart.
class OtChargeHeadMasterScreen extends StatefulWidget {
  final Color accentColor;
  const OtChargeHeadMasterScreen({super.key, required this.accentColor});

  @override
  State<OtChargeHeadMasterScreen> createState() => _OtChargeHeadMasterScreenState();
}

class _OtChargeHeadMasterScreenState extends State<OtChargeHeadMasterScreen> {
  List<OtChargeHeadItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<OtChargeHeadItem> get _filtered => _query.isEmpty ? _all : _all.where((i) => i.chargeName.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await OtChargeHeadService.instance.fetchAll();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _delete(OtChargeHeadItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.chargeName}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await OtChargeHeadService.instance.delete(item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openDialog({OtChargeHeadItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.chargeName ?? '');
    final pctCtrl = TextEditingController(text: item != null ? (item.percentage == item.percentage.toInt() ? item.percentage.toInt().toString() : item.percentage.toString()) : '');
    bool active = item?.isActive ?? true;
    bool saving = false;
    String? nameErr, pctErr;

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        final name = nameCtrl.text.trim();
        final pct = double.tryParse(pctCtrl.text.trim());
        if (name.isEmpty) { ss(() => nameErr = 'Required'); return; }
        if (pct == null) { ss(() => pctErr = 'Invalid'); return; }
        ss(() { saving = true; nameErr = null; pctErr = null; });
        try {
          if (item == null) {
            await OtChargeHeadService.instance.create(name, pct, active);
          } else {
            await OtChargeHeadService.instance.update(item.id, name, pct, active);
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
        title: Text(item == null ? 'Add Charge Head' : 'Edit Charge Head'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, autofocus: true, decoration: InputDecoration(labelText: 'Charge Name', errorText: nameErr, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: pctCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Percentage (%)', errorText: pctErr, border: const OutlineInputBorder())),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), value: active, onChanged: (v) => ss(() => active = v)),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    nameCtrl.dispose();
    pctCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.payments_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('OT Charge Heads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search charge heads...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results' : 'No charge heads yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Expanded(child: Text(item.chargeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (!item.isActive) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.redA70.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: const Text('Inactive', style: TextStyle(fontSize: 9, color: AppColors.red, fontWeight: FontWeight.w700))),
            Text('${item.percentage.toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.accentColor)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
          ]),
        );
      },
    );
  }
}
