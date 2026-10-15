import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/medicine_models.dart';
import '../services/medicine_service.dart';
import '../services/permission_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/medicines_tab.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/table_row_action.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';
import '../widgets/split_pane_scaffold.dart';
import '../utils/currency_format.dart';

BoxDecoration _cardDeco() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: AppColors.primaryA10),
  boxShadow: [
    BoxShadow(
      color: AppColors.primaryA06,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

bool get _medCanAdd => PermissionService.instance.can(Perm.masterMedicineAdd);
bool get _medCanEdit => PermissionService.instance.can(Perm.masterMedicineEdit);
bool get _medCanDelete =>
    PermissionService.instance.can(Perm.masterMedicineDelete);

/// Tablet Medicines Master — 7 tabs (Dosages/Types/Categories/Routes are
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
  groups('Med. Groups', Icons.collections_bookmark_outlined),
  ward('Ward Medicine', Icons.local_hospital_outlined);

  final String label;
  final IconData icon;
  const _Tab(this.label, this.icon);
}

class _MedicinesScreenState extends State<MedicinesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: _Tab.values.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _Tab.values.length - 1),
    );
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
        Text(
          'Medicine Master',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        _buildTabBar(),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _SimpleMedMasterTab(
                title: 'Dosages',
                subtitle: 'Reusable dosage instructions for prescriptions.',
                fieldLabel: 'Dosage',
                fetchAll: MedicineService.instance.fetchDosages,
                onCreate: MedicineService.instance.createDosage,
                onUpdate: MedicineService.instance.updateDosage,
                onDelete: MedicineService.instance.deleteDosage,
              ),
              _SimpleMedMasterTab(
                title: 'Medicine Types',
                subtitle: 'Classify medicines (e.g. Antibiotic, Steroid).',
                fieldLabel: 'Type Name',
                fetchAll: MedicineService.instance.fetchTypes,
                onCreate: MedicineService.instance.createType,
                onUpdate: MedicineService.instance.updateType,
                onDelete: MedicineService.instance.deleteType,
              ),
              _SimpleMedMasterTab(
                title: 'Medicine Categories',
                subtitle: 'Broad groupings (e.g. Eye Drops, Ointments).',
                fieldLabel: 'Category Name',
                fetchAll: MedicineService.instance.fetchCategories,
                onCreate: MedicineService.instance.createCategory,
                onUpdate: MedicineService.instance.updateCategory,
                onDelete: MedicineService.instance.deleteCategory,
              ),
              _SimpleMedMasterTab(
                title: 'Route of Administration',
                subtitle: 'How a medicine is administered.',
                fieldLabel: 'Route Name',
                fetchAll: MedicineService.instance.fetchRoutes,
                onCreate: MedicineService.instance.createRoute,
                onUpdate: MedicineService.instance.updateRoute,
                onDelete: MedicineService.instance.deleteRoute,
              ),
              const _MedicinesCatalogTab(),
              const _MedicineGroupsTab(),
              const _MedicinesCatalogTab(ward: true),
            ],
          ),
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
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.primaryA18,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    t.icon,
                    size: 14,
                    color: active ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? Colors.white : AppColors.primary,
                    ),
                  ),
                ],
              ),
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
  const _SimpleMedMasterTab({
    required this.title,
    required this.subtitle,
    required this.fieldLabel,
    required this.fetchAll,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_SimpleMedMasterTab> createState() => _SimpleMedMasterTabState();
}

class _SimpleMedMasterTabState extends State<_SimpleMedMasterTab>
    with AutomaticKeepAliveClientMixin {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.fetchAll();
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _openDialog({MedMasterItem? item}) async {
    final ctrl = TextEditingController(text: item?.name ?? '');
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, ss) {
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
              if (dCtx.mounted)
                showAppSnackBar(
                  dCtx,
                  e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
            }
          }

          return AppDialog(
            size: AppDialogSize.small,
            header: AppDialogHeader(
              icon: item == null ? Icons.add_rounded : Icons.edit_outlined,
              title: item == null
                  ? 'Add ${widget.fieldLabel}'
                  : 'Edit ${widget.fieldLabel}',
              onClose: saving ? null : () => Navigator.pop(dCtx),
            ),
            body: TextField(
              controller: ctrl,
              autofocus: item == null,
              decoration: appFieldDecoration(widget.fieldLabel),
              onSubmitted: (_) => save(),
            ),
            actions: [
              AppSecondaryButton(
                onPressed: saving ? null : () => Navigator.pop(dCtx),
              ),
              AppPrimaryButton(label: 'Save', loading: saving, onPressed: save),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _confirmDelete(MedMasterItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete ${widget.fieldLabel}',
      message: 'Delete "${item.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.onDelete(item.id);
      await _load();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_medCanAdd)
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 5, itemHeight: 68);
    if (_error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    if (_items.isEmpty)
      return Center(
        child: Text(
          'No ${widget.title.toLowerCase()} yet.',
          style: const TextStyle(color: AppColors.textDisabled),
        ),
      );
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 3
            : c.maxWidth >= 700
            ? 2
            : 1;
        return AppRefreshIndicator(
          onRefresh: _load,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 48,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              return Container(
                padding: const EdgeInsets.only(left: 12, right: 6),
                decoration: _cardDeco(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_medCanEdit)
                      TableIconAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        kind: TableActionKind.edit,
                        onTap: () => _openDialog(item: item),
                      ),
                    if (_medCanDelete)
                      TableIconAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        kind: TableActionKind.delete,
                        onTap: () => _confirmDelete(item),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Medicines catalog tab ─────────────────────────────────────────────

class _MedicinesCatalogTab extends StatefulWidget {
  final bool ward;
  const _MedicinesCatalogTab({this.ward = false});

  @override
  State<_MedicinesCatalogTab> createState() => _MedicinesCatalogTabState();
}

class _MedicinesCatalogTabState extends State<_MedicinesCatalogTab>
    with AutomaticKeepAliveClientMixin {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await MedicineService.instance.fetchMedicines(
        search: _searchCtrl.text.trim(),
        page: p,
        ward: widget.ward,
      );
      if (mounted)
        setState(() {
          _result = result;
          _page = p;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
      showAppSnackBar(context, 'Load medicines list first', isError: true);
      return;
    }
    int? typeId = item?.medicineTypeId;
    int? dosageId = item?.dosageId;
    final name = TextEditingController(text: item?.name ?? '');
    final duration = TextEditingController(text: item?.duration ?? '');
    final qty = TextEditingController(text: item?.qty ?? '');
    final company = TextEditingController(text: item?.company ?? '');
    final composition = TextEditingController(text: item?.composition ?? '');
    final price = TextEditingController(
      text: item?.price?.toStringAsFixed(2) ?? '0.00',
    );
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, ss) {
          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            ss(() => saving = true);
            try {
              final data = {
                'medicine_type_id': typeId,
                'name': name.text.trim(),
                'dosage_id': dosageId,
                'duration': duration.text.trim(),
                'qty': qty.text.trim(),
                'company': company.text.trim().isEmpty
                    ? null
                    : company.text.trim(),
                'composition': composition.text.trim().isEmpty
                    ? null
                    : composition.text.trim(),
                'price': double.tryParse(price.text) ?? 0.0,
                if (widget.ward) 'usage_scope': 'ward',
              };
              if (item == null) {
                await MedicineService.instance.createMedicine(data);
              } else {
                await MedicineService.instance.updateMedicine(item.id, data);
              }
              if (dCtx.mounted) Navigator.pop(dCtx);
              await _load(page: _page);
            } catch (e) {
              ss(() => saving = false);
              if (dCtx.mounted)
                showAppSnackBar(
                  dCtx,
                  e.toString().replaceFirst('Exception: ', ''),
                  isError: true,
                );
            }
          }

          return AppDialog(
            size: AppDialogSize.medium,
            header: AppDialogHeader(
              icon: item == null ? Icons.add_rounded : Icons.edit_outlined,
              title: item == null
                  ? (widget.ward ? 'Add Ward Medicine' : 'Add Medicine')
                  : (widget.ward ? 'Edit Ward Medicine' : 'Edit Medicine'),
              onClose: saving ? null : () => Navigator.pop(dCtx),
            ),
            body: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppFormRow(
                    flex: const [2, 3],
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: typeId,
                        isExpanded: true,
                        decoration: appFieldDecoration('Medicine Type *'),
                        items: types
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => ss(() => typeId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: name,
                        decoration: appFieldDecoration('Medicine Name *'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppFormRow(
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: dosageId,
                        isExpanded: true,
                        decoration: appFieldDecoration('Dosage *'),
                        items: dosages
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => ss(() => dosageId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: duration,
                        decoration: appFieldDecoration(
                          'Duration *',
                          hint: 'e.g. 4 days',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: qty,
                        decoration: appFieldDecoration(
                          'Qty *',
                          hint: 'e.g. 10 tablets',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppFormRow(
                    children: [
                      TextFormField(
                        controller: company,
                        decoration: appFieldDecoration('Company'),
                      ),
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: appFieldDecoration(
                          'Price (${currentCurrencySymbol()})',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: composition,
                    maxLines: 2,
                    decoration: appFieldDecoration('Composition'),
                  ),
                ],
              ),
            ),
            actions: [
              AppSecondaryButton(
                onPressed: saving ? null : () => Navigator.pop(dCtx),
              ),
              AppPrimaryButton(label: 'Save', loading: saving, onPressed: save),
            ],
          );
        },
      ),
    );
    name.dispose();
    duration.dispose();
    qty.dispose();
    company.dispose();
    composition.dispose();
    price.dispose();
  }

  Future<void> _openImportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) =>
          _ImportMedicinesDialog(onImported: () => _load(page: _page)),
    );
  }

  Future<void> _confirmDelete(MedItem item) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Medicine',
      message: 'Delete "${item.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await MedicineService.instance.deleteMedicine(item.id);
      await _load(page: _page);
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search name or company…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _page = 1);
                            _load(page: 1);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppColors.primaryA12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (_medCanAdd) ...[
              if (!widget.ward) ...[
                OutlinedButton.icon(
                  onPressed: _openImportDialog,
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('CSV Upload'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primaryA30),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(widget.ward ? 'Add Ward Medicine' : 'Add Medicine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading && result == null
              ? const AppSkeletonList(count: 5, itemHeight: 68)
              : _error != null && result == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : result == null
              ? const SizedBox.shrink()
              : result.items.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.isNotEmpty
                        ? 'No results for "${_searchCtrl.text}"'
                        : (widget.ward
                              ? 'No ward medicines yet'
                              : 'No medicines yet'),
                    style: const TextStyle(color: AppColors.textDisabled),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 1100
                              ? 3
                              : c.maxWidth >= 720
                              ? 2
                              : 1;
                          return AppRefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisExtent: 72,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: result.items.length,
                              itemBuilder: (_, i) {
                                final item = result.items[i];
                                final meta =
                                    [
                                          item.medicineTypeName,
                                          item.dosageText,
                                          item.duration,
                                          item.qty,
                                          item.company,
                                        ]
                                        .whereType<String>()
                                        .where((s) => s.trim().isNotEmpty)
                                        .join(' · ');
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    6,
                                    8,
                                  ),
                                  decoration: _cardDeco(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (item.price != null)
                                            Text(
                                              '${currentCurrencySymbol()}${item.price!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.green,
                                              ),
                                            ),
                                          if (_medCanEdit)
                                            TableIconAction(
                                              icon: Icons.edit_outlined,
                                              tooltip: 'Edit',
                                              kind: TableActionKind.edit,
                                              onTap: () =>
                                                  _openDialog(item: item),
                                            ),
                                          if (_medCanDelete)
                                            TableIconAction(
                                              icon:
                                                  Icons.delete_outline_rounded,
                                              tooltip: 'Delete',
                                              kind: TableActionKind.delete,
                                              onTap: () => _confirmDelete(item),
                                            ),
                                        ],
                                      ),
                                      if (meta.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          meta,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    _PaginationRow(
                      meta: result.meta,
                      loading: _loading,
                      onPrev: () => _load(page: _page - 1),
                      onNext: () => _load(page: _page + 1),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── CSV/Excel bulk import ────────────────────────────────────────────────────
// See CSV_MEDICINE_IMPORT_PARITY_PLAN.md — mirrors web's import modal.

class _ImportMedicinesDialog extends StatefulWidget {
  final VoidCallback onImported;

  const _ImportMedicinesDialog({required this.onImported});

  @override
  State<_ImportMedicinesDialog> createState() => _ImportMedicinesDialogState();
}

class _ImportMedicinesDialogState extends State<_ImportMedicinesDialog> {
  PlatformFile? _picked;
  bool _importing = false;
  bool _downloadingSample = false;
  MedicineImportResult? _result;

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xls', 'xlsx'],
    );
    if (file == null) return;
    setState(() {
      _picked = file;
      _result = null;
    });
  }

  Future<void> _downloadSample() async {
    setState(() => _downloadingSample = true);
    try {
      await MedicineService.instance.downloadSampleFile();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _downloadingSample = false);
    }
  }

  Future<void> _import() async {
    final path = _picked?.path;
    if (path == null) return;
    setState(() {
      _importing = true;
      _result = null;
    });
    try {
      final result = await MedicineService.instance.importMedicines(File(path));
      if (!mounted) return;
      setState(() {
        _importing = false;
        _result = result;
      });
      if (result.imported > 0) widget.onImported();
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      showAppSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.upload_file_rounded,
        title: 'CSV Upload',
        subtitle: 'Bulk import medicines',
        onClose: () => Navigator.pop(context),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Required Excel Format',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _csvChip('Medicine Name', required: true),
                    for (final c in [
                      'Medicine Type',
                      'Dosage',
                      'Duration',
                      'Qty',
                      'Company',
                      'Composition',
                      'Price',
                    ])
                      _csvChip(c, required: false),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Blue = required, gray = optional — only Medicine Name is required. Medicine Type & Dosage (if provided) must match existing entries (case-insensitive). Duplicate names are skipped.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _downloadingSample ? null : _downloadSample,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _downloadingSample
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              size: 14,
                              color: Color(0xFF1D4ED8),
                            ),
                      const SizedBox(width: 4),
                      const Text(
                        'Download a sample file',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Select File (.xlsx, .xls, .csv)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: Text(
                _picked?.name ?? 'Choose File',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primaryA30),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _result!.imported > 0
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFFEF2F2),
                border: Border.all(
                  color: _result!.imported > 0
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imported ${_result!.imported}, skipped ${_result!.skipped}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  if (_result!.errors.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _result!.errors
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• $e',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        AppSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        AppPrimaryButton(
          label: 'Import Now',
          icon: Icons.upload_rounded,
          loading: _importing,
          onPressed: _picked == null ? null : _import,
        ),
      ],
    );
  }

  Widget _csvChip(String label, {required bool required}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: required ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        color: required ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
      ),
    ),
  );
}

class _PaginationRow extends StatelessWidget {
  final MedMeta meta;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _PaginationRow({
    required this.meta,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (meta.lastPage <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: (meta.hasPrev && !loading) ? onPrev : null,
          ),
          Text(
            '${meta.currentPage} / ${meta.lastPage}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: (meta.hasNext && !loading) ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ── Medicine Groups tab (Pattern A: list + detail form) ──────────────────

class _MedicineGroupsTab extends StatefulWidget {
  const _MedicineGroupsTab();

  @override
  State<_MedicineGroupsTab> createState() => _MedicineGroupsTabState();
}

class _MedicineGroupsTabState extends State<_MedicineGroupsTab>
    with AutomaticKeepAliveClientMixin {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await MedicineService.instance.fetchGroups(page: p);
      if (mounted)
        setState(() {
          _result = r;
          _page = p;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _confirmDelete(MedGroup group) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Group',
      message: 'Delete "${group.name}"? All medicine rows will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await MedicineService.instance.deleteGroup(group.id);
      if (_selectedId == group.id) setState(() => _selectedId = null);
      await _load(page: _page);
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SplitPaneScaffold(
      showDetail: _selectedId != null || _creatingNew,
      onBack: () => setState(() {
        _selectedId = null;
        _creatingNew = false;
      }),
      listPane: _buildListPane(),
      detailPane: _buildDetailPane(),
      backLabel: 'Back to Groups',
      listPaneWidth: 340,
      gap: 16,
    );
  }

  Widget _buildListPane() {
    final result = _result;
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Prescription Groups',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : () => _load(page: _page),
                ),
                if (_medCanAdd)
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setState(() {
                      _creatingNew = true;
                      _selectedId = null;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading && result == null
                ? const AppSkeletonList(count: 5, itemHeight: 68)
                : _error != null && result == null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : (result == null || result.groups.isEmpty)
                ? Center(
                    child: Text(
                      'No medicine groups yet',
                      style: TextStyle(color: AppColors.textDisabled),
                    ),
                  )
                : AppRefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: result.groups.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.primaryA08),
                      itemBuilder: (_, i) {
                        final g = result.groups[i];
                        final active = _selectedId == g.id;
                        return Material(
                          color: active
                              ? AppColors.primaryA08
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedId = g.id;
                              _creatingNew = false;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: active
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${g.usageScope == 'ot'
                                              ? 'OT · '
                                              : g.usageScope == 'opd'
                                              ? 'OPD · '
                                              : g.usageScope == 'both'
                                              ? 'OPD + OT · '
                                              : ''}${g.itemsCount} medicine${g.itemsCount == 1 ? '' : 's'}${g.diagnosisValue != null ? ' · ${g.diagnosisValue}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_medCanDelete)
                                    TableIconAction(
                                      icon: Icons.delete_outline_rounded,
                                      tooltip: 'Delete',
                                      kind: TableActionKind.delete,
                                      onTap: () => _confirmDelete(g),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (result != null && result.meta.lastPage > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _PaginationRow(
                meta: result.meta,
                loading: _loading,
                onPrev: () => _load(page: _page - 1),
                onNext: () => _load(page: _page + 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailPane() {
    if (_creatingNew) {
      return _panelBox(
        child: _GroupFormPane(
          existing: null,
          onSaved: () {
            setState(() => _creatingNew = false);
            _load(page: _page);
          },
          onCancel: () => setState(() => _creatingNew = false),
        ),
      );
    }
    final group = _result?.groups.where((g) => g.id == _selectedId).firstOrNull;
    if (group == null) {
      return _panelBox(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 56,
                color: AppColors.primaryA22,
              ),
              const SizedBox(height: 12),
              Text(
                'Select a group to view or edit',
                style: TextStyle(fontSize: 13, color: AppColors.primaryA55),
              ),
            ],
          ),
        ),
      );
    }
    return _panelBox(
      child: FutureBuilder<MedGroup>(
        future: MedicineService.instance.fetchGroup(group.id),
        key: ValueKey(group.id),
        builder: (context, snap) {
          if (!snap.hasData)
            return const AppSkeletonList(
              count: 5,
              itemHeight: 60,
              padding: EdgeInsets.zero,
            );
          return _GroupFormPane(
            existing: snap.data,
            onSaved: () => _load(page: _page),
            onCancel: () => setState(() => _selectedId = null),
          );
        },
      ),
    );
  }

  Widget _panelBox({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDeco(),
    child: child,
  );
}

class _GroupFormPane extends StatefulWidget {
  final MedGroup? existing;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  const _GroupFormPane({
    required this.existing,
    required this.onSaved,
    required this.onCancel,
  });

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
  String? _usageScope;

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
    _usageScope = (g?.usageScope == 'opd' || g?.usageScope == 'ot')
        ? g!.usageScope
        : null;
    if (g != null && g.items.isNotEmpty) {
      _medIds = g.items.map((i) => i.medicineId).toList();
      _dosageIds = g.items.map((i) => i.dosageId).toList();
      _routeIds = g.items.map((i) => i.routeId).toList();
      _durationCtrls = g.items
          .map((i) => TextEditingController(text: i.duration ?? ''))
          .toList();
      _qtyCtrls = g.items
          .map((i) => TextEditingController(text: '${i.quantity}'))
          .toList();
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
    for (final c in _durationCtrls) {
      c.dispose();
    }
    for (final c in _qtyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _loadingFormData = true;
      _loadError = null;
    });
    try {
      final data = await MedicineService.instance.fetchGroupFormData();
      if (mounted)
        setState(() {
          _formData = data;
          _loadingFormData = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loadingFormData = false;
        });
    }
  }

  void _addRow() => setState(() {
    _medIds.add(null);
    _dosageIds.add(null);
    _routeIds.add(null);
    _durationCtrls.add(TextEditingController());
    _qtyCtrls.add(TextEditingController(text: '1'));
  });

  void _removeRow(int i) {
    if (_medIds.length <= 1) return;
    setState(() {
      _medIds.removeAt(i);
      _dosageIds.removeAt(i);
      _routeIds.removeAt(i);
      _durationCtrls[i].dispose();
      _durationCtrls.removeAt(i);
      _qtyCtrls[i].dispose();
      _qtyCtrls.removeAt(i);
    });
  }

  void _onMedicineSelected(int idx, int? medicineId) {
    setState(() {
      _medIds[idx] = medicineId;
      if (medicineId != null) {
        final af = _formData?.autoFillFor(medicineId);
        if (af != null) {
          if (af.dosageId != null) _dosageIds[idx] = af.dosageId;
          if (af.duration != null && af.duration!.isNotEmpty)
            _durationCtrls[idx].text = af.duration!;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    for (int i = 0; i < _medIds.length; i++) {
      if (_medIds[i] == null) {
        showAppSnackBar(
          context,
          'Row ${i + 1}: Select a medicine',
          isError: true,
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'group_code': _codeCtrl.text.trim().isEmpty
            ? null
            : _codeCtrl.text.trim(),
        'diagnosis_id': _diagnosisId,
        'usage_scope': _usageScope,
        'items': List.generate(
          _medIds.length,
          (i) => {
            'medicine_id': _medIds[i],
            'dosage_id': _dosageIds[i],
            'route_id': _routeIds[i],
            'duration': _durationCtrls[i].text.trim().isEmpty
                ? null
                : _durationCtrls[i].text.trim(),
            'quantity': int.tryParse(_qtyCtrls[i].text) ?? 1,
          },
        ),
      };
      if (widget.existing == null) {
        await MedicineService.instance.createGroup(payload);
      } else {
        await MedicineService.instance.updateGroup(
          widget.existing!.id,
          payload,
        );
      }
      if (mounted) {
        showAppSnackBar(context, 'Group saved.', isSuccess: true);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFormData)
      return const AppSkeletonList(
        count: 5,
        itemHeight: 60,
        padding: EdgeInsets.zero,
      );
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadFormData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final fd = _formData!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.collections_bookmark_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.existing == null
                      ? 'New Medicine Group'
                      : 'Edit Medicine Group',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 700;
                      final nameField = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _nameCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                          decoration: appFieldDecoration(
                            'Group Name *',
                            hint: 'e.g. Post-Op Cataract',
                          ),
                        ),
                      );
                      final codeField = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _codeCtrl,
                          decoration: appFieldDecoration(
                            'Group Code',
                            hint: 'e.g. GRP-001',
                          ),
                        ),
                      );
                      final typeField = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _usageScope,
                          isExpanded: true,
                          decoration: appFieldDecoration('Type *'),
                          items: const [
                            DropdownMenuItem(value: 'opd', child: Text('OPD')),
                            DropdownMenuItem(value: 'ot', child: Text('OT')),
                          ],
                          validator: (v) =>
                              v == null ? 'Select OPD or OT' : null,
                          onChanged: (v) => setState(() => _usageScope = v),
                        ),
                      );
                      final dxField = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<int?>(
                          initialValue: _diagnosisId,
                          isExpanded: true,
                          hint: const Text('— None —'),
                          decoration: appFieldDecoration(
                            'Diagnosis (optional)',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('— None —'),
                            ),
                            ...fd.diagnoses.map(
                              (d) => DropdownMenuItem<int?>(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _diagnosisId = v),
                        ),
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: nameField),
                                const SizedBox(width: 12),
                                Expanded(child: codeField),
                                const SizedBox(width: 12),
                                Expanded(child: typeField),
                                const SizedBox(width: 12),
                                Expanded(child: dxField),
                              ],
                            )
                          : Column(
                              children: [
                                nameField,
                                codeField,
                                typeField,
                                dxField,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Medicines',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text(
                          'Add Row',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    _medIds.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _rowCard(i, fd),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: widget.existing != null
                          ? 'Update Group'
                          : 'Save Group',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(int i, MedGroupFormData fd) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryA06,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (_medIds.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.red,
                  ),
                  onPressed: () => _removeRow(i),
                ),
            ],
          ),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 640;
              final medField = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<int>(
                  initialValue: _medIds[i],
                  isExpanded: true,
                  hint: const Text(
                    'Select medicine',
                    style: TextStyle(fontSize: 12),
                  ),
                  decoration: appFieldDecoration(
                    'Medicine *',
                  ).copyWith(isDense: true),
                  items: fd.medicines
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => _onMedicineSelected(i, v),
                ),
              );
              final dosField = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<int?>(
                  initialValue: _dosageIds[i],
                  isExpanded: true,
                  hint: const Text('—', style: TextStyle(fontSize: 12)),
                  decoration: appFieldDecoration(
                    'Dosage',
                  ).copyWith(isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('—')),
                    ...fd.dosages.map(
                      (d) => DropdownMenuItem<int?>(
                        value: d.id,
                        child: Text(d.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _dosageIds[i] = v),
                ),
              );
              final durField = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: _durationCtrls[i],
                  decoration: appFieldDecoration(
                    'Duration',
                    hint: 'e.g. 4 days',
                  ).copyWith(isDense: true),
                ),
              );
              final routeField = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<int?>(
                  initialValue: _routeIds[i],
                  isExpanded: true,
                  hint: const Text('—', style: TextStyle(fontSize: 12)),
                  decoration: appFieldDecoration(
                    'Route',
                  ).copyWith(isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('—')),
                    ...fd.routes.map(
                      (r) => DropdownMenuItem<int?>(
                        value: r.id,
                        child: Text(r.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _routeIds[i] = v),
                ),
              );
              final qtyField = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: _qtyCtrls[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFieldDecoration('Qty').copyWith(isDense: true),
                ),
              );
              if (!wide)
                return Column(
                  children: [
                    medField,
                    Row(
                      children: [
                        Expanded(child: dosField),
                        const SizedBox(width: 8),
                        Expanded(child: durField),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: routeField),
                        const SizedBox(width: 8),
                        SizedBox(width: 70, child: qtyField),
                      ],
                    ),
                  ],
                );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: medField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: dosField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: durField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: routeField),
                  const SizedBox(width: 8),
                  SizedBox(width: 70, child: qtyField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
