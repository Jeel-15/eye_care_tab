import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_location_master_models.dart';
import '../services/platform_location_master_service.dart';
import '../utils/app_decorations.dart';
import '../utils/app_dialogs.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/skeleton.dart';

/// Tablet Platform Location Master — top TabBar (4 tabs: Countries/States/
/// Districts/Cities), matching Medicines' flat-area convention. Mobile
/// already used AlertDialog forms (no bottom sheets), so almost no
/// adaptation was needed beyond the embedded-content shell. Business logic
/// (cascading filters, CRUD, active toggle) ported unchanged from
/// eye_care_app/lib/screens/platform_location_master_screen.dart.
class PlatformLocationMasterScreen extends StatefulWidget {
  final PlatformAdmin admin;
  const PlatformLocationMasterScreen({super.key, required this.admin});

  @override
  State<PlatformLocationMasterScreen> createState() => _PlatformLocationMasterScreenState();
}

class _PlatformLocationMasterScreenState extends State<PlatformLocationMasterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LocationDropdownData? _dropdownData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDropdown();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdown() async {
    final data = await PlatformLocationMasterService.instance.getDropdownData();
    if (!mounted) return;
    setState(() { _dropdownData = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppSkeletonList(count: 5, itemHeight: 68);
    if (_dropdownData == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.primaryA20),
          const SizedBox(height: 12),
          const Text('Could not load location data.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _loadDropdown, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA08)),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [Tab(text: 'Countries'), Tab(text: 'States'), Tab(text: 'Districts'), Tab(text: 'Cities')],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _CountriesTab(onDropdownRefresh: _loadDropdown),
            _StatesTab(dd: _dropdownData!),
            _DistrictsTab(dd: _dropdownData!),
            _CitiesTab(dd: _dropdownData!),
          ]),
        ),
      ],
    );
  }
}

// ── Countries Tab ─────────────────────────────────────────────────────────

class _CountriesTab extends StatefulWidget {
  final VoidCallback onDropdownRefresh;
  const _CountriesTab({required this.onDropdownRefresh});

  @override
  State<_CountriesTab> createState() => _CountriesTabState();
}

class _CountriesTabState extends State<_CountriesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformLocationMasterService.instance;
  final _searchCtrl = TextEditingController();
  List<MasterCountry> _items = [];
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

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
    final r = await _svc.getCountries(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({MasterCountry? item}) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final tzCtrl = TextEditingController(text: item?.defaultTimezone ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add Country' : 'Edit Country', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: SizedBox(width: 380, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Country Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 10),
          TextFormField(controller: tzCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Timezone (e.g. Asia/Kolkata) *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(item == null ? 'Add' : 'Save')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final tz = tzCtrl.text.trim();
    nameCtrl.dispose();
    tzCtrl.dispose();
    if (saved != true) return;
    final result = item == null ? await _svc.storeCountry(name, tz) : await _svc.updateCountry(item.id, name, tz);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      _load();
      widget.onDropdownRefresh();
    }
  }

  Future<void> _delete(MasterCountry c) async {
    if (!await showDeleteConfirmDialog(context, 'Delete "${c.name}"?', body: 'All states under this country will also be removed.')) return;
    final r = await _svc.deleteCountry(c.id);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) {
      _load();
      widget.onDropdownRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      AppSearchBar(controller: _searchCtrl, hint: 'Search countries...', onChanged: _onSearch),
      const SizedBox(height: 10),
      IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary), tooltip: 'Add Country', alignment: Alignment.centerRight),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 60)
            : _items.isEmpty
                ? AppEmptyState(message: 'No countries found', icon: Icons.public_off_rounded)
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final c = _items[i];
                          return _LocationCard(title: c.name, subtitle: c.defaultTimezone, badge: '${c.statesCount} states', badgeColor: AppColors.primary, isActive: c.isActive, onEdit: () => _showForm(item: c), onDelete: () => _delete(c), onToggle: () async {
                            await _svc.toggleCountry(c.id);
                            _load(page: _page);
                          });
                        },
                      ),
                    ),
                    if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                  ]),
      ),
    ]);
  }
}

// ── States Tab ────────────────────────────────────────────────────────────

class _StatesTab extends StatefulWidget {
  final LocationDropdownData dd;
  const _StatesTab({required this.dd});
  @override
  State<_StatesTab> createState() => _StatesTabState();
}

