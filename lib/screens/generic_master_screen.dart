import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/simple_master_service.dart';
import '../widgets/app_animations.dart';

/// Tablet generic master editor — Pattern A (list, inline add/edit dialog).
/// Covers every simple {value, is_favourite, is_seeded} master (~26 types:
/// complaints, kcos, hno, diagnoses, advices, vn/pnvn/nrvn, sph_cyl, axis,
/// nct, sac/lid/conj/cornea/ac/iris/pupil/lens/em/covertest, disc/fr,
/// durations, lens-options, ot-types). Embedded as the Masters hub's detail
/// pane (no own Scaffold) — ported from
/// eye_care_app/lib/screens/generic_master_screen.dart.
class GenericMasterScreen extends StatefulWidget {
  final String title;
  final String apiPath;
  final Color accentColor;
  final IconData icon;
  final bool hasFavourite;
  final bool hasSeeded;

  const GenericMasterScreen({
    super.key,
    required this.title,
    required this.apiPath,
    required this.accentColor,
    this.icon = Icons.list_rounded,
    this.hasFavourite = false,
    this.hasSeeded = false,
  });

  @override
  State<GenericMasterScreen> createState() => _GenericMasterScreenState();
}

class _GenericMasterScreenState extends State<GenericMasterScreen> {
  List<SimpleMasterItem> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';

  List<SimpleMasterItem> get _filtered => _query.isEmpty ? _all : _all.where((i) => i.value.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GenericMasterScreen old) {
    super.didUpdateWidget(old);
    if (old.apiPath != widget.apiPath) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await SimpleMasterService.instance.fetchAll(widget.apiPath);
      if (mounted) setState(() { _all = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _toggleFav(SimpleMasterItem item) async {
    try {
      final newFav = await SimpleMasterService.instance.toggleFavourite(widget.apiPath, item.id);
      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((i) => i.id == item.id);
        if (idx != -1) _all[idx] = item.copyWith(isFavourite: newFav);
        _all.sort((a, b) => a.isFavourite == b.isFavourite ? a.value.compareTo(b.value) : (a.isFavourite ? -1 : 1));
      });
    } catch (_) {}
  }

  Future<void> _delete(SimpleMasterItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete "${item.value}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await SimpleMasterService.instance.delete(widget.apiPath, item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openDialog({SimpleMasterItem? item}) async {
    final ctrl = TextEditingController(text: item?.value ?? '');
    bool fav = item?.isFavourite ?? false;
    bool saving = false;
    String? fieldError;

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
        Future<void> save() async {
          final v = ctrl.text.trim();
          if (v.isEmpty) { ss(() => fieldError = 'Value is required'); return; }
          ss(() { saving = true; fieldError = null; });
          try {
            if (item == null) {
              await SimpleMasterService.instance.create(widget.apiPath, v, isFavourite: fav);
            } else {
              await SimpleMasterService.instance.update(widget.apiPath, item.id, v, isFavourite: fav);
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
          title: Text(item == null ? 'Add ${widget.title}' : 'Edit ${widget.title}'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: 'Value', errorText: fieldError, border: const OutlineInputBorder())),
              if (widget.hasFavourite)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as Favourite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: fav,
                  onChanged: (v) => ss(() => fav = v),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
          ],
        );
      }),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(widget.icon, color: widget.accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
        ]),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(hintText: 'Search ${widget.title.toLowerCase()}...', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: AppColors.background, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return Center(child: CircularProgressIndicator(color: widget.accentColor));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 44, color: AppColors.red.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white)),
        ]),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Text(_query.isNotEmpty ? 'No results for "$_query"' : 'No ${widget.title.toLowerCase()} yet. Tap Add to create one.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDisabled)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Row(children: [
            Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: widget.accentColor))),
            const SizedBox(width: 12),
            Expanded(child: Text(item.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            if (widget.hasFavourite) IconButton(icon: Icon(item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: item.isFavourite ? AppColors.orange : const Color(0xFFCBD5E1)), onPressed: () => _toggleFav(item)),
            if (item.isSeeded)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textDisabled))
            else ...[
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _delete(item)),
            ],
          ]),
        );
      },
    );
  }
}
