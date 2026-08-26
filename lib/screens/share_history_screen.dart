import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../models/share_history_models.dart';
import '../services/share_history_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import 'patient_history_route.dart';

/// Tablet Share History module — top TabBar (3 tabs, matches Medicines'
/// flat-area convention) replacing mobile's same-named tabs but with two
/// tablet-specific upgrades: filters stay in a persistent horizontal row
/// instead of an expand/collapse card, and both patient/hospital lists
/// render as a real DataTable (Pattern D) instead of card stacks. Business
/// logic (search/filter/send/accept/remove) ported unchanged from
/// eye_care_app/lib/screens/share_history_screen.dart.
class ShareHistoryScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final int initialTab;

  const ShareHistoryScreen({super.key, required this.user, required this.hospital, this.initialTab = 0});

  @override
  State<ShareHistoryScreen> createState() => _ShareHistoryScreenState();
}

class _ShareHistoryScreenState extends State<ShareHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
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
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA08)),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [Tab(text: 'Patient History'), Tab(text: 'Hospital History'), Tab(text: 'Requests')],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            _PatientHistoryTab(hospital: widget.hospital, user: widget.user),
            _HospitalHistoryTab(hospital: widget.hospital),
            _RequestsTab(hospital: widget.hospital),
          ]),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Patient History
// ═══════════════════════════════════════════════════════════════════════════

class _PatientHistoryTab extends StatefulWidget {
  final HospitalInfo hospital;
  final UserInfo user;
  const _PatientHistoryTab({required this.hospital, required this.user});

  @override
  State<_PatientHistoryTab> createState() => _PatientHistoryTabState();
}