class _StatesTabState extends State<_StatesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformLocationMasterService.instance;
  final _searchCtrl = TextEditingController();
  int? _countryId;
  List<MasterState> _items = [];
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

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
    final r = await _svc.getStates(countryId: _countryId, search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({MasterState? item}) async {
    int? selCountryId = item?.countryId ?? _countryId;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add State' : 'Edit State', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: SizedBox(width: 380, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            key: ValueKey(selCountryId),
            initialValue: selCountryId,
            decoration: AppDecorations.inputDecoration(labelText: 'Country *'),
            items: widget.dd.countries.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => ss(() => selCountryId = v),
            validator: (v) => v == null ? 'Select country' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: nameCtrl, decoration: AppDecorations.inputDecoration(labelText: 'State Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(item == null ? 'Add' : 'Save')),
        ],
      )),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true) return;
    final result = item == null ? await _svc.storeState(selCountryId!, name) : await _svc.updateState(item.id, selCountryId!, name);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) _load();
  }

  Future<void> _delete(MasterState s) async {
    if (!await showDeleteConfirmDialog(context, 'Delete "${s.name}"?', body: 'All districts and cities under this state will also be removed.')) return;
    final r = await _svc.deleteState(s.id);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Row(children: [
        Expanded(child: _FilterDropdown<int?>(value: _countryId, hint: 'All Countries', items: [null, ...widget.dd.countries.map((c) => c.id)], label: (v) => v == null ? 'All Countries' : widget.dd.countries.firstWhere((c) => c.id == v).name, onChanged: (v) { setState(() => _countryId = v); _load(); })),
        const SizedBox(width: 10),
        IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary), tooltip: 'Add State'),
      ]),
      const SizedBox(height: 8),
      AppSearchBar(controller: _searchCtrl, hint: 'Search states...', onChanged: _onSearch),
      const SizedBox(height: 10),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 60)
            : _items.isEmpty
                ? AppEmptyState(message: 'No states found', icon: Icons.map_outlined)
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final s = _items[i];
                          return _LocationCard(title: s.name, subtitle: s.countryName ?? '', isActive: s.isActive, onEdit: () => _showForm(item: s), onDelete: () => _delete(s), onToggle: () async {
                            await _svc.toggleState(s.id);
                            _load(page: _page);
                          });
                        },
                      ),
                    ),
                    if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                  ]),
      ),
    ]);
  }
}

// ── Districts Tab ─────────────────────────────────────────────────────────

class _DistrictsTab extends StatefulWidget {
  final LocationDropdownData dd;
  const _DistrictsTab({required this.dd});
  @override
  State<_DistrictsTab> createState() => _DistrictsTabState();
}

class _DistrictsTabState extends State<_DistrictsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformLocationMasterService.instance;
  final _searchCtrl = TextEditingController();
  int? _stateId;
  List<MasterDistrict> _items = [];
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

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
    final r = await _svc.getDistricts(stateId: _stateId, search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({MasterDistrict? item}) async {
    int? selStateId = item?.stateId ?? _stateId;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(item == null ? 'Add District' : 'Edit District', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: SizedBox(width: 380, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            key: ValueKey(selStateId),
            initialValue: selStateId,
            decoration: AppDecorations.inputDecoration(labelText: 'State *'),
            items: widget.dd.states.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => ss(() => selStateId = v),
            validator: (v) => v == null ? 'Select state' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: nameCtrl, decoration: AppDecorations.inputDecoration(labelText: 'District Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(item == null ? 'Add' : 'Save')),
        ],
      )),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true) return;
    final result = item == null ? await _svc.storeDistrict(selStateId!, name) : await _svc.updateDistrict(item.id, selStateId!, name);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) _load();
  }

  Future<void> _delete(MasterDistrict d) async {
    if (!await showDeleteConfirmDialog(context, 'Delete "${d.name}"?')) return;
    final r = await _svc.deleteDistrict(d.id);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Row(children: [
        Expanded(child: _FilterDropdown<int?>(value: _stateId, hint: 'All States', items: [null, ...widget.dd.states.map((s) => s.id)], label: (v) => v == null ? 'All States' : widget.dd.states.firstWhere((s) => s.id == v).name, onChanged: (v) { setState(() => _stateId = v); _load(); })),
        const SizedBox(width: 10),
        IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary), tooltip: 'Add District'),
      ]),
      const SizedBox(height: 8),
      AppSearchBar(controller: _searchCtrl, hint: 'Search districts...', onChanged: _onSearch),
      const SizedBox(height: 10),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 60)
            : _items.isEmpty
                ? AppEmptyState(message: 'No districts found', icon: Icons.location_city_outlined)
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final d = _items[i];
                          return _LocationCard(title: d.name, subtitle: d.stateName ?? '', isActive: d.isActive, onEdit: () => _showForm(item: d), onDelete: () => _delete(d), onToggle: () async {
                            await _svc.toggleDistrict(d.id);
                            _load(page: _page);
                          });
                        },
                      ),
                    ),
                    if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                  ]),
      ),
    ]);
  }
}

// ── Cities Tab ────────────────────────────────────────────────────────────

class _CitiesTab extends StatefulWidget {
  final LocationDropdownData dd;
  const _CitiesTab({required this.dd});
  @override
  State<_CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<_CitiesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = PlatformLocationMasterService.instance;
  final _searchCtrl = TextEditingController();
  int? _stateId, _districtId;
  List<MasterCity> _items = [];
  int _page = 1, _lastPage = 1;
  bool _loading = true;
  Timer? _debounce;

