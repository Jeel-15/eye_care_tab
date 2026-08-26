import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_breakpoints.dart';
import '../models/medicine_models.dart';
import '../services/medicine_service.dart';
import '../utils/medicines_tab.dart';
import '../widgets/app_animations.dart';
import '../widgets/skeleton.dart';

BoxDecoration _cardDeco() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA10), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2))]);

/// Tablet Medicines Master — 6 tabs (Dosages/Types/Categories/Routes are
/// simple masters; Medicines is a searchable paginated catalog; Medicine
/// Groups is Pattern A list+detail with an item-repeater form). Ported from
/// eye_care_app/lib/screens/medicines_screen.dart +
/// medicine_group_form_screen.dart. The mobile app's separate
/// medicine_group_detail_screen.dart (read-only view) is folded into the
/// same always-editable form pane here — one surface instead of two.
class MedicinesScreen extends StatefulWidget {
  final int initialTab;
  const MedicinesScreen({super.key, this.initialTab = MedicinesTab.medicines});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

enum _Tab {
  dosages('Dosages', Icons.medication_outlined),
  types('Med. Types', Icons.label_outline_rounded),
  categories('Categories', Icons.grid_view_rounded),
  routes('Route/Admin', Icons.arrow_circle_right_outlined),
  medicines('Medicines', Icons.medication_liquid_outlined),
  groups('Med. Groups', Icons.collections_bookmark_outlined);

  final String label;
  final IconData icon;
  const _Tab(this.label, this.icon);
}

class _MedicinesScreenState extends State<MedicinesScreen> with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _Tab.values.length, vsync: this, initialIndex: widget.initialTab.clamp(0, _Tab.values.length - 1));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medicine Master', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(height: 14),
        _buildTabBar(),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            _SimpleMedMasterTab(title: 'Dosages', subtitle: 'Reusable dosage instructions for prescriptions.', fieldLabel: 'Dosage', fetchAll: MedicineService.instance.fetchDosages, onCreate: MedicineService.instance.createDosage, onUpdate: MedicineService.instance.updateDosage, onDelete: MedicineService.instance.deleteDosage),
            _SimpleMedMasterTab(title: 'Medicine Types', subtitle: 'Classify medicines (e.g. Antibiotic, Steroid).', fieldLabel: 'Type Name', fetchAll: MedicineService.instance.fetchTypes, onCreate: MedicineService.instance.createType, onUpdate: MedicineService.instance.updateType, onDelete: MedicineService.instance.deleteType),
            _SimpleMedMasterTab(title: 'Medicine Categories', subtitle: 'Broad groupings (e.g. Eye Drops, Ointments).', fieldLabel: 'Category Name', fetchAll: MedicineService.instance.fetchCategories, onCreate: MedicineService.instance.createCategory, onUpdate: MedicineService.instance.updateCategory, onDelete: MedicineService.instance.deleteCategory),
            _SimpleMedMasterTab(title: 'Route of Administration', subtitle: 'How a medicine is administered.', fieldLabel: 'Route Name', fetchAll: MedicineService.instance.fetchRoutes, onCreate: MedicineService.instance.createRoute, onUpdate: MedicineService.instance.updateRoute, onDelete: MedicineService.instance.deleteRoute),
            const _MedicinesCatalogTab(),
            const _MedicineGroupsTab(),
          ]),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabCtrl,
      builder: (_, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _Tab.values.map((t) {
          final active = _tabCtrl.index == t.index;
          return GestureDetector(
            onTap: () => _tabCtrl.animateTo(t.index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: active ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.primary : AppColors.primaryA18)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, size: 14, color: active ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
                Text(t.label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Colors.white : AppColors.primary)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Simple master tab (Dosages / Types / Categories / Routes) ────────────

typedef _FetchAll = Future<List<MedMasterItem>> Function();
typedef _CreateOne = Future<void> Function(String value);
typedef _MutateOne = Future<void> Function(int id, String value);
typedef _DeleteOne = Future<void> Function(int id);

class _SimpleMedMasterTab extends StatefulWidget {
  final String title, subtitle, fieldLabel;
  final _FetchAll fetchAll;
  final _CreateOne onCreate;
  final _MutateOne onUpdate;
  final _DeleteOne onDelete;
  const _SimpleMedMasterTab({required this.title, required this.subtitle, required this.fieldLabel, required this.fetchAll, required this.onCreate, required this.onUpdate, required this.onDelete});

  @override
  State<_SimpleMedMasterTab> createState() => _SimpleMedMasterTabState();
}

class _SimpleMedMasterTabState extends State<_SimpleMedMasterTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<MedMasterItem> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.fetchAll();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _openDialog({MedMasterItem? item}) async {
    final ctrl = TextEditingController(text: item?.name ?? '');
    bool saving = false;
    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        if (ctrl.text.trim().isEmpty) return;
        ss(() => saving = true);
        try {
          if (item == null) {
            await widget.onCreate(ctrl.text.trim());
          } else {
            await widget.onUpdate(item.id, ctrl.text.trim());
          }
          if (dCtx.mounted) Navigator.pop(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (dCtx.mounted) showAppSnackBar(dCtx, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add ${widget.fieldLabel}' : 'Edit ${widget.fieldLabel}'),
        content: SizedBox(width: 360, child: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: widget.fieldLabel, border: const OutlineInputBorder()), onSubmitted: (_) => save())),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    ctrl.dispose();
  }

  Future<void> _confirmDelete(MedMasterItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete?'), content: Text('Delete "${item.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await widget.onDelete(item.id);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)), Text(widget.subtitle, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 15), label: const Text('Add'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 14),
      Expanded(child: _buildBody()),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 5, itemHeight: 68);
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]));
    if (_items.isEmpty) return Center(child: Text('No ${widget.title.toLowerCase()} yet.', style: const TextStyle(color: AppColors.textDisabled)));
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 2 : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 8, crossAxisSpacing: 12, childAspectRatio: 6.2),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: _cardDeco(),
            child: Row(children: [
              Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primaryA12, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
              const SizedBox(width: 10),
              Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, overflow: TextOverflow.ellipsis))),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.orange), onPressed: () => _openDialog(item: item)),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.red), onPressed: () => _confirmDelete(item)),
            ]),
          );
        },
      );
    });
  }
}

