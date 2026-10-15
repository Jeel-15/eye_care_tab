import '../utils/date_format.dart';
import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/patient_history_models.dart';
import '../models/patient_models.dart';
import '../models/share_history_models.dart';
import '../services/patient_service.dart';
import '../services/share_history_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/form_kit.dart';
import '../widgets/retry_network_image.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/table_row_action.dart';
import '../widgets/table_pagination_footer.dart';
import 'patient_history_screen.dart';
import '../widgets/skeleton.dart';
import '../utils/app_date_picker.dart';

/// Tablet Share History module — top TabBar (3 tabs, matches Medicines'
/// flat-area convention) mirroring web's `doctor_history.blade.php` (the
/// only reachable "Share History" page per the nav — `hospital_history`
/// route/view exists but nothing links to it, so it is NOT the source of
/// truth). Filters stay in a persistent horizontal row instead of web's
/// AJAX-debounced form, and all three tabs' tabular data renders through
/// the shared [ScaledDataTable]/[TablePaginationFooter] (Pattern D), same
/// as Patients/OT Appointments. Business logic (search/filter/send/accept/
/// remove) ported from eye_care_app/lib/screens/share_history_screen.dart.
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
            _RequestsTab(user: widget.user, hospital: widget.hospital),
          ]),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Patient History
