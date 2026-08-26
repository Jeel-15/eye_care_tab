import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_medicine_master_models.dart';
import '../services/platform_medicine_master_service.dart';
import '../utils/app_decorations.dart';
import '../utils/app_dialogs.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/skeleton.dart';

/// Tablet Platform Medicine Master — top TabBar (5 tabs: Dosages/Types/
/// Categories/Routes/Medicines), matching the hospital-side Medicines
/// screen's flat-tab convention. Medicine add/edit uses a Dialog instead of
/// mobile's DraggableScrollableSheet. Business logic (shared simple-master
/// CRUD base, medicine form data, search/filter/paginate) ported unchanged
/// from eye_care_app/lib/screens/platform_medicine_master_screen.dart.
class PlatformMedicineMasterScreen extends StatefulWidget {
  final PlatformAdmin admin;
  const PlatformMedicineMasterScreen({super.key, required this.admin});

  @override
  State<PlatformMedicineMasterScreen> createState() => _PlatformMedicineMasterScreenState();
}

class _PlatformMedicineMasterScreenState extends State<PlatformMedicineMasterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA08)),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [Tab(text: 'Dosages'), Tab(text: 'Types'), Tab(text: 'Categories'), Tab(text: 'Routes'), Tab(text: 'Medicines')],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(controller: _tabController, children: const [_DosagesTab(), _TypesTab(), _CategoriesTab(), _RoutesTab(), _MedicinesTab()]),
        ),
      ],
    );
  }
}

// ── Simple Master Tab Base ─────────────────────────────────────────────────

abstract class _SimpleMasterTabState<T extends StatefulWidget> extends State<T> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformMedicineMasterService.instance;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

  String get _entityLabel;
  String get _fieldLabel;
  String get _fieldKey;

  Future<({List<Map<String, dynamic>> items, int total, int lastPage})?> _fetchItems({String? search, int page = 1});
  Future<({bool success, String message})> _storeItem(String value);
  Future<({bool success, String message})> _updateItem(int id, String value);
  Future<({bool success, String message})> _deleteItem(int id);
  Future<bool> _toggleItem(int id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    final search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    final r = await _fetchItems(search: search, page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final ctrl = TextEditingController(text: item?[_fieldKey] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add $_entityLabel' : 'Edit $_entityLabel', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: SizedBox(width: 360, child: Form(key: formKey, child: TextFormField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: AppDecorations.inputDecoration(labelText: '$_fieldLabel *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(item == null ? 'Add' : 'Save')),
        ],
      ),
    );
    final value = ctrl.text.trim();
    ctrl.dispose();
    if (saved != true) return;
    final result = item == null ? await _storeItem(value) : await _updateItem(item['id'] as int, value);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final val = item[_fieldKey] as String;
    final yes = await showDeleteConfirmDialog(context, 'Delete "$val"?');
    if (!yes) return;
    final r = await _deleteItem(item['id'] as int);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Row(children: [
        Expanded(child: AppSearchBar(controller: _searchCtrl, hint: 'Search $_entityLabel...', onChanged: _onSearch)),
        const SizedBox(width: 8),
        IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26), tooltip: 'Add $_entityLabel'),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 56)
            : _items.isEmpty
                ? AppEmptyState(message: 'No $_entityLabel found', icon: Icons.inbox_rounded)
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          final isActive = item['is_active'] == true || item['is_active'] == 1;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: AppDecorations.card(),
                            child: Row(children: [
                              Expanded(child: Text(item[_fieldKey] as String, style: AppTextStyles.cardTitle)),
                              Switch(value: isActive, onChanged: (_) async {
                                final newVal = await _toggleItem(item['id'] as int);
                                setState(() => item['is_active'] = newVal);
                              }, activeThumbColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.primary), onPressed: () => _showForm(item: item), padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
                              const SizedBox(width: 4),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _confirmDelete(item), padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
                            ]),
                          );
                        },
                      ),
                    ),
                    if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                  ]),
      ),
    ]);
  }
}

