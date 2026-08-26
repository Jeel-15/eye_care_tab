import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../services/exam_masters_service.dart';

/// Searchable master-value picker used for Vision/Axis/NCT (plain list/grid,
/// no favourites split) and O/E + Fundus fields (Favourites/All split with a
/// ☆ toggle). Content-only widget — show it via `PopoverController.show`.
class MasterListPopover extends StatefulWidget {
  final List<ExamMasterItem> items;
  final String title;
  final String current;
  final bool showFavourites;
  final bool grid;
  final void Function(String value) onSelect;
  final Future<bool> Function(ExamMasterItem item)? onToggleFavourite; // returns new isFavourite
  final VoidCallback onClose;

  const MasterListPopover({
    super.key,
    required this.items,
    required this.title,
    required this.current,
    required this.onSelect,
    required this.onClose,
    this.showFavourites = false,
    this.grid = false,
    this.onToggleFavourite,
  });

  @override
  State<MasterListPopover> createState() => _MasterListPopoverState();
}

class _MasterListPopoverState extends State<MasterListPopover> {
  String _query = '';
  late List<ExamMasterItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  Future<void> _toggle(ExamMasterItem item) async {
    if (widget.onToggleFavourite == null) return;
    final newFav = await widget.onToggleFavourite!(item);
    setState(() {
      final idx = _items.indexWhere((e) => e.id == item.id);
      if (idx >= 0) _items[idx] = ExamMasterItem(id: item.id, value: item.value, isFavourite: newFav);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty ? _items : _items.where((i) => i.value.toLowerCase().contains(_query.toLowerCase())).toList();
    final favs = widget.showFavourites ? filtered.where((i) => i.isFavourite).toList() : <ExamMasterItem>[];
    final others = widget.showFavourites ? filtered.where((i) => !i.isFavourite).toList() : filtered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(children: [
            Expanded(child: Text(widget.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
            if (widget.current.isNotEmpty)
              GestureDetector(onTap: () { widget.onSelect(''); widget.onClose(); }, child: Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w700))),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.close_rounded, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: widget.onClose),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA18)),
            ),
          ),
        ),
        Flexible(
          child: widget.grid ? _buildGrid(filtered) : _buildList(favs, others),
        ),
      ],
    );
  }

  Widget _buildGrid(List<ExamMasterItem> items) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No results', style: TextStyle(fontSize: 12))));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1.4),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          final sel = it.value == widget.current;
          return GestureDetector(
            onTap: () { widget.onSelect(it.value); widget.onClose(); },
            child: Container(
              decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: sel ? AppColors.primary : Colors.grey.shade300)),
              alignment: Alignment.center,
              child: Text(it.value, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : AppColors.primary)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<ExamMasterItem> favs, List<ExamMasterItem> others) {
    if (favs.isEmpty && others.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No results', style: TextStyle(fontSize: 12))));
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (favs.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(12, 2, 12, 2), child: Text('★ Favourites', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade700))),
          ...favs.map(_tile),
          const Divider(height: 1),
        ],
        if (others.isNotEmpty) ...[
          if (widget.showFavourites) Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 2), child: Text('All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA50))),
          ...others.map(_tile),
        ],
      ],
    );
  }

  Widget _tile(ExamMasterItem item) {
    final sel = item.value == widget.current;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      tileColor: sel ? AppColors.primaryA08 : null,
      title: Text(item.value, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? AppColors.primary : null)),
      trailing: widget.onToggleFavourite != null
          ? IconButton(
              icon: Icon(item.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded, size: 17, color: item.isFavourite ? Colors.amber : AppColors.primaryA30),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _toggle(item),
            )
          : (sel ? Icon(Icons.check_rounded, size: 16, color: AppColors.primary) : null),
      onTap: () { widget.onSelect(item.value); widget.onClose(); },
    );
  }
}