// ── Medicines catalog tab ─────────────────────────────────────────────

class _MedicinesCatalogTab extends StatefulWidget {
  const _MedicinesCatalogTab();

  @override
  State<_MedicinesCatalogTab> createState() => _MedicinesCatalogTabState();
}

class _MedicinesCatalogTabState extends State<_MedicinesCatalogTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  MedListResult? _result;
  bool _loading = false;
  String? _error;
  int _page = 1;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final p = page ?? _page;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await MedicineService.instance.fetchMedicines(search: _searchCtrl.text.trim(), page: p);
      if (mounted) setState(() { _result = result; _page = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _page = 1);
      _load(page: 1);
    });
  }

  Future<void> _openDialog({MedItem? item}) async {
    final types = _result?.types ?? [];
    final dosages = _result?.dosages ?? [];
    if (types.isEmpty) {
      showAppSnackBar(context, 'Load medicines list first');
      return;
    }
    int? typeId = item?.medicineTypeId;
    int? dosageId = item?.dosageId;
    String usageScope = item?.usageScope ?? 'opd';
    final name = TextEditingController(text: item?.name ?? '');
    final duration = TextEditingController(text: item?.duration ?? '');
    final qty = TextEditingController(text: item?.qty ?? '');
    final company = TextEditingController(text: item?.company ?? '');
    final composition = TextEditingController(text: item?.composition ?? '');
    final price = TextEditingController(text: item?.price?.toStringAsFixed(2) ?? '0.00');
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(context: context, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        if (!(formKey.currentState?.validate() ?? false)) return;
        ss(() => saving = true);
        try {
          final data = {'medicine_type_id': typeId, 'name': name.text.trim(), 'usage_scope': usageScope, 'dosage_id': dosageId, 'duration': duration.text.trim(), 'qty': qty.text.trim(), 'company': company.text.trim().isEmpty ? null : company.text.trim(), 'composition': composition.text.trim().isEmpty ? null : composition.text.trim(), 'price': double.tryParse(price.text) ?? 0.0};
          if (item == null) {
            await MedicineService.instance.createMedicine(data);
          } else {
            await MedicineService.instance.updateMedicine(item.id, data);
          }
          if (dCtx.mounted) Navigator.pop(dCtx);
          await _load(page: _page);
        } catch (e) {
          ss(() => saving = false);
          if (dCtx.mounted) showAppSnackBar(dCtx, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add Medicine' : 'Edit Medicine'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(initialValue: typeId, isExpanded: true, decoration: const InputDecoration(labelText: 'Medicine Type *', border: OutlineInputBorder()), items: types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(), onChanged: (v) => ss(() => typeId = v), validator: (v) => v == null ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Medicine Name *', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ChoiceChip(label: const Text('OPD'), selected: usageScope == 'opd', onSelected: (_) => ss(() => usageScope = 'opd')),
                    const SizedBox(width: 10),
                    ChoiceChip(label: const Text('OT'), selected: usageScope == 'ot', onSelected: (_) => ss(() => usageScope = 'ot')),
                  ]),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(initialValue: dosageId, isExpanded: true, decoration: const InputDecoration(labelText: 'Dosage *', border: OutlineInputBorder()), items: dosages.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(), onChanged: (v) => ss(() => dosageId = v), validator: (v) => v == null ? 'Required' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: duration, decoration: const InputDecoration(labelText: 'Duration *', hintText: 'e.g. 4 days', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: qty, decoration: const InputDecoration(labelText: 'Qty *', hintText: 'e.g. 10 tablets', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: company, decoration: const InputDecoration(labelText: 'Company', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: composition, maxLines: 2, decoration: const InputDecoration(labelText: 'Composition', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder())),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    name.dispose(); duration.dispose(); qty.dispose(); company.dispose(); composition.dispose(); price.dispose();
  }

  Future<void> _confirmDelete(MedItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Medicine?'), content: Text('Delete "${item.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await MedicineService.instance.deleteMedicine(item.id);
      await _load(page: _page);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = _result;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(hintText: 'Search name or company…', prefixIcon: const Icon(Icons.search_rounded, size: 20), suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _page = 1); _load(page: 1); }) : null, filled: true, fillColor: Colors.white, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA12))),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(onPressed: () => _openDialog(), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Medicine'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
      ]),
      const SizedBox(height: 12),
      Expanded(
        child: _loading && result == null
            ? const AppSkeletonList(count: 5, itemHeight: 68)
            : _error != null && result == null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))]))
                : result == null
                    ? const SizedBox.shrink()
                    : result.items.isEmpty
                        ? Center(child: Text(_searchCtrl.text.isNotEmpty ? 'No results for "${_searchCtrl.text}"' : 'No medicines yet', style: const TextStyle(color: AppColors.textDisabled)))
                        : Column(children: [
                            Expanded(
                              child: LayoutBuilder(builder: (context, c) {
                                final cols = c.maxWidth >= AppBreakpoints.medium ? 2 : 1;
                                return GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 10, crossAxisSpacing: 12, mainAxisExtent: 104),
                                  itemCount: result.items.length,
                                  itemBuilder: (_, i) => _MedCard(item: result.items[i], onEdit: () => _openDialog(item: result.items[i]), onDelete: () => _confirmDelete(result.items[i])),
                                );
                              }),
                            ),
                            _PaginationRow(meta: result.meta, loading: _loading, onPrev: () => _load(page: _page - 1), onNext: () => _load(page: _page + 1)),
                          ],
                          ),
      ),
    ]);
  }
}