List<Map<String, dynamic>> _toMaps(List items) => items.map((e) {
      if (e is MasterDosage) return {'id': e.id, 'dosage': e.dosage, 'is_active': e.isActive};
      if (e is MasterMedicineType) return {'id': e.id, 'name': e.name, 'is_active': e.isActive};
      if (e is MasterMedicineCategory) return {'id': e.id, 'name': e.name, 'is_active': e.isActive};
      if (e is MasterMedicineRoute) return {'id': e.id, 'name': e.name, 'is_active': e.isActive};
      return <String, dynamic>{};
    }).toList();

// ── Dosages ───────────────────────────────────────────────────────────────

class _DosagesTab extends StatefulWidget {
  const _DosagesTab();
  @override
  State<_DosagesTab> createState() => _DosagesTabState();
}

class _DosagesTabState extends _SimpleMasterTabState<_DosagesTab> {
  @override
  String get _entityLabel => 'Dosage';
  @override
  String get _fieldLabel => 'Dosage';
  @override
  String get _fieldKey => 'dosage';

  @override
  Future<({List<Map<String, dynamic>> items, int total, int lastPage})?> _fetchItems({String? search, int page = 1}) async {
    final r = await _svc.getDosages(search: search, page: page);
    if (r == null) return null;
    return (items: _toMaps(r.items), total: r.total, lastPage: r.lastPage);
  }

  @override
  Future<({bool success, String message})> _storeItem(String v) => _svc.storeDosage(v);
  @override
  Future<({bool success, String message})> _updateItem(int id, String v) => _svc.updateDosage(id, v);
  @override
  Future<({bool success, String message})> _deleteItem(int id) => _svc.deleteDosage(id);
  @override
  Future<bool> _toggleItem(int id) => _svc.toggleDosage(id);
}

// ── Types ─────────────────────────────────────────────────────────────────

class _TypesTab extends StatefulWidget {
  const _TypesTab();
  @override
  State<_TypesTab> createState() => _TypesTabState();
}

class _TypesTabState extends _SimpleMasterTabState<_TypesTab> {
  @override
  String get _entityLabel => 'Type';
  @override
  String get _fieldLabel => 'Medicine Type';
  @override
  String get _fieldKey => 'name';

  @override
  Future<({List<Map<String, dynamic>> items, int total, int lastPage})?> _fetchItems({String? search, int page = 1}) async {
    final r = await _svc.getTypes(search: search, page: page);
    if (r == null) return null;
    return (items: _toMaps(r.items), total: r.total, lastPage: r.lastPage);
  }

  @override
  Future<({bool success, String message})> _storeItem(String v) => _svc.storeType(v);
  @override
  Future<({bool success, String message})> _updateItem(int id, String v) => _svc.updateType(id, v);
  @override
  Future<({bool success, String message})> _deleteItem(int id) => _svc.deleteType(id);
  @override
  Future<bool> _toggleItem(int id) => _svc.toggleType(id);
}

// ── Categories ────────────────────────────────────────────────────────────

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends _SimpleMasterTabState<_CategoriesTab> {
  @override
  String get _entityLabel => 'Category';
  @override
  String get _fieldLabel => 'Category Name';
  @override
  String get _fieldKey => 'name';

  @override
  Future<({List<Map<String, dynamic>> items, int total, int lastPage})?> _fetchItems({String? search, int page = 1}) async {
    final r = await _svc.getCategories(search: search, page: page);
    if (r == null) return null;
    return (items: _toMaps(r.items), total: r.total, lastPage: r.lastPage);
  }

  @override
  Future<({bool success, String message})> _storeItem(String v) => _svc.storeCategory(v);
  @override
  Future<({bool success, String message})> _updateItem(int id, String v) => _svc.updateCategory(id, v);
  @override
  Future<({bool success, String message})> _deleteItem(int id) => _svc.deleteCategory(id);
  @override
  Future<bool> _toggleItem(int id) => _svc.toggleCategory(id);
}

// ── Routes ────────────────────────────────────────────────────────────────

