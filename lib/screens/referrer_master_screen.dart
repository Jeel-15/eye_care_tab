import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/masters_service.dart';
import '../services/referrer_service.dart';
import '../widgets/app_animations.dart';

/// Tablet Referrers master — name + contact. Ported from
/// eye_care_app/lib/screens/referrer_master_screen.dart.
class ReferrerMasterScreen extends StatefulWidget {
  final Color accentColor;
  const ReferrerMasterScreen({super.key, required this.accentColor});

  @override
  State<ReferrerMasterScreen> createState() => _ReferrerMasterScreenState();
}

class _ReferrerMasterScreenState extends State<ReferrerMasterScreen> {
  List<ReferrerItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<ReferrerItem> get _filtered => _query.isEmpty ? _all : _all.where((i) => i.name.toLowerCase().contains(_query.toLowerCase()) || (i.contact ?? '').contains(_query)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ReferrerService.instance.fetchAll();
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _delete(ReferrerItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await ReferrerService.instance.delete(item.id);
      MastersService.instance.clearCache();
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openDialog({ReferrerItem? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final contactCtrl = TextEditingController(text: item?.contact ?? '');
    bool saving = false;
    String? nameErr;

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) { ss(() => nameErr = 'Required'); return; }
        ss(() { saving = true; nameErr = null; });
        try {
          final contact = contactCtrl.text.trim();
          if (item == null) {
            await ReferrerService.instance.create(name, contact.isEmpty ? null : contact);
          } else {
            await ReferrerService.instance.update(item.id, name, contact.isEmpty ? null : contact);
          }
          MastersService.instance.clearCache();
          if (mounted) Navigator.pop(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add Referrer' : 'Edit Referrer'),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, autofocus: true, decoration: InputDecoration(labelText: 'Name', errorText: nameErr, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: contactCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact (optional)', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    nameCtrl.dispose();
    contactCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.people_alt_rounded, color: widget.accentColor, size: 20),
        const SizedBox(width: 10),
        const Expanded(child: Text('Referrers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => _query = v.trim()), decoration: InputDecoration(hintText: 'Search referrers...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none))),
      const SizedBox(height: 12),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    final items = _filtered;
    if (items.isEmpty) return Center(child: Text(_query.isNotEmpty ? 'No results' : 'No referrers yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (item.contact != null && item.contact!.isNotEmpty) Text(item.contact!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
          ]),
        );
      },
    );
  }
}