class _PatientHistoryTabState extends State<_PatientHistoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _nameCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<HistoryPatient> _patients = [];
  ShareHistoryMeta? _meta;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doctorCtrl.dispose();
    _contactCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _search({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ShareHistoryService.instance.fetchPatients(patientName: _nameCtrl.text.trim(), doctorName: _doctorCtrl.text.trim(), contactNo: _contactCtrl.text.trim(), date: _dateCtrl.text, page: page);
      if (!mounted) return;
      setState(() { _patients = result.patients; _meta = result.meta; _page = page; _searched = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _nameCtrl.clear();
    _doctorCtrl.clear();
    _contactCtrl.clear();
    _dateCtrl.clear();
    _search();
  }

  void _onView(HistoryPatient p) {
    if (p.isOwn) {
      final patient = Patient(id: p.id, patientCode: p.patientCode, firstName: p.firstName, lastName: p.lastName, fullName: p.fullName, age: p.age, contactNo: p.contactNo);
      Navigator.of(context, rootNavigator: true).push(appRoute(PatientHistoryRoute(user: widget.user, hospital: widget.hospital, patient: patient)));
    } else {
      Navigator.of(context, rootNavigator: true).push(appRoute(_PartnerPatientsView(hospital: widget.hospital, partnerTenantId: p.tenantId, partnerName: p.tenantName ?? 'Partner Hospital')));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterBar(onFilter: () => _search(), onClear: _clear, fields: [
          _FilterField(controller: _nameCtrl, label: 'Patient Name', hint: 'Search patient...'),
          _FilterField(controller: _doctorCtrl, label: 'Doctor Name', hint: 'Search doctor...'),
          _FilterField(controller: _contactCtrl, label: 'Contact No.', hint: 'Contact number...', keyboardType: TextInputType.phone),
          _DateFilterField(controller: _dateCtrl, label: 'Date'),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? AppErrorState(message: _error!, onRetry: () => _search(page: _page))
                    : _searched && _patients.isEmpty
                        ? const AppEmptyState(message: 'No history found.')
                        : Column(children: [
                            Expanded(child: _buildTable()),
                            if (_meta != null && _meta!.lastPage > 1) _PaginationBar(current: _meta!.currentPage, last: _meta!.lastPage, total: _meta!.total, onPage: (p) => _search(page: p)),
                          ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    // DataTable shrink-wraps to its own content width by default — wrap in
    // ConstrainedBox(minWidth: ...) so it fills the pane instead of leaving
    // dead space when there are few rows/short values (same fix already
    // applied to reports_screen.dart/ot_report_viewer_screen.dart this pass).
    return Scrollbar(
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Hospital')),
                  DataColumn(label: Text('MRD')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Doctor')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Age')),
                  DataColumn(label: Text('')),
                ],
                rows: _patients.map((p) {
                  return DataRow(cells: [
                    DataCell(_HospBadge(isOwn: p.isOwn, name: p.tenantName)),
                    DataCell(Text(p.patientCode)),
                    DataCell(Text(p.fullName)),
                    DataCell(Text(p.doctorName ?? '—')),
                    DataCell(Text(_formatDate(p.appointmentDate))),
                    DataCell(Text(p.contactNo)),
                    DataCell(Text('${p.age}')),
                    DataCell(TextButton.icon(onPressed: () => _onView(p), icon: const Icon(Icons.arrow_forward_rounded, size: 15), label: const Text('View'))),
                  ]);
                }).toList(),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Hospital History
// ═══════════════════════════════════════════════════════════════════════════

class _HospitalHistoryTab extends StatefulWidget {
  final HospitalInfo hospital;
  const _HospitalHistoryTab({required this.hospital});

  @override
  State<_HospitalHistoryTab> createState() => _HospitalHistoryTabState();
}

class _HospitalHistoryTabState extends State<_HospitalHistoryTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<ShareHospital> _hospitals = [];
  ShareHistoryMeta? _meta;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ShareHistoryService.instance.fetchHospitals(hospName: _nameCtrl.text.trim(), city: _cityCtrl.text.trim(), district: _districtCtrl.text.trim(), state: _stateCtrl.text.trim(), page: page);
      if (!mounted) return;
      setState(() { _hospitals = result.hospitals; _meta = result.meta; _page = page; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _nameCtrl.clear();
    _cityCtrl.clear();
    _districtCtrl.clear();
    _stateCtrl.clear();
    _load();
  }

  Future<void> _openDetail(ShareHospital h) async {
    showDialog(context: context, builder: (_) => _HospitalDetailDialog(hospitalId: h.id, hospitalName: h.name));
  }

  Future<void> _sendRequest(ShareHospital h) async {
    final ok = await _confirm('Send request to ${h.name}?');
    if (!ok || !mounted) return;
    try {
      await ShareHistoryService.instance.sendRequest(h.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Request sent to ${h.name}.', isSuccess: true);
      _load(page: _page);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _acceptRequest(ShareHospital h, int reqId) async {
    final ok = await _confirm('Accept connection from ${h.name}?');
    if (!ok || !mounted) return;
    try {
      await ShareHistoryService.instance.acceptRequest(reqId);
      if (!mounted) return;
      showAppSnackBar(context, 'Connected with ${h.name}.', isSuccess: true);
      _load(page: _page);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _removeRequest(ShareHospital h, int reqId) async {
    final ok = await _confirm('Remove connection with ${h.name}?');
    if (!ok || !mounted) return;
    try {
      await ShareHistoryService.instance.removeRequest(reqId);
      if (!mounted) return;
      showAppSnackBar(context, 'Removed.', isSuccess: true);
      _load(page: _page);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<bool> _confirm(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text('Confirm', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterBar(onFilter: () => _load(), onClear: _clear, fields: [
          _FilterField(controller: _nameCtrl, label: 'Hospital Name', hint: 'Search hospital...'),
          _FilterField(controller: _cityCtrl, label: 'City', hint: 'City...'),
          _FilterField(controller: _districtCtrl, label: 'District', hint: 'District...'),
          _FilterField(controller: _stateCtrl, label: 'State', hint: 'State...'),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? AppErrorState(message: _error!, onRetry: () => _load(page: _page))
                    : _hospitals.isEmpty
                        ? const AppEmptyState(message: 'No hospitals found.', icon: Icons.apartment_rounded)
                        : Column(children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(children: [Icon(Icons.apartment_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 6), Text('Total: ${_meta?.total ?? 0} hospitals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary))]),
                            ),
                            Expanded(child: _buildTable()),
                            if (_meta != null && _meta!.lastPage > 1) _PaginationBar(current: _meta!.currentPage, last: _meta!.lastPage, total: _meta!.total, onPage: (p) => _load(page: p)),
                          ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Scrollbar(
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Hospital')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _hospitals.map((h) {
                  final req = h.requestInfo;
                  return DataRow(cells: [
                    DataCell(Text(h.name, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary))),
                    DataCell(Text([h.city, h.district, h.state].where((s) => (s ?? '').isNotEmpty).join(' · '))),
                    DataCell(_ReqStatusBadge(req: req)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(onPressed: () => _openDetail(h), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22)), child: const Text('View')),
                      const SizedBox(width: 6),
                      ..._actionButtons(h, req),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _actionButtons(ShareHospital h, ShareRequestInfo? req) {
    if (req == null) {
      return [ElevatedButton(onPressed: () => _sendRequest(h), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0), child: const Text('Request'))];
    }
    if (req.status == 'accepted') {
      return [OutlinedButton(onPressed: () => _removeRequest(h, req.id), style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: BorderSide(color: AppColors.red)), child: const Text('Remove'))];
    }
    if (req.direction == 'sent') {
      return [OutlinedButton(onPressed: () => _removeRequest(h, req.id), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: BorderSide(color: AppColors.primaryA22)), child: const Text('Cancel'))];
    }
    return [
      ElevatedButton(onPressed: () => _acceptRequest(h, req.id), style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0), child: const Text('Accept')),
      const SizedBox(width: 6),
      OutlinedButton(onPressed: () => _removeRequest(h, req.id), style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: BorderSide(color: AppColors.red)), child: const Text('✕')),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Requests
// ═══════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatefulWidget {
  final HospitalInfo hospital;
  const _RequestsTab({required this.hospital});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  ConnectionsData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ShareHistoryService.instance.fetchConnections();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptRequest(IncomingRequest req) async {
    try {
      await ShareHistoryService.instance.acceptRequest(req.id);
      if (!mounted) return;
      showAppSnackBar(context, 'Connected with ${req.fromTenant.name}.', isSuccess: true);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _removeRequest(int reqId) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text('Remove', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
            content: const Text('Are you sure you want to remove this request?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    try {
      await ShareHistoryService.instance.removeRequest(reqId);
      if (!mounted) return;
      showAppSnackBar(context, 'Removed.', isSuccess: true);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        children: [
          if (data.accepted.isNotEmpty) ...[
            _SectionHeader(title: 'Connected Hospitals', trailing: '${data.accepted.length} Active'),
            const SizedBox(height: 10),
            _cardGrid(data.accepted.map((c) => _ConnectedCard(connection: c, onViewHistory: () => Navigator.of(context, rootNavigator: true).push(appRoute(_PartnerPatientsView(hospital: widget.hospital, partnerTenantId: c.partner.id, partnerName: c.partner.name))))).toList()),
            const SizedBox(height: 20),
          ],
          _SectionHeader(title: 'Incoming Requests', badge: data.incoming.isNotEmpty ? '${data.incoming.length} NEW' : null),
          const SizedBox(height: 10),
          if (data.incoming.isEmpty) const AppEmptyState(message: 'No incoming requests.') else _cardGrid(data.incoming.map((req) => _IncomingRequestCard(request: req, onAccept: () => _acceptRequest(req), onRemove: () => _removeRequest(req.id))).toList()),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Sent Requests'),
          const SizedBox(height: 10),
          if (data.sent.isEmpty)
            const AppEmptyState(message: 'No sent requests.')
          else
            _cardGrid(data.sent.map((req) => _SentRequestCard(
                  request: req,
                  onViewHistory: req.status == 'accepted' ? () => Navigator.of(context, rootNavigator: true).push(appRoute(_PartnerPatientsView(hospital: widget.hospital, partnerTenantId: req.toTenant.id, partnerName: req.toTenant.name))) : null,
                  onRemove: () => _removeRequest(req.id),
                )).toList()),
        ],
      ),
    );
  }

  Widget _cardGrid(List<Widget> cards) {
    return LayoutBuilder(builder: (context, c) {
      final twoCol = c.maxWidth >= 720;
      if (!twoCol) return Column(children: cards);
      final cardWidth = (c.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: cards.map((w) => SizedBox(width: cardWidth, child: w)).toList());
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Partner Patients — full-screen route (pushed from Tab1 + Tab3)
// ═══════════════════════════════════════════════════════════════════════════

class _PartnerPatientsView extends StatefulWidget {
  final HospitalInfo hospital;
  final int partnerTenantId;
  final String partnerName;

  const _PartnerPatientsView({required this.hospital, required this.partnerTenantId, required this.partnerName});

  @override
  State<_PartnerPatientsView> createState() => _PartnerPatientsViewState();
}

class _PartnerPatientsViewState extends State<_PartnerPatientsView> {
  final _nameCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<HistoryPatient> _patients = [];
  ShareHistoryMeta? _meta;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doctorCtrl.dispose();
    _contactCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ShareHistoryService.instance.fetchPartnerPatients(widget.partnerTenantId, patientName: _nameCtrl.text.trim(), doctorName: _doctorCtrl.text.trim(), contactNo: _contactCtrl.text.trim(), date: _dateCtrl.text, page: page);
      if (!mounted) return;
      setState(() { _patients = result.patients; _meta = result.meta; _page = page; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.partnerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white)),
          const Text('Partner Hospital Patients', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterBar(onFilter: () => _load(), onClear: () {
              _nameCtrl.clear();
              _doctorCtrl.clear();
              _contactCtrl.clear();
              _dateCtrl.clear();
              _load();
            }, fields: [
              _FilterField(controller: _nameCtrl, label: 'Patient Name', hint: 'Search patient...'),
              _FilterField(controller: _doctorCtrl, label: 'Doctor Name', hint: 'Search doctor...'),
              _FilterField(controller: _contactCtrl, label: 'Contact No.', hint: 'Contact...', keyboardType: TextInputType.phone),
              _DateFilterField(controller: _dateCtrl, label: 'Date'),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null
                        ? AppErrorState(message: _error!, onRetry: () => _load(page: _page))
                        : _patients.isEmpty
                            ? const AppEmptyState(message: 'No patient records found.')
                            : Column(children: [
                                Expanded(
                                  child: Scrollbar(
                                    child: SingleChildScrollView(
                                      child: LayoutBuilder(builder: (context, constraints) {
                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                            child: DataTable(
                                              columns: const [DataColumn(label: Text('MRD')), DataColumn(label: Text('Name')), DataColumn(label: Text('Doctor')), DataColumn(label: Text('Date')), DataColumn(label: Text('Contact')), DataColumn(label: Text('Age'))],
                                              rows: _patients.map((p) => DataRow(cells: [DataCell(Text(p.patientCode)), DataCell(Text(p.fullName)), DataCell(Text(p.doctorName ?? '—')), DataCell(Text(_formatDate(p.appointmentDate))), DataCell(Text(p.contactNo)), DataCell(Text('${p.age}'))])).toList(),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                                if (_meta != null && _meta!.lastPage > 1) _PaginationBar(current: _meta!.currentPage, last: _meta!.lastPage, total: _meta!.total, onPage: (p) => _load(page: p)),
                              ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

class _FilterBar extends StatelessWidget {
  final List<Widget> fields;
  final VoidCallback onFilter;
  final VoidCallback onClear;

  const _FilterBar({required this.fields, required this.onFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.primaryA10), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2))]),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final f in fields) ...[Expanded(child: f), const SizedBox(width: 10)],
            _actions(),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: fields.map((f) => SizedBox(width: (c.maxWidth - 10) / 2, child: f)).toList()),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: _actions()),
        ]);
      }),
    );
  }

  Widget _actions() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton(onPressed: onClear, style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)), child: const Text('Clear')),
      const SizedBox(width: 10),
      ElevatedButton.icon(onPressed: onFilter, icon: const Icon(Icons.search_rounded, size: 16), label: const Text('Filter'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13))),
    ]);
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _FilterField({required this.controller, required this.label, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontSize: 12, color: AppColors.textDisabled), filled: true, fillColor: AppColors.primaryA06, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
      ),
    ]);
  }
}

class _DateFilterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _DateFilterField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setLocal) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!));
            if (picked != null) setLocal(() => controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
          },
          decoration: InputDecoration(
            hintText: 'Select date...',
            hintStyle: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            suffixIcon: controller.text.isEmpty ? Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textDisabled) : IconButton(icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textDisabled), onPressed: () => setLocal(() => controller.clear())),
            filled: true,
            fillColor: AppColors.primaryA06,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ]);
    });
  }
}

class _HospBadge extends StatelessWidget {
  final bool isOwn;
  final String? name;

  const _HospBadge({required this.isOwn, this.name});

  @override
  Widget build(BuildContext context) {
    final bg = isOwn ? AppColors.blueA12 : AppColors.greenA12;
    final fg = isOwn ? AppColors.blue : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Text(isOwn ? 'OWN' : (name ?? 'Partner'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.5)),
    );
  }
}

class _ReqStatusBadge extends StatelessWidget {
  final ShareRequestInfo? req;
  const _ReqStatusBadge({this.req});

  @override
  Widget build(BuildContext context) {
    if (req == null) return const SizedBox.shrink();
    String label;
    Color color;
    if (req!.status == 'accepted') {
      label = '✓ Connected';
      color = AppColors.green;
    } else if (req!.direction == 'sent') {
      label = '⏰ Requested';
      color = AppColors.orange;
    } else {
      label = '🔔 Incoming';
      color = AppColors.primary;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)));
  }
}

class _SentStatusBadge extends StatelessWidget {
  final String status;
  const _SentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'accepted':
        label = '✓ Connected';
        color = AppColors.green;
      case 'rejected':
        label = '✕ Rejected';
        color = AppColors.red;
      default:
        label = '⏰ Pending';
        color = AppColors.orange;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final String? badge;

  const _SectionHeader({required this.title, this.trailing, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary)),
        if (badge != null) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)))],
        const Spacer(),
        if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]);
}