class _RoutesTab extends StatefulWidget {
  const _RoutesTab();
  @override
  State<_RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends _SimpleMasterTabState<_RoutesTab> {
  @override
  String get _entityLabel => 'Route';
  @override
  String get _fieldLabel => 'Route Name';
  @override
  String get _fieldKey => 'name';

  @override
  Future<({List<Map<String, dynamic>> items, int total, int lastPage})?> _fetchItems({String? search, int page = 1}) async {
    final r = await _svc.getRoutes(search: search, page: page);
    if (r == null) return null;
    return (items: _toMaps(r.items), total: r.total, lastPage: r.lastPage);
  }

  @override
  Future<({bool success, String message})> _storeItem(String v) => _svc.storeRoute(v);
  @override
  Future<({bool success, String message})> _updateItem(int id, String v) => _svc.updateRoute(id, v);
  @override
  Future<({bool success, String message})> _deleteItem(int id) => _svc.deleteRoute(id);
  @override
  Future<bool> _toggleItem(int id) => _svc.toggleRoute(id);
}

// ── Medicines Tab ─────────────────────────────────────────────────────────

class _MedicinesTab extends StatefulWidget {
  const _MedicinesTab();
  @override
  State<_MedicinesTab> createState() => _MedicinesTabState();
}

class _MedicinesTabState extends State<_MedicinesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformMedicineMasterService.instance;
  final _searchCtrl = TextEditingController();
  int? _typeId;
  List<MasterMedicine> _items = [];
  MedicineFormData? _formData;
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _formData = await _svc.getFormData();
    if (mounted) _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    final search = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    final r = await _svc.getMedicines(search: search, typeId: _typeId, page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({MasterMedicine? item}) async {
    if (_formData == null) {
      showAppSnackBar(context, 'Form data not loaded', isError: true);
      return;
    }
    await showDialog(context: context, builder: (ctx) => _MedicineFormDialog(formData: _formData!, item: item, onSaved: () => _load()));
  }

  Future<void> _confirmDelete(MasterMedicine m) async {
    if (!await showDeleteConfirmDialog(context, 'Delete "${m.name}"?')) return;
    final r = await _svc.deleteMedicine(m.id);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Row(children: [
        if (_formData != null) ...[
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
              child: DropdownButton<int?>(
                value: _typeId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: Text('All Types', style: AppTextStyles.cardSubtitle),
                style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                items: [const DropdownMenuItem<int?>(value: null, child: Text('All Types')), ..._formData!.types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))],
                onChanged: (v) { setState(() => _typeId = v); _load(); },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: AppSearchBar(controller: _searchCtrl, hint: 'Search medicine...', onChanged: _onSearch)),
        const SizedBox(width: 8),
        IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26), tooltip: 'Add Medicine'),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 78)
            : _items.isEmpty
                ? AppEmptyState(message: 'No medicines found', icon: Icons.medication_outlined)
                : LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 900 ? 2 : 1;
                    return Column(children: [
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 8, crossAxisSpacing: 12, childAspectRatio: cols == 2 ? 2.6 : 3.4),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final m = _items[i];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: AppDecorations.card(),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(m.name, style: AppTextStyles.cardTitle),
                                    const SizedBox(height: 4),
                                    Wrap(spacing: 6, runSpacing: 4, children: [
                                      if (m.typeName != null) _Chip(m.typeName!, AppColors.primary),
                                      if (m.dosageName != null) _Chip(m.dosageName!, AppColors.teal),
                                      if (m.duration != null) _Chip(m.duration!, AppColors.orange),
                                      if (m.price != null) _Chip('₹${m.price!.toStringAsFixed(0)}', AppColors.green),
                                    ]),
                                    if (m.composition != null && m.composition!.isNotEmpty) ...[const SizedBox(height: 4), Text(m.composition!, style: AppTextStyles.cardSubtitle, maxLines: 2, overflow: TextOverflow.ellipsis)],
                                  ]),
                                ),
                                Column(children: [
                                  Switch(value: m.isActive, onChanged: (_) async {
                                    final val = await _svc.toggleMedicine(m.id);
                                    if (!mounted) return;
                                    setState(() => _items[_items.indexOf(m)] = MasterMedicine(id: m.id, name: m.name, typeId: m.typeId, typeName: m.typeName, dosageId: m.dosageId, dosageName: m.dosageName, duration: m.duration, qty: m.qty, composition: m.composition, company: m.company, price: m.price, isActive: val));
                                  }, activeThumbColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.primary), onPressed: () => _showForm(item: m), padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
                                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: () => _confirmDelete(m), padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
                                  ]),
                                ]),
                              ]),
                            );
                          },
                        ),
                      ),
                      if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                    ]);
                  }),
      ),
    ]);
  }
}