  List<MasterDistrict> get _filteredDistricts => _stateId == null ? widget.dd.districts : widget.dd.districts.where((d) => d.stateId == _stateId).toList();

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
    final r = await _svc.getCities(stateId: _stateId, districtId: _districtId, search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), page: page);
    if (!mounted) return;
    setState(() { _loading = false; _items = r?.items ?? []; _page = page; _lastPage = r?.lastPage ?? 1; });
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load());
  }

  Future<void> _showForm({MasterCity? item}) async {
    int? selStateId = item?.stateId ?? _stateId;
    int? selDistrictId = item?.districtId ?? _districtId;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final stateDistricts = selStateId == null ? widget.dd.districts : widget.dd.districts.where((d) => d.stateId == selStateId).toList();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Text(item == null ? 'Add City' : 'Edit City', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          content: SizedBox(width: 380, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              key: ValueKey(selStateId),
              initialValue: selStateId,
              decoration: AppDecorations.inputDecoration(labelText: 'State *'),
              items: widget.dd.states.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (v) => ss(() { selStateId = v; selDistrictId = null; }),
              validator: (v) => v == null ? 'Select state' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              key: ValueKey('dist_$selDistrictId'),
              initialValue: stateDistricts.any((d) => d.id == selDistrictId) ? selDistrictId : null,
              decoration: AppDecorations.inputDecoration(labelText: 'District (optional)'),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('None')), ...stateDistricts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))],
              onChanged: (v) => ss(() => selDistrictId = v),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: nameCtrl, decoration: AppDecorations.inputDecoration(labelText: 'City Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          ])))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text(item == null ? 'Add' : 'Save')),
          ],
        );
      }),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true) return;
    final result = item == null ? await _svc.storeCity(stateId: selStateId!, districtId: selDistrictId, name: name) : await _svc.updateCity(item.id, stateId: selStateId!, districtId: selDistrictId, name: name);
    if (!mounted) return;
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) _load();
  }

  Future<void> _delete(MasterCity c) async {
    if (!await showDeleteConfirmDialog(context, 'Delete "${c.name}"?')) return;
    final r = await _svc.deleteCity(c.id);
    if (!mounted) return;
    showAppSnackBar(context, r.message, isSuccess: r.success, isError: !r.success);
    if (r.success) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Row(children: [
        Expanded(child: _FilterDropdown<int?>(value: _stateId, hint: 'All States', items: [null, ...widget.dd.states.map((s) => s.id)], label: (v) => v == null ? 'All States' : widget.dd.states.firstWhere((s) => s.id == v).name, onChanged: (v) { setState(() { _stateId = v; _districtId = null; }); _load(); })),
        const SizedBox(width: 8),
        Expanded(child: _FilterDropdown<int?>(value: _filteredDistricts.any((d) => d.id == _districtId) ? _districtId : null, hint: 'All Districts', items: [null, ..._filteredDistricts.map((d) => d.id)], label: (v) => v == null ? 'All Districts' : _filteredDistricts.firstWhere((d) => d.id == v).name, onChanged: (v) { setState(() => _districtId = v); _load(); })),
        const SizedBox(width: 10),
        IconButton(onPressed: () => _showForm(), icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary), tooltip: 'Add City'),
      ]),
      const SizedBox(height: 8),
      AppSearchBar(controller: _searchCtrl, hint: 'Search cities...', onChanged: _onSearch),
      const SizedBox(height: 10),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 60)
            : _items.isEmpty
                ? AppEmptyState(message: 'No cities found', icon: Icons.location_off_rounded)
                : Column(children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final c = _items[i];
                          final sub = [if (c.stateName != null) c.stateName!, if (c.districtName != null) c.districtName!].join(' › ');
                          return _LocationCard(title: c.name, subtitle: sub, isActive: c.isActive, onEdit: () => _showForm(item: c), onDelete: () => _delete(c), onToggle: () async {
                            await _svc.toggleCity(c.id);
                            _load(page: _page);
                          });
                        },
                      ),
                    ),
                    if (_lastPage > 1) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _page, totalPages: _lastPage, onPageChange: (p) => _load(page: p))),
                  ]),
      ),
    ]);
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const _FilterDropdown({required this.value, required this.hint, required this.items, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          hint: Text(hint, style: AppTextStyles.cardSubtitle),
          style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(label(v), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null || null is T) onChanged(v as T); },
        ),
      );
}

class _LocationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _LocationCard({required this.title, required this.subtitle, this.badge, this.badgeColor, required this.isActive, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: AppDecorations.card(),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: AppDecorations.pill(color: badgeColor ?? AppColors.primary), child: Text(badge!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor ?? AppColors.primary))),
              ],
            ]),
            if (subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis)],
          ])),
          Switch(value: isActive, onChanged: (_) => onToggle(), activeThumbColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          IconButton(icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.primary), onPressed: onEdit, padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), onPressed: onDelete, padding: const EdgeInsets.all(4), constraints: const BoxConstraints()),
        ]),
      );
}