class _PaginationBar extends StatelessWidget {
  final int current;
  final int last;
  final int total;
  final void Function(int) onPage;

  const _PaginationBar({required this.current, required this.last, required this.total, required this.onPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$total results · Page $current/$last', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), iconSize: 20, onPressed: current > 1 ? () => onPage(current - 1) : null),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), iconSize: 20, onPressed: current < last ? () => onPage(current + 1) : null),
        ]),
      ]),
    );
  }
}

// ── Requests tab sub-cards ────────────────────────────────────────────────

class _ConnectedCard extends StatelessWidget {
  final ShareConnection connection;
  final VoidCallback onViewHistory;

  const _ConnectedCard({required this.connection, required this.onViewHistory});

  @override
  Widget build(BuildContext context) {
    final p = connection.partner;
    return Container(
      decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.green, width: 1.5)),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(AppRadius.md)), child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
              Text([p.city, p.state].where((s) => (s ?? '').isNotEmpty).join(', '), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onViewHistory,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
            child: const Text('View Patient History →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  final IncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onRemove;

  const _IncomingRequestCard({required this.request, required this.onAccept, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final f = request.fromTenant;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: AppColors.primary, width: 4)), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.move_to_inbox_rounded, color: AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary)),
              Text([f.city, f.state].where((s) => (s ?? '').isNotEmpty).join(', '), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              if (request.createdAt.isNotEmpty) Text('Requested: ${_formatDate(request.createdAt)}', style: TextStyle(fontSize: 10, color: AppColors.textDisabled)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)), child: const Text('✓ Accept', style: TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: onRemove, style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: BorderSide(color: AppColors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)), child: const Text('✕ Remove', style: TextStyle(fontWeight: FontWeight.w800)))),
        ]),
      ]),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final SentRequest request;
  final VoidCallback? onViewHistory;
  final VoidCallback onRemove;

  const _SentRequestCard({required this.request, this.onViewHistory, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = request.toTenant;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA10), boxShadow: [BoxShadow(color: AppColors.primaryA06, blurRadius: 6, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.apartment_rounded, color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
            Text([t.city, t.state].where((s) => (s ?? '').isNotEmpty).join(', '), style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            if (request.createdAt.isNotEmpty) Text('Sent: ${_formatDate(request.createdAt)}', style: TextStyle(fontSize: 10, color: AppColors.textDisabled)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _SentStatusBadge(status: request.status),
          const SizedBox(height: 6),
          Row(children: [
            if (onViewHistory != null) TextButton(onPressed: onViewHistory, style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero), child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            if (onViewHistory != null) const SizedBox(width: 6),
            InkWell(onTap: onRemove, borderRadius: BorderRadius.circular(AppRadius.sm), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(border: Border.all(color: AppColors.red), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.red))),
          ]),
        ]),
      ]),
    );
  }
}

