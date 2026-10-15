/// Searchable single-choice list in a dialog — Settings' location/timezone
/// pickers and the User form's role picker share this one frame.
library;

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import 'app_dialog.dart';
import 'form_kit.dart';

/// Pops with the tapped item, or null when closed. Pass [items] when the
/// list is already in memory, or [loader] to fetch it (a spinner shows
/// meanwhile, and a thrown error is shown in place of the list). Search
/// matches against [label]; [itemBuilder] replaces the default row and must
/// call `select` on tap.
Future<T?> showSearchPickerDialog<T>(
  BuildContext context, {
  required String title,
  required String Function(T item) label,
  List<T>? items,
  Future<List<T>> Function()? loader,
  IconData icon = Icons.list_alt_rounded,
  String searchHint = 'Search...',
  Widget Function(BuildContext context, T item, VoidCallback select)? itemBuilder,
}) {
  assert(items != null || loader != null, 'Pass items or loader');
  return showDialog<T>(
    context: context,
    builder: (_) => _SearchPickerDialog<T>(
      title: title,
      label: label,
      items: items,
      loader: loader,
      icon: icon,
      searchHint: searchHint,
      itemBuilder: itemBuilder,
    ),
  );
}

class _SearchPickerDialog<T> extends StatefulWidget {
  final String title;
  final String Function(T item) label;
  final List<T>? items;
  final Future<List<T>> Function()? loader;
  final IconData icon;
  final String searchHint;
  final Widget Function(BuildContext context, T item, VoidCallback select)? itemBuilder;

  const _SearchPickerDialog({
    required this.title,
    required this.label,
    required this.items,
    required this.loader,
    required this.icon,
    required this.searchHint,
    required this.itemBuilder,
  });

  @override
  State<_SearchPickerDialog<T>> createState() => _SearchPickerDialogState<T>();
}

class _SearchPickerDialogState<T> extends State<_SearchPickerDialog<T>> {
  final _searchCtrl = TextEditingController();
  List<T>? _items;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    if (_items == null) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.loader!();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<T> get _filtered {
    final all = _items;
    if (all == null) return <T>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((i) => widget.label(i).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SizedBox(
        width: AppDialogSize.small.width,
        height: 520,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppDialogHeader(icon: widget.icon, title: widget.title, onClose: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: appFieldDecoration(null, hint: widget.searchHint, prefix: Icons.search_rounded),
            ),
          ),
          Expanded(child: _list()),
        ]),
      ),
    );
  }

  Widget _list() {
    if (_error != null) return _message(_error!);
    if (_items == null) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    final filtered = _filtered;
    if (filtered.isEmpty) return _message('No results found.');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final item = filtered[i];
        void select() => Navigator.pop(context, item);
        return widget.itemBuilder?.call(ctx, item, select) ??
            ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              title: Text(widget.label(item), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              onTap: select,
            );
      },
    );
  }

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
      );
}