class _MedCard extends StatelessWidget {
  final MedItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MedCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, overflow: TextOverflow.ellipsis))),
          if (item.price != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text('₹${item.price!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green))),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.orange), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.red), onPressed: onDelete),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 4, children: [
          _infoChip(item.usageScope == 'ot' ? Icons.local_hospital_outlined : Icons.storefront_outlined, item.usageScope.toUpperCase()),
          if (item.medicineTypeName != null) _infoChip(Icons.label_outline_rounded, item.medicineTypeName!),
          if (item.dosageText != null) _infoChip(Icons.medication_outlined, item.dosageText!),
          if (item.duration != null) _infoChip(Icons.timer_outlined, item.duration!),
          if (item.company != null) _infoChip(Icons.business_outlined, item.company!),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 11, color: AppColors.textSecondary), const SizedBox(width: 3), Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))]);
}

class _PaginationRow extends StatelessWidget {
  final MedMeta meta;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PaginationRow({required this.meta, required this.loading, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    if (meta.lastPage <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: (meta.hasPrev && !loading) ? onPrev : null),
        Text('${meta.currentPage} / ${meta.lastPage}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: (meta.hasNext && !loading) ? onNext : null),
      ]),
    );
  }
}

// ── Medicine Groups tab (Pattern A: list + detail form) ──────────────────