// Web column order (doctor_history.blade.php → patient-history-results
// partial): # · MRD No. · Patient Name · Hospital · Doctor Name · Date ·
// Contact · Age · Action.
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

  static const _columns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('MRD', 84),
    ScaledTableColumn('Patient', 170),
    ScaledTableColumn('Hospital', 130),
    ScaledTableColumn('Doctor', 130),
    ScaledTableColumn('Date', 90),
    ScaledTableColumn('Contact', 100),
    ScaledTableColumn('Age', 50, headerAlign: TextAlign.center),
    ScaledTableColumn('Action', 70, headerAlign: TextAlign.center),
  ];

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

  // Bug fix + UX fix (2026-10-05): this used to (a) build a Patient from
  // only the handful of fields HistoryPatient parses, so the History
  // screen's Info Grid — Doctor, Case, Date, Fee, City, Referred By, etc. —
  // rendered blank even though that data already exists on the patient's
  // real record, and (b) push PatientHistoryRoute as a full-screen route,
  // which read worse than the Patients screen's own floating-dialog
  // treatment for the exact same PatientHistoryScreen widget
  // (`_openHistoryDialog` in patients_screen.dart). `fetchOne()` hits the
  // same tenant-scoped `PatientApiController::show()` the Patients screen
  // already uses, so this (own-tenant) patient comes back fully populated;
  // the partner-hospital case below is a different, not-yet-built
  // cross-tenant flow and is left untouched.
  Future<void> _onView(HistoryPatient p) async {
    if (p.isOwn) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
      try {
        final patient = await PatientService.instance.fetchOne(p.id);
        if (!mounted) return;
        Navigator.pop(context);
        _openHistoryDialog(patient);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } else {
      Navigator.of(context, rootNavigator: true).push(appRoute(_PartnerPatientsView(user: widget.user, hospital: widget.hospital, partnerTenantId: p.tenantId, partnerName: p.tenantName ?? 'Partner Hospital')));
    }
  }

  void _notReady(String label) => showAppSnackBar(context, '$label — not built yet', duration: const Duration(seconds: 2));

  // Ported from patients_screen.dart's `_openHistoryDialog` — same
  // showGeneralDialog + custom fade/slide transition, same 900×760 centered
  // Dialog, so History opens identically everywhere it's reachable from.
  Future<void> _openHistoryDialog(Patient p) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dCtx, anim, secAnim) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PatientHistoryScreen(
              user: widget.user,
              hospital: widget.hospital,
              patient: p,
              onBack: () => Navigator.pop(dCtx),
              onNotReady: _notReady,
            ),
          ),
        ),
      ),
      transitionBuilder: (dCtx, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
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
          child: _TableCard(
            child: _loading
                ? const AppSkeletonList(count: 6, itemHeight: 70)
                : _error != null
                    ? AppErrorState(message: _error!, onRetry: () => _search(page: _page))
                    : _searched && _patients.isEmpty
                        ? const AppEmptyState(message: 'No history found.')
                        : Column(children: [
                            Expanded(child: _buildTable()),
                            if (_meta != null) _paginationFooter(_meta!, (p) => _search(page: p)),
                          ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Scrollbar(
      child: SingleChildScrollView(
        child: ScaledDataTable(
          columns: _columns,
          rows: List.generate(_patients.length, (i) => _rowCells(i, _patients[i])),
          emptyMessage: 'No history found.',
        ),
      ),
    );
  }

  List<Widget> _rowCells(int index, HistoryPatient p) {
    final perPage = _meta?.perPage ?? 20;
    final currentPage = _meta?.currentPage ?? _page;
    final serial = ((currentPage - 1) * perPage) + index + 1;
    return [
      Text('$serial', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Text(p.patientCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      Text(p.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: _HospBadge(isOwn: p.isOwn, name: p.tenantName)),
      Text(p.doctorName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(_formatDate(p.appointmentDate), style: const TextStyle(fontSize: 12)),
      Text(p.contactNo, style: const TextStyle(fontSize: 12)),
      Text('${p.age}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      TableIconAction(icon: Icons.visibility_outlined, tooltip: 'View', onTap: () => _onView(p)),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Hospital History
// Web column order (hospital-history-results.blade.php partial): # · Logo ·
// Hospital Name · City · District · State · Status (tenant plan status) ·
// Action (View + Request/Accept/Remove/Cancel).
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

  static const _columns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('Logo', 50, headerAlign: TextAlign.center),
    ScaledTableColumn('Hospital', 170),
    ScaledTableColumn('City', 100),
    ScaledTableColumn('District', 100),
    ScaledTableColumn('State', 100),
    ScaledTableColumn('Status', 80, headerAlign: TextAlign.center),
    ScaledTableColumn('Actions', 130, headerAlign: TextAlign.center),
  ];

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

  Future<bool> _confirm(String msg) => showAppConfirmDialog(context, title: 'Confirm', message: msg, confirmLabel: 'Yes', icon: Icons.link_off_rounded);

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
          child: _TableCard(
            child: _loading
                ? const AppSkeletonList(count: 6, itemHeight: 70)
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
                            if (_meta != null) _paginationFooter(_meta!, (p) => _load(page: p)),
                          ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Scrollbar(
      child: SingleChildScrollView(
        child: ScaledDataTable(
          columns: _columns,
          rows: List.generate(_hospitals.length, (i) => _rowCells(i, _hospitals[i])),
          emptyMessage: 'No hospitals found.',
        ),
      ),
    );
  }

  List<Widget> _rowCells(int index, ShareHospital h) {
    final perPage = _meta?.perPage ?? 20;
    final currentPage = _meta?.currentPage ?? _page;
    final serial = ((currentPage - 1) * perPage) + index + 1;
    return [
      Text('$serial', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Align(alignment: Alignment.center, child: _HospitalLogo(logoPath: h.logoPath)),
      Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primary)),
      Text(h.city ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(h.district ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(h.state ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Align(alignment: Alignment.center, child: _PlanStatusBadge(status: h.status)),
      _actionsCell(h),
    ];
  }

  Widget _actionsCell(ShareHospital h) {
    final req = h.requestInfo;
    return Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      TableIconAction(icon: Icons.visibility_outlined, tooltip: 'View', onTap: () => _openDetail(h)),
      ..._requestActionIcons(h, req),
    ]);
  }

  List<Widget> _requestActionIcons(ShareHospital h, ShareRequestInfo? req) {
    if (req == null) {
      return [TableIconAction(icon: Icons.send_rounded, tooltip: 'Send Request', onTap: () => _sendRequest(h))];
    }
    if (req.status == 'accepted') {
      return [TableIconAction(icon: Icons.link_off_rounded, tooltip: 'Remove Connection', kind: TableActionKind.delete, onTap: () => _removeRequest(h, req.id))];
    }
    if (req.direction == 'sent') {
      return [TableIconAction(icon: Icons.cancel_outlined, tooltip: 'Cancel Request', kind: TableActionKind.delete, onTap: () => _removeRequest(h, req.id))];
    }
    // Incoming (received) — Accept or Remove, same as the Requests tab.
    return [
      TableIconAction(icon: Icons.check_circle_rounded, tooltip: 'Accept', kind: TableActionKind.positive, onTap: () => _acceptRequest(h, req.id)),
      const SizedBox(width: 4),
      TableIconAction(icon: Icons.close_rounded, tooltip: 'Remove', kind: TableActionKind.delete, onTap: () => _removeRequest(h, req.id)),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Requests
// Web sections (doctor_history.blade.php, Request tab): Connected Hospitals
// (cards) → Incoming Requests (table: # · From Hospital · City · State ·
// Requested On · Action) → Sent Requests (table: # · To Hospital · City ·
// State · Sent On · Status · Action).
// ═══════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  const _RequestsTab({required this.user, required this.hospital});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;
  ConnectionsData? _data;

  static const _incomingColumns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('From Hospital', 180),
    ScaledTableColumn('City', 110),
    ScaledTableColumn('State', 100),
    ScaledTableColumn('Requested On', 110),
    ScaledTableColumn('Action', 100, headerAlign: TextAlign.center),
  ];

  static const _sentColumns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('To Hospital', 180),
    ScaledTableColumn('City', 110),
    ScaledTableColumn('State', 100),
    ScaledTableColumn('Sent On', 100),
    ScaledTableColumn('Status', 110, headerAlign: TextAlign.center),
    ScaledTableColumn('Action', 90, headerAlign: TextAlign.center),
  ];

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
    final ok = await showAppConfirmDialog(context, title: 'Remove Request', message: 'Are you sure you want to remove this request?', confirmLabel: 'Remove', destructive: true, icon: Icons.link_off_rounded);
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

  void _viewPartnerHistory(SharePartner partner) {
    Navigator.of(context, rootNavigator: true).push(appRoute(_PartnerPatientsView(user: widget.user, hospital: widget.hospital, partnerTenantId: partner.id, partnerName: partner.name)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 90);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final data = _data!;
    return AppRefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        children: [
          // ── Connected Hospitals (cards — matches web's card grid, not a table) ──
          if (data.accepted.isNotEmpty) ...[
            _SectionHeader(title: 'Connected Hospitals', trailing: '${data.accepted.length} Active'),
            const SizedBox(height: 10),
            _cardGrid(data.accepted.map((c) => _ConnectedCard(connection: c, onViewHistory: () => _viewPartnerHistory(c.partner))).toList()),
            const SizedBox(height: 20),
          ],

          // ── Incoming Requests ──────────────────────────────────────
          _SectionHeader(title: 'Incoming Requests', badge: data.incoming.isNotEmpty ? '${data.incoming.length} NEW' : null),
          const SizedBox(height: 10),
          if (data.incoming.isEmpty)
            const AppEmptyState(message: 'No incoming requests.')
          else
            _TableCard(
              child: ScaledDataTable(
                columns: _incomingColumns,
                rows: List.generate(data.incoming.length, (i) => _incomingRowCells(i, data.incoming[i])),
                emptyMessage: 'No incoming requests.',
              ),
            ),
          const SizedBox(height: 20),

          // ── Sent Requests ────────────────────────────────────────────
          _SectionHeader(title: 'Sent Requests'),
          const SizedBox(height: 10),
          if (data.sent.isEmpty)
            const AppEmptyState(message: 'No sent requests.')
          else
            _TableCard(
              child: ScaledDataTable(
                columns: _sentColumns,
                rows: List.generate(data.sent.length, (i) => _sentRowCells(i, data.sent[i])),
                emptyMessage: 'No sent requests.',
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _incomingRowCells(int index, IncomingRequest req) {
    final f = req.fromTenant;
    return [
      Text('${index + 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primary)),
      Text(f.city ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(f.state ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(_formatDate(req.createdAt), style: const TextStyle(fontSize: 12)),
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        TableIconAction(icon: Icons.check_circle_rounded, tooltip: 'Accept', kind: TableActionKind.positive, onTap: () => _acceptRequest(req)),
        const SizedBox(width: 4),
        TableIconAction(icon: Icons.close_rounded, tooltip: 'Remove', kind: TableActionKind.delete, onTap: () => _removeRequest(req.id)),
      ]),
    ];
  }

  List<Widget> _sentRowCells(int index, SentRequest req) {
    final t = req.toTenant;
    return [
      Text('${index + 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primary)),
      Text(t.city ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(t.state ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(_formatDate(req.createdAt), style: const TextStyle(fontSize: 12)),
      Align(alignment: Alignment.center, child: _SentStatusBadge(status: req.status)),
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        if (req.status == 'accepted') TableIconAction(icon: Icons.visibility_outlined, tooltip: 'View History', kind: TableActionKind.history, onTap: () => _viewPartnerHistory(t)),
        if (req.status == 'accepted') const SizedBox(width: 4),
        TableIconAction(icon: Icons.close_rounded, tooltip: 'Cancel', kind: TableActionKind.delete, onTap: () => _removeRequest(req.id)),
      ]),
    ];
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
// Web column order (partner_history.blade.php): # · MRD No. · Patient Name ·
// Doctor · Date · Contact No. · Age · Action. Web's Action links to a
// cross-tenant "shared patient history" page — ported 2026-10-05 via
// ShareHistoryApiController::patientHistory() + fetchPartnerPatientHistory(),
// opened the same way own-tenant History opens (_openHistoryDialog).
// ═══════════════════════════════════════════════════════════════════════════

class _PartnerPatientsView extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final int partnerTenantId;
  final String partnerName;

  const _PartnerPatientsView({required this.user, required this.hospital, required this.partnerTenantId, required this.partnerName});

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

  static const _columns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('MRD', 84),
    ScaledTableColumn('Patient', 190),
    ScaledTableColumn('Doctor', 140),
    ScaledTableColumn('Date', 100),
    ScaledTableColumn('Contact', 110),
    ScaledTableColumn('Age', 60, headerAlign: TextAlign.center),
    ScaledTableColumn('Action', 70, headerAlign: TextAlign.center, hug: true),
  ];

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

  List<Widget> _rowCells(int index, HistoryPatient p) {
    final perPage = _meta?.perPage ?? 20;
    final currentPage = _meta?.currentPage ?? _page;
    final serial = ((currentPage - 1) * perPage) + index + 1;
    return [
      Text('$serial', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Text(p.patientCode, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      Text(p.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(p.doctorName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      Text(_formatDate(p.appointmentDate), style: const TextStyle(fontSize: 12)),
      Text(p.contactNo, style: const TextStyle(fontSize: 12)),
      Text('${p.age}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      Align(
        alignment: Alignment.center,
        child: TableIconAction(
          icon: Icons.visibility_outlined,
          tooltip: 'View History',
          kind: TableActionKind.history,
          onTap: () => _onView(p),
        ),
      ),
    ];
  }

  // Bug fix (2026-10-05): web's equivalent list (`partner_history.blade.php`)
  // has a View action per row; this screen never did — the API this app
  // calls never had a cross-tenant history endpoint for it to hit. Opens
  // the same floating Dialog treatment Share History's own-tenant path uses.
  void _onView(HistoryPatient p) {
    final patient = Patient(
      id: p.id,
      patientCode: p.patientCode,
      firstName: p.firstName,
      lastName: p.lastName,
      fullName: p.fullName,
      age: p.age,
      contactNo: p.contactNo,
    );
    _openHistoryDialog(
      patient,
      historyLoader: (_) => ShareHistoryService.instance.fetchPartnerPatientHistory(p.allPatientIds),
    );
  }

  void _notReady(String label) => showAppSnackBar(context, '$label — not built yet', duration: const Duration(seconds: 2));

  Future<void> _openHistoryDialog(Patient p, {required Future<ExamHistoryData> Function(int) historyLoader}) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dCtx, anim, secAnim) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PatientHistoryScreen(
              user: widget.user,
              hospital: widget.hospital,
              patient: p,
              historyLoader: historyLoader,
              onBack: () => Navigator.pop(dCtx),
              onNotReady: _notReady,
            ),
          ),
        ),
      ),
      transitionBuilder: (dCtx, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton(tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.partnerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Text('Partner Hospital Patients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ])),
            ]),
            const SizedBox(height: 12),
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
              child: _TableCard(
                child: _loading
                    ? const AppSkeletonList(count: 6, itemHeight: 70)
                    : _error != null
                        ? AppErrorState(message: _error!, onRetry: () => _load(page: _page))
                        : _patients.isEmpty
                            ? const AppEmptyState(message: 'No patient records found.')
                            : Column(children: [
                                Expanded(
                                  child: Scrollbar(
                                    child: SingleChildScrollView(
                                      child: ScaledDataTable(
                                        columns: _columns,
                                        rows: List.generate(_patients.length, (i) => _rowCells(i, _patients[i])),
                                        emptyMessage: 'No patient records found.',
                                      ),
                                    ),
                                  ),
                                ),
                                if (_meta != null) _paginationFooter(_meta!, (p) => _load(page: p)),
                              ]),
              ),
            ),
          ],
        ),
          ),
        ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

/// The white rounded/elevated panel every tab in this screen wraps its
/// table/state content in — factored out so it isn't hand-duplicated 4x.
class _TableCard extends StatelessWidget {
  final Widget child;
  const _TableCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

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
            final picked = await showAppDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!));
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
      child: Text(isOwn ? 'OWN' : (name ?? 'Partner'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.5)),
    );
  }
}

/// Hospital's tenant/plan status badge — web's Hospital History "Status"
/// column shows `$hospital->displayStatus()` (active/trial/grace), which is
/// unrelated to any share-connection state (that lives only in the Action
/// column's buttons).
class _PlanStatusBadge extends StatelessWidget {
  final String status;
  const _PlanStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'active':
        label = 'Active';
        color = AppColors.green;
      case 'trial':
        label = 'Trial';
        color = AppColors.orange;
      default:
        label = 'Grace';
        color = AppColors.red;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)));
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

/// A tenant's logo in the Hospital History table (web: `hosp-logo` <img> or
/// `hosp-logo-placeholder`). `logo_path` is a storage-relative path, same as
/// web's `asset('storage/'.$hospital->logo_path)` — resolved against the
/// API's own origin since the app only knows `AppConfig.apiBaseUrl`.
class _HospitalLogo extends StatelessWidget {
  final String? logoPath;
  const _HospitalLogo({this.logoPath});

  static const _size = 34.0;

  String? get _url {
    final path = logoPath;
    if (path == null || path.isEmpty) return null;
    final api = Uri.parse(AppConfig.apiBaseUrl);
    final origin = Uri(scheme: api.scheme, host: api.host, port: api.hasPort ? api.port : null);
    return '$origin/storage/$path';
  }

  Widget _placeholder() => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.local_hospital_rounded, size: 16, color: AppColors.primary),
      );

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: _size,
        height: _size,
        child: RetryNetworkImage(url: url, fit: BoxFit.contain, fallbackBuilder: (_) => _placeholder()),
      ),
    );
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
        if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ]);
}

