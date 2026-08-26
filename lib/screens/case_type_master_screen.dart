import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/case_type_service.dart';
import '../widgets/app_animations.dart';

/// Tablet Case Types master — name + fee. Embedded as a Masters hub detail
/// pane. Ported from eye_care_app/lib/screens/case_type_master_screen.dart.
class CaseTypeMasterScreen extends StatefulWidget {
  final Color accentColor;
  const CaseTypeMasterScreen({super.key, required this.accentColor});

  @override
  State<CaseTypeMasterScreen> createState() => _CaseTypeMasterScreenState();
}

class _CaseTypeMasterScreenState extends State<CaseTypeMasterScreen> {
  List<CaseTypeItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<CaseTypeItem> get _filtered => _query.isEmpty ? _all : _all.where((i) => i.caseType.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await CaseTypeService.instance.fetchAll();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _delete(CaseTypeItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.caseType}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await CaseTypeService.instance.delete(item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openDialog({CaseTypeItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.caseType ?? '');
    final feeCtrl = TextEditingController(text: item != null ? (item.caseFee == item.caseFee.toInt() ? item.caseFee.toInt().toString() : item.caseFee.toString()) : '');
    bool saving = false;
    String? nameErr, feeErr;

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        final name = nameCtrl.text.trim();
        final fee = double.tryParse(feeCtrl.text.trim());
        if (name.isEmpty) { ss(() => nameErr = 'Required'); return; }
        if (fee == null) { ss(() => feeErr = 'Invalid fee'); return; }
        ss(() { saving = true; nameErr = null; feeErr = null; });
        try {
          if (item == null) {
            await CaseTypeService.instance.create(name, fee);
          } else {
            await CaseTypeService.instance.update(item.id, name, fee);
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
        title: Text(item == null ? 'Add Case Type' : 'Edit Case Type'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, autofocus: true, decoration: InputDecoration(labelText: 'Case Type', errorText: nameErr, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Case Fee (₹)', errorText: feeErr, border: const OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    nameCtrl.dispose();
    feeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.folder_open_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Case Types', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search case types...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results' : 'No case types yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Expanded(child: Text(item.caseType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            Text('₹${item.caseFee.toInt()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.accentColor)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
          ]),
        );
      },
    );
  }
}