class _MedicineGroupsTab extends StatefulWidget {
  const _MedicineGroupsTab();

  @override
  State<_MedicineGroupsTab> createState() => _MedicineGroupsTabState();
}

class _MedicineGroupsTabState extends State<_MedicineGroupsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  MedGroupListResult? _result;
  bool _loading = false;
  String? _error;
  int _page = 1;
  int? _selectedId;
  bool _creatingNew = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? page}) async {
    final p = page ?? _page;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await MedicineService.instance.fetchGroups(page: p);
      if (mounted) setState(() { _result = r; _page = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _confirmDelete(MedGroup group) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Group?'), content: Text('Delete "${group.name}"?\nAll medicine rows will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.red)))]));
    if (ok != true || !mounted) return;
    try {
      await MedicineService.instance.deleteGroup(group.id);
      if (_selectedId == group.id) setState(() => _selectedId = null);
      await _load(page: _page);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(builder: (context, c) {
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();
      if (c.maxWidth < AppBreakpoints.medium) {
        return (_selectedId != null || _creatingNew)
            ? Column(children: [TextButton.icon(onPressed: () => setState(() { _selectedId = null; _creatingNew = false; }), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to Groups')), Expanded(child: detailPane)])
            : listPane;
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 340, child: listPane), const SizedBox(width: 16), Expanded(child: detailPane)]);
    });
  }

  Widget _buildListPane() {
    final result = _result;
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            Expanded(child: Text('Prescription Groups', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))),
            IconButton(icon: Icon(Icons.add_circle_rounded, color: AppColors.primary), onPressed: () => setState(() { _creatingNew = true; _selectedId = null; })),
          ]),
        ),
        Expanded(
          child: _loading && result == null
              ? const AppSkeletonList(count: 5, itemHeight: 68)
              : _error != null && result == null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : (result == null || result.groups.isEmpty)
                      ? Center(child: Text('No medicine groups yet', style: TextStyle(color: AppColors.textDisabled)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: result.groups.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
                          itemBuilder: (_, i) {
                            final g = result.groups[i];
                            final active = _selectedId == g.id;
                            return Material(
                              color: active ? AppColors.primaryA08 : Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() { _selectedId = g.id; _creatingNew = false; }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(g.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? AppColors.primary : AppColors.textPrimary)),
                                        Text('${g.itemsCount} medicine${g.itemsCount == 1 ? '' : 's'}${g.diagnosisValue != null ? ' · ${g.diagnosisValue}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ]),
                                    ),
                                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.red), onPressed: () => _confirmDelete(g)),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
        ),
        if (result != null && result.meta.lastPage > 1) Padding(padding: const EdgeInsets.all(8), child: _PaginationRow(meta: result.meta, loading: _loading, onPrev: () => _load(page: _page - 1), onNext: () => _load(page: _page + 1))),
      ]),
    );
  }

  Widget _buildDetailPane() {
    if (_creatingNew) {
      return _panelBox(child: _GroupFormPane(existing: null, onSaved: () { setState(() => _creatingNew = false); _load(page: _page); }, onCancel: () => setState(() => _creatingNew = false)));
    }
    final group = _result?.groups.where((g) => g.id == _selectedId).firstOrNull;
    if (group == null) {
      return _panelBox(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.collections_bookmark_outlined, size: 56, color: AppColors.primaryA22), const SizedBox(height: 12), Text('Select a group to view or edit', style: TextStyle(fontSize: 13, color: AppColors.primaryA55))])));
    }
    return _panelBox(
      child: FutureBuilder<MedGroup>(
        future: MedicineService.instance.fetchGroup(group.id),
        key: ValueKey(group.id),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primary));
          return _GroupFormPane(existing: snap.data, onSaved: () => _load(page: _page), onCancel: () => setState(() => _selectedId = null));
        },
      ),
    );
  }

  Widget _panelBox({required Widget child}) => Container(padding: const EdgeInsets.all(20), decoration: _cardDeco(), child: child);
}