// ── Requests tab sub-cards (Connected Hospitals only — web renders these as
// cards, not a table; Incoming/Sent Requests are real web tables, handled
// via ScaledDataTable above) ──────────────────────────────────────────────

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
              Text([p.city, p.state].where((s) => (s ?? '').isNotEmpty).join(', '), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
    return AppDialog(
      size: AppDialogSize.small,
      header: EntityDialogHeader(
        name: widget.hospitalName,
        avatarColors: [AppColors.primary, AppColors.blueLight],
        facts: _detail == null
            ? null
            : HeaderFacts([
                HeaderFact('Doctors', '${_detail!.doctorsCount}'),
                HeaderFact('Staff', '${_detail!.staffCount}'),
                HeaderFact('Patients', '${_detail!.patientsCount}'),
              ]),
        onClose: () => Navigator.pop(context),
      ),
      body: _loading
          ? const AppSkeletonList(count: 3, itemHeight: 50, padding: EdgeInsets.symmetric(vertical: 12))
          : _error != null
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(_error!, style: const TextStyle(color: AppColors.red)))
              : _detail == null
                  ? const SizedBox.shrink()
                  : FactSheet(sections: [
                      FactSection('', [
                        Fact('Location', [
                          if (_detail!.city.trim().isNotEmpty) _detail!.city.trim(),
                          if (_detail!.state.trim().isNotEmpty) _detail!.state.trim(),
                        ].join(', ')),
                        Fact('Admin Email', _detail!.adminEmail),
                      ]),
                    ]),
      actions: [AppSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context))],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _formatDate(String iso) => iso.isEmpty ? '—' : formatDateString(iso);

/// The "Showing X to Y of Z entries ... Previous [n] Next" footer every
/// web-parity table in this app renders below its rows (see
/// [TablePaginationFooter]) — one helper shared by all three paginated
/// tables in this file (Patient History, Hospital History, Partner
/// Patients) instead of each computing start/end itself.
Widget _paginationFooter(ShareHistoryMeta meta, void Function(int page) onPage) {
  final start = meta.total == 0 ? 0 : ((meta.currentPage - 1) * meta.perPage) + 1;
  final end = meta.total == 0 ? 0 : (meta.currentPage * meta.perPage).clamp(0, meta.total);
  return TablePaginationFooter(
    total: meta.total,
    currentPage: meta.currentPage,
    lastPage: meta.lastPage,
    start: start,
    end: end,
    onPrev: () => onPage(meta.currentPage - 1),
    onNext: () => onPage(meta.currentPage + 1),
  );
}