// ── Hospital Detail Dialog ──────────────────────────────────────────────

class _HospitalDetailDialog extends StatefulWidget {
  final int hospitalId;
  final String hospitalName;

  const _HospitalDetailDialog({required this.hospitalId, required this.hospitalName});

  @override
  State<_HospitalDetailDialog> createState() => _HospitalDetailDialogState();
}

class _HospitalDetailDialogState extends State<_HospitalDetailDialog> {
  bool _loading = true;
  HospitalDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ShareHistoryService.instance.fetchHospitalDetail(widget.hospitalId);
      if (!mounted) return;
      setState(() => _detail = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.hospitalName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.primary))),
              IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
            ]),
            if (_loading)
              Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(_error!, style: TextStyle(color: AppColors.red)))
            else if (_detail != null) ...[
              const SizedBox(height: 4),
              Text('${_detail!.city}, ${_detail!.state}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(children: [
                _DetailStat(label: 'Doctors', value: '${_detail!.doctorsCount}'),
                _vDivider,
                _DetailStat(label: 'Staff', value: '${_detail!.staffCount}'),
                _vDivider,
                _DetailStat(label: 'Patients', value: '${_detail!.patientsCount}'),
              ]),
              const SizedBox(height: 16),
              Row(children: [Icon(Icons.email_outlined, size: 14, color: AppColors.textDisabled), const SizedBox(width: 6), Text(_detail!.adminEmail, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
            ],
          ]),
        ),
      ),
    );
  }

  static final _vDivider = Container(width: 1, height: 36, color: AppColors.primaryA10, margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.primary)),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _formatDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return iso;
  }
}