class _GroupFormPane extends StatefulWidget {
  final MedGroup? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  const _GroupFormPane({required this.existing, required this.onSaved, required this.onCancel});

  @override
  State<_GroupFormPane> createState() => _GroupFormPaneState();
}

class _GroupFormPaneState extends State<_GroupFormPane> {
  final _formKey = GlobalKey<FormState>();
  MedGroupFormData? _formData;
  bool _loadingFormData = true;
  String? _loadError;
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  int? _diagnosisId;

  late List<int?> _medIds;
  late List<int?> _dosageIds;
  late List<int?> _routeIds;
  late List<TextEditingController> _durationCtrls;
  late List<TextEditingController> _qtyCtrls;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _codeCtrl = TextEditingController(text: g?.groupCode ?? '');
    _diagnosisId = g?.diagnosisId;
    if (g != null && g.items.isNotEmpty) {
      _medIds = g.items.map((i) => i.medicineId).toList();
      _dosageIds = g.items.map((i) => i.dosageId).toList();
      _routeIds = g.items.map((i) => i.routeId).toList();
      _durationCtrls = g.items.map((i) => TextEditingController(text: i.duration ?? '')).toList();
      _qtyCtrls = g.items.map((i) => TextEditingController(text: '${i.quantity}')).toList();
    } else {
      _medIds = [null];
      _dosageIds = [null];
      _routeIds = [null];
      _durationCtrls = [TextEditingController()];
      _qtyCtrls = [TextEditingController(text: '1')];
    }
    _loadFormData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    for (final c in _durationCtrls) { c.dispose(); }
    for (final c in _qtyCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() { _loadingFormData = true; _loadError = null; });
    try {
      final data = await MedicineService.instance.fetchGroupFormData();
      if (mounted) setState(() { _formData = data; _loadingFormData = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loadingFormData = false; });
    }
  }

  void _addRow() => setState(() {
        _medIds.add(null); _dosageIds.add(null); _routeIds.add(null);
        _durationCtrls.add(TextEditingController()); _qtyCtrls.add(TextEditingController(text: '1'));
      });

  void _removeRow(int i) {
    if (_medIds.length <= 1) return;
    setState(() {
      _medIds.removeAt(i); _dosageIds.removeAt(i); _routeIds.removeAt(i);
      _durationCtrls[i].dispose(); _durationCtrls.removeAt(i);
      _qtyCtrls[i].dispose(); _qtyCtrls.removeAt(i);
    });
  }

  void _onMedicineSelected(int idx, int? medicineId) {
    setState(() {
      _medIds[idx] = medicineId;
      if (medicineId != null) {
        final af = _formData?.autoFillFor(medicineId);
        if (af != null) {
          if (af.dosageId != null) _dosageIds[idx] = af.dosageId;
          if (af.duration != null && af.duration!.isNotEmpty) _durationCtrls[idx].text = af.duration!;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    for (int i = 0; i < _medIds.length; i++) {
      if (_medIds[i] == null) {
        showAppSnackBar(context, 'Row ${i + 1}: Select a medicine', isError: true);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'group_code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        'diagnosis_id': _diagnosisId,
        'items': List.generate(_medIds.length, (i) => {'medicine_id': _medIds[i], 'dosage_id': _dosageIds[i], 'route_id': _routeIds[i], 'duration': _durationCtrls[i].text.trim().isEmpty ? null : _durationCtrls[i].text.trim(), 'quantity': int.tryParse(_qtyCtrls[i].text) ?? 1}),
      };
      if (widget.existing == null) {
        await MedicineService.instance.createGroup(payload);
      } else {
        await MedicineService.instance.updateGroup(widget.existing!.id, payload);
      }
      if (mounted) {
        showAppSnackBar(context, 'Group saved.', isSuccess: true);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFormData) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_loadError != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!), const SizedBox(height: 10), ElevatedButton(onPressed: _loadFormData, child: const Text('Retry'))]));
    }
    final fd = _formData!;
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.collections_bookmark_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.existing == null ? 'New Medicine Group' : 'Edit Medicine Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: widget.onCancel),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 700;
                final nameField = _field('Group Name *', TextFormField(controller: _nameCtrl, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, decoration: const InputDecoration(hintText: 'e.g. Post-Op Cataract', border: OutlineInputBorder())));
                final codeField = _field('Group Code', TextFormField(controller: _codeCtrl, decoration: const InputDecoration(hintText: 'e.g. GRP-001', border: OutlineInputBorder())));
                final dxField = _field('Diagnosis (optional)', DropdownButtonFormField<int?>(initialValue: _diagnosisId, isExpanded: true, hint: const Text('— None —'), decoration: const InputDecoration(border: OutlineInputBorder()), items: [const DropdownMenuItem<int?>(value: null, child: Text('— None —')), ...fd.diagnoses.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name)))], onChanged: (v) => setState(() => _diagnosisId = v)));
                return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: nameField), const SizedBox(width: 12), Expanded(child: codeField), const SizedBox(width: 12), Expanded(child: dxField)]) : Column(children: [nameField, codeField, dxField]);
              }),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Medicines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary))),
                ElevatedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add_rounded, size: 14), label: const Text('Add Row', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7))),
              ]),
              const SizedBox(height: 10),
              ...List.generate(_medIds.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _rowCard(i, fd))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.existing != null ? 'Update Group' : 'Save Group', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, Widget child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)), const SizedBox(height: 5), child]));

  Widget _rowCard(int i, MedGroupFormData fd) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryA06, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)), child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
          const Spacer(),
          if (_medIds.length > 1) IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.red), onPressed: () => _removeRow(i)),
        ]),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 640;
          final medField = _field('Medicine *', DropdownButtonFormField<int>(initialValue: _medIds[i], isExpanded: true, hint: const Text('Select medicine', style: TextStyle(fontSize: 12)), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), items: fd.medicines.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => _onMedicineSelected(i, v)));
          final dosField = _field('Dosage', DropdownButtonFormField<int?>(initialValue: _dosageIds[i], isExpanded: true, hint: const Text('—', style: TextStyle(fontSize: 12)), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), items: [const DropdownMenuItem<int?>(value: null, child: Text('—')), ...fd.dosages.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name)))], onChanged: (v) => setState(() => _dosageIds[i] = v)));
          final durField = _field('Duration', TextFormField(controller: _durationCtrls[i], decoration: const InputDecoration(isDense: true, hintText: 'e.g. 4 days', border: OutlineInputBorder())));
          final routeField = _field('Route', DropdownButtonFormField<int?>(initialValue: _routeIds[i], isExpanded: true, hint: const Text('—', style: TextStyle(fontSize: 12)), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), items: [const DropdownMenuItem<int?>(value: null, child: Text('—')), ...fd.routes.map((r) => DropdownMenuItem<int?>(value: r.id, child: Text(r.name)))], onChanged: (v) => setState(() => _routeIds[i] = v)));
          final qtyField = _field('Qty', TextFormField(controller: _qtyCtrls[i], keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())));
          if (!wide) return Column(children: [medField, Row(children: [Expanded(child: dosField), const SizedBox(width: 8), Expanded(child: durField)]), Row(children: [Expanded(child: routeField), const SizedBox(width: 8), SizedBox(width: 70, child: qtyField)])]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: medField), const SizedBox(width: 8), Expanded(flex: 2, child: dosField), const SizedBox(width: 8), Expanded(flex: 2, child: durField), const SizedBox(width: 8), Expanded(flex: 2, child: routeField), const SizedBox(width: 8), SizedBox(width: 70, child: qtyField)]);
        }),
      ]),
    );
  }
}