// ── Medicine Form Dialog ─────────────────────────────────────────────────

class _MedicineFormDialog extends StatefulWidget {
  final MedicineFormData formData;
  final MasterMedicine? item;
  final VoidCallback onSaved;
  const _MedicineFormDialog({required this.formData, this.item, required this.onSaved});

  @override
  State<_MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<_MedicineFormDialog> {
  final _svc = PlatformMedicineMasterService.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _compositionCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int? _typeId, _dosageId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.item;
    if (m != null) {
      _nameCtrl.text = m.name;
      _durationCtrl.text = m.duration ?? '';
      _qtyCtrl.text = m.qty ?? '';
      _compositionCtrl.text = m.composition ?? '';
      _companyCtrl.text = m.company ?? '';
      _priceCtrl.text = m.price != null ? m.price!.toStringAsFixed(0) : '';
      _typeId = m.typeId;
      _dosageId = m.dosageId;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _qtyCtrl.dispose();
    _compositionCtrl.dispose();
    _companyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'master_medicine_type_id': _typeId,
      'master_dosage_id': _dosageId,
      'name': _nameCtrl.text.trim(),
      'duration': _durationCtrl.text.trim().isEmpty ? null : _durationCtrl.text.trim(),
      'qty': _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
      'composition': _compositionCtrl.text.trim().isEmpty ? null : _compositionCtrl.text.trim(),
      'company': _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      'price': _priceCtrl.text.trim().isEmpty ? null : double.tryParse(_priceCtrl.text.trim()),
    };
    final result = widget.item == null ? await _svc.storeMedicine(data) : await _svc.updateMedicine(widget.item!.id, data);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 480,
        height: 600,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [Expanded(child: Text(widget.item == null ? 'Add Medicine' : 'Edit Medicine', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))), IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context))]),
              ),
              Divider(color: AppColors.primaryA12, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      _sheetDropdown<int?>(label: 'Medicine Type *', value: _typeId, items: widget.formData.types.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(), onChanged: (v) => setState(() => _typeId = v), validator: (v) => v == null ? 'Select type' : null),
                      const SizedBox(height: 12),
                      _sheetDropdown<int?>(label: 'Dosage *', value: _dosageId, items: widget.formData.dosages.map((d) => DropdownMenuItem(value: d.id, child: Text(d.dosage))).toList(), onChanged: (v) => setState(() => _dosageId = v), validator: (v) => v == null ? 'Select dosage' : null),
                      const SizedBox(height: 12),
                      _sheetField(_nameCtrl, 'Medicine Name *', required: true, cap: TextCapitalization.words),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: _sheetField(_durationCtrl, 'Duration (e.g. 7 Days)')), const SizedBox(width: 10), Expanded(child: _sheetField(_qtyCtrl, 'Qty (e.g. 10 tabs)'))]),
                      const SizedBox(height: 12),
                      _sheetField(_compositionCtrl, 'Composition', maxLines: 3),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: _sheetField(_companyCtrl, 'Company')), const SizedBox(width: 10), Expanded(child: _sheetField(_priceCtrl, 'Price (₹)', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]))]),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Text(widget.item == null ? 'Add Medicine' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1, TextCapitalization cap = TextCapitalization.sentences, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) => TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        textCapitalization: cap,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: AppDecorations.inputDecoration(labelText: label),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      );

  Widget _sheetDropdown<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged, FormFieldValidator<T>? validator}) => DropdownButtonFormField<T>(initialValue: value, decoration: AppDecorations.inputDecoration(labelText: label), items: items, onChanged: onChanged, validator: validator);
}

// ── Shared helpers ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );
}
