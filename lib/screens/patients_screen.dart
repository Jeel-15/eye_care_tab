import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/base_service.dart' show PermissionDeniedException;
import '../services/exam_masters_service.dart';
import '../services/patient_service.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import '../utils/date_format.dart';
import '../utils/refreshable.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/exam/dilation_lock.dart';
import '../widgets/form_kit.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/table_row_action.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import 'opd_bill_screen.dart';
import 'patient_checkin_screen.dart';
import 'patient_form_screen.dart';
import 'patient_history_screen.dart';
import 'primary_exam_screen.dart';
import 'secondary_exam_screen.dart';

/// Tablet Patients module — web parity redesign (2026-09-18): a single
/// full-width data table (# / MRD / Patient / Doctor / Fee-Type / Status /
/// Actions), matching `resources/views/hospital/patients/index.blade.php`
/// + its `partials/table.blade.php` exactly. Web's Patients page has never
/// been a list+detail split — it's one real (DataTables-powered) table,
/// with a permission-free "View" action opening a modal for full detail
/// and the rest of the actions (Primary/Secondary Exam, History, Print,
/// Edit, Check-in) as inline row icons, same permission keys as before.
///
/// Business logic (fetch/cache/search/paginate/add/edit/history/checkin/
/// print/exam, including the dilation double-tap-override lock) is
/// unchanged from the previous split-pane version — only the presentation
/// moved from a side detail-pane to per-row action icons + dialogs; the
/// Add/Edit forms open through `showPaneDialog`, the same host every other
/// form pane in the app uses.
class PatientsScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const PatientsScreen({super.key, required this.user, required this.hospital});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> implements Refreshable {
  bool _showAll = false;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  List<Patient> _patients = [];
  PatientStats? _stats;
  PatientMeta? _meta;
  bool _isLoading = false;
  bool _refreshing = false;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _goToPage(1);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) ExamMastersService.instance.prewarm();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _goToPage(_currentPage);

  String get _cacheScope => PatientService.scopeFor(
        hospitalSlug: widget.hospital.slug,
        userId: widget.user.id,
      );

  Future<void> _goToPage(int page) async {
    if (_isLoading) return;
    if (page == 1 && _patients.isEmpty && _search.isEmpty) {
      final cached = await PatientService.instance
          .getCachedPatients(showAll: _showAll, scope: _cacheScope);
      if (cached != null && mounted) {
        setState(() {
          _patients = cached.patients;
          _stats = cached.stats;
          _meta = cached.meta;
        });
      }
    }
    final hasData = _patients.isNotEmpty;
    setState(() {
      _isLoading = !hasData;
      _refreshing = hasData;
      _error = null;
      _currentPage = page;
    });
    try {
      final result = await PatientService.instance.fetchPatients(
        showAll: _showAll,
        search: _search,
        page: page,
        scope: _cacheScope,
      );
      if (!mounted) return;
      setState(() {
        _patients = result.patients;
        _stats = result.stats;
        _meta = result.meta;
      });
    } on PermissionDeniedException catch (e) {
      // A definitive "you're not allowed" answer must never be masked by
      // whatever stale cached list step above already rendered.
      // See ROLES_PERMISSIONS_DEEP_AUDIT_ROUND2.md Part B.
      if (mounted) {
        setState(() {
          _patients = [];
          _stats = null;
          _meta = null;
          _error = e.toString();
        });
      }
    } catch (e) {
      if (mounted && _patients.isEmpty) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _toggleShowAll(bool showAll) {
    if (_showAll == showAll) return;
    setState(() {
      _showAll = showAll;
      _patients = [];
      _meta = null;
      _stats = null;
    });
    _goToPage(1);
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search != val) {
        setState(() => _search = val);
        _goToPage(1);
      }
    });
  }

  // ── Dialog-based actions (replace the old embedded side-panel modes) ────

  void _afterSave() {
    // A role can be granted patient_register/patient_register_phone without
    // patient_view (e.g. a walk-in-desk-only role) — the save already
    // succeeded, but refreshing the list would hit a 403 on patient_view.
    // Skip the refresh entirely when the user can't view the list anyway.
    if (PermissionService.instance.can(Perm.opdPatientView)) {
      _goToPage(_currentPage);
    }
    showAppSnackBar(context, 'Saved.', isSuccess: true);
  }

  Future<void> _openAddDialog(PatientFormMode mode) async {
    await showPaneDialog<void>(
      context,
      builder: (dCtx) => PatientFormScreen(
        key: ValueKey('patient_form_${mode.name}'),
        mode: mode,
        user: widget.user,
        hospital: widget.hospital,
        onSaved: (saved) {
          Navigator.pop(dCtx);
          _afterSave();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openEditDialog(Patient p) async {
    await showPaneDialog<void>(
      context,
      builder: (dCtx) => PatientFormScreen(
        key: ValueKey('patient_form_edit_${p.id}'),
        mode: PatientFormMode.edit,
        patient: p,
        user: widget.user,
        hospital: widget.hospital,
        onSaved: (saved) {
          Navigator.pop(dCtx);
          _afterSave();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  // showGeneralDialog (not the plain showDialog every other dialog on this
  // screen uses) so this one specific dialog can get a gentler custom
  // transition — a slight upward slide + fade instead of the default
  // Material dialog's fade+scale-from-center "pop". Built from Flutter's
  // own FadeTransition/SlideTransition, no extra package. Left as the lone
  // exception for now (see PATIENT_HISTORY_MODAL_UX_PLAN.md) — once this
  // reads well the same treatment can be normalized onto
  // _openViewDialog/_openEditDialog/_openAddDialog too.
  Future<void> _openHistoryDialog(Patient p) async {
    // Client report (2026-10-07): the fixed 900 cap squeezed the exam
    // clinical-data view's new two-column layout into ~430px columns —
    // cramped tables that read as "everything shrunk" next to how the same
    // data shows inside the actual exam screens. Scales with the screen
    // instead (capped generously) so wide tablets get real room.
    final screen = MediaQuery.sizeOf(context);
    final dialogMaxWidth = (screen.width * 0.92).clamp(900.0, 1280.0);
    final dialogMaxHeight = (screen.height * 0.9).clamp(760.0, 860.0);
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
          constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: dialogMaxHeight),
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

  Future<void> _openViewDialog(Patient p) async {
    await showDialog<void>(
      context: context,
      builder: (dCtx) => _PatientDetailView(
        patient: p,
        currencySymbol: widget.hospital.currencySymbol,
        onClose: () => Navigator.pop(dCtx),
        onEdit: () { Navigator.pop(dCtx); _openEditDialog(p); },
        onHistory: () { Navigator.pop(dCtx); _openHistoryDialog(p); },
        onCheckin: () { Navigator.pop(dCtx); _openCheckin(p); },
        onPrimaryExam: () { Navigator.pop(dCtx); _openPrimaryExam(p); },
        onSecondaryExam: () { Navigator.pop(dCtx); _openSecondaryExam(p); },
        onPrintBill: () { Navigator.pop(dCtx); _openPrintBill(p); },
        onNotReady: _notReady,
      ),
    );
  }

  Future<void> _openCheckin(Patient p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PatientCheckinScreen(
        user: widget.user,
        hospital: widget.hospital,
        patient: p,
        onCancel: () => Navigator.pop(context),
        onDone: (updated) {
          Navigator.pop(context);
          _goToPage(_currentPage);
          Navigator.of(context, rootNavigator: true).push(appRoute(OpdBillScreen(user: widget.user, hospital: widget.hospital, patient: updated)));
        },
      ),
    );
  }

  void _openPrintBill(Patient p) {
    Navigator.of(context, rootNavigator: true).push(appRoute(OpdBillScreen(user: widget.user, hospital: widget.hospital, patient: p)));
  }

  void _notReady(String label) => showAppSnackBar(context, '$label — not built yet', duration: const Duration(seconds: 2));

  Future<void> _openPrimaryExam(Patient p) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(PrimaryExamScreen(user: widget.user, hospital: widget.hospital, patient: p)),
    );
    if (result == true && mounted) _goToPage(_currentPage);
  }

  // Only called once the caller already knows it's safe: either the patient
  // was never locked, or the countdown chip's own double-tap confirmation
  // already ran. No dialog here — matches web's plain (non-locked)
  // "Examine" link.
  Future<void> _openSecondaryExam(Patient p) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: p)),
    );
    if (result == true && mounted) _goToPage(_currentPage);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final perm = PermissionService.instance;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(perm),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _buildStatCards()),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _buildSearchBar()),
        if (_refreshing) LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, color: AppColors.primary),
        Expanded(child: _buildTableArea()),
        if (_meta != null) _buildPaginationBar(),
      ]),
    );
  }

  Widget _buildHeader(PermissionService perm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(children: [
        Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(_showAll ? 'All Patients' : "Today's Patients", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(width: 16),
        SegmentedPillToggle<bool>(
          options: const [(value: false, label: 'Today'), (value: true, label: 'All Patients')],
          selected: _showAll,
          onChanged: _toggleShowAll,
        ),
        const Spacer(),
        IconButton(icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh', onPressed: _isLoading ? null : () => _goToPage(_currentPage)),
        if (perm.can(Perm.opdPatientRegister)) ...[
          OutlinedButton.icon(
            onPressed: () => _openAddDialog(PatientFormMode.addWalkIn),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Walk-in'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22)),
          ),
          const SizedBox(width: 8),
        ],
        if (perm.can(Perm.opdPatientRegisterPhone))
          OutlinedButton.icon(
            onPressed: () => _openAddDialog(PatientFormMode.addPhone),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
            label: const Text('Phone Appt'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22)),
          ),
      ]),
    );
  }

  // Web parity: `patients-stats-wrap` has 4 cards (Total Patients / Waiting
  // / Primary Done / Completed) — the previous version here only had 3
  // (missing Primary Done, even though `PatientStats.primaryDone` was
  // already parsed and available).
  Widget _buildStatCards() {
    final s = _stats;
    return Row(children: [
      Expanded(child: _statChip('Total', s?.total ?? 0, AppColors.primary)),
      const SizedBox(width: 8),
      Expanded(child: _statChip('Waiting', s?.waiting ?? 0, AppColors.orange)),
      const SizedBox(width: 8),
      Expanded(child: _statChip('Primary Done', s?.primaryDone ?? 0, AppColors.blue)),
      const SizedBox(width: 8),
      Expanded(child: _statChip('Completed', s?.completed ?? 0, AppColors.green)),
    ]);
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search name, MRD or contact...',
        hintStyle: TextStyle(fontSize: 13, color: AppColors.primaryA45),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryA55, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primaryA55, size: 18), onPressed: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              })
            : null,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _buildPaginationBar() {
    final meta = _meta!;
    final lastPage = meta.lastPage;
    if (lastPage <= 1) return const SizedBox(height: 8);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), iconSize: 20, onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null),
        Text('Page $_currentPage / $lastPage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), iconSize: 20, onPressed: _currentPage < lastPage ? () => _goToPage(_currentPage + 1) : null),
      ]),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────
  //
  // Web parity: `hospital.patients.partials.table` — # / MRD / Patient /
  // Doctor / Fee-Type / Status / Actions columns, real DataTables search
  // (mirrored here by the existing debounced server-side search) and
  // pagination. Fixed column widths + a horizontal scroll (not
  // Expanded/flex columns) — a flex-based version of this exact pattern on
  // the doctor dashboard's tables squeezed the Actions column hard enough
  // that a button's own Text wrapped character-by-character; this avoids
  // that class of bug entirely by giving every column a comfortable fixed
  // width up front. A vertical scroll wraps the horizontal one so a full
  // page of rows never overflows the tablet shell's fixed content area.

  // Columns are fixed-width by design — a flex-based version of this exact
  // pattern on the doctor-dashboard tables squeezed a column narrow enough
  // that a button's own Text wrapped character-by-character. Rendered by
  // the shared [ScaledDataTable] (fixed-width columns that scale UP
  // together to fill available width when the rail collapses, horizontal
  // scroll fallback when space is tight) — the same component OT
  // Appointments and OT Counsellor's tables use, so this ~60-line
  // scaffolding is written once instead of duplicated per screen.
  static const _columns = [
    ScaledTableColumn('#', 36, headerAlign: TextAlign.center),
    ScaledTableColumn('MRD', 84),
    ScaledTableColumn('Patient', 220),
    ScaledTableColumn('Doctor', 130),
    ScaledTableColumn('Fee / Type', 100),
    ScaledTableColumn('Status', 130),
    ScaledTableColumn('Actions', 300),
  ];

  Widget _buildTableArea() {
    if (_isLoading) return const AppSkeletonList();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => _goToPage(_currentPage), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Retry')),
          ]),
        ),
      );
    }
    return AppRefreshIndicator(
      onRefresh: () => _goToPage(_currentPage),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ScaledDataTable(
          columns: _columns,
          rows: List.generate(_patients.length, (i) => _rowCells(i, _patients[i])),
          emptyMessage: _search.isNotEmpty ? 'No results match your search.' : 'No patients found.',
        ),
      ),
    );
  }

  List<Widget> _rowCells(int index, Patient p) {
    final perPage = _meta?.perPage ?? 20;
    final serial = ((_currentPage - 1) * perPage) + index + 1;
    return [
      Text('$serial', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryA55)),
      Align(alignment: Alignment.centerLeft, child: _mrdChip(p.patientCode)),
      _patientCell(p),
      Text(p.doctor?.name ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      _feeCell(p),
      Align(alignment: Alignment.centerLeft, child: _statusChipFor(p.status)),
      _actionsCell(p),
    ];
  }

  Widget _mrdChip(String code) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(6)),
        child: Text(code, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
      );

  Widget _patientCell(Patient p) {
    final subtitle = [
      if (p.age != null) '${p.age}y',
      if (p.gender != null) p.genderDisplay,
      if (p.contactNo != null) p.contactNo!,
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(p.fullName, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(subtitle, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    ]);
  }

  Widget _feeCell(Patient p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(p.caseFee != null ? '${widget.hospital.currencySymbol}${p.caseFee!.toInt()}' : '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(4)),
        child: Text(p.type == 'phone' ? 'Phone' : 'Walk-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryA70)),
      ),
    ]);
  }

  Widget _statusChipFor(PatientStatus status) {
    final (label, bg, fg) = switch (status) {
      PatientStatus.completed => ('Completed', AppColors.tealA13, const Color(0xFF0E9E82)),
      PatientStatus.primaryDone => ('Primary Done', AppColors.primaryA13, AppColors.primary),
      PatientStatus.waiting => ('Waiting', AppColors.orangeA13, const Color(0xFFE67E22)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // Web parity: `partials/table.blade.php`'s Actions column icon order —
  // View, divider, Primary Exam, Secondary Exam, divider, History, Print,
  // Edit, Check-in (phone only) — each gated by the same permission key
  // web uses (View itself is never permission-gated on web either).
  Widget _actionsCell(Patient p) {
    final perm = PermissionService.instance;
    final canCheckin = perm.can(Perm.opdPatientRegister) && p.type == 'phone' && p.caseId == null;
    final hasUtilGroup = perm.can(Perm.opdExamHistory) || perm.can(Perm.opdBillPrint) || perm.can(Perm.opdPatientEdit) || canCheckin;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        TableIconAction(icon: Icons.info_outline_rounded, tooltip: 'View', onTap: () => _openViewDialog(p)),
        _actionDivider(),
        // Web parity (`partials/table.blade.php`): both the Primary icon's
        // "done" state and the Secondary lock are driven by `$primary !==
        // null` — a primary_examination ROW existing at all (created by the
        // very first autosave) — not `primary_done_at` (only set once the
        // doctor actually finishes). `primaryDoneAt` here was stricter than
        // web: a patient with in-progress, not-yet-finished primary data
        // showed web's Secondary slot already unlocked while this screen
        // still showed it locked for the same patient.
        if (perm.can(Perm.opdExamPrimary))
          p.primaryExamination != null
              ? _doneIcon(Icons.assignment_turned_in_rounded, 'Primary Done')
              : TableIconAction(icon: Icons.assignment_outlined, tooltip: 'Primary Exam', onTap: () => _openPrimaryExam(p)),
        if (perm.can(Perm.opdExamSecondary))
          p.primaryExamination == null
              ? _doneIcon(Icons.lock_outline_rounded, 'Complete Primary First', muted: true)
              : p.secondaryDoneAt != null
                  ? _doneIcon(Icons.check_circle_rounded, 'Secondary Done')
                  : p.unlockTimeMs != null
                      ? _DilationChip(unlockTimeMs: p.unlockTimeMs!, onOverride: () => _openSecondaryExam(p))
                      : TableIconAction(icon: Icons.remove_red_eye_outlined, tooltip: 'Secondary Exam', onTap: () => _openSecondaryExam(p)),
        if (hasUtilGroup) _actionDivider(),
        if (perm.can(Perm.opdExamHistory))
          TableIconAction(icon: Icons.history_rounded, tooltip: 'History', kind: TableActionKind.history, onTap: () => _openHistoryDialog(p)),
        if (perm.can(Perm.opdBillPrint))
          TableIconAction(icon: Icons.print_outlined, tooltip: 'Print', kind: TableActionKind.print, onTap: () => _openPrintBill(p)),
        if (perm.can(Perm.opdPatientEdit))
          TableIconAction(icon: Icons.edit_outlined, tooltip: 'Edit', kind: TableActionKind.edit, onTap: () => _openEditDialog(p)),
        if (canCheckin)
          TableIconAction(icon: Icons.how_to_reg_rounded, tooltip: 'Check-in', kind: TableActionKind.positive, onTap: () => _openCheckin(p)),
      ]),
    );
  }

  Widget _doneIcon(IconData icon, String tooltip, {bool muted = false}) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: TableIconAction.size,
          height: TableIconAction.size,
          child: Icon(icon, size: 18, color: muted ? Colors.grey.shade400 : AppColors.teal),
        ),
      );

  Widget _actionDivider() => Container(width: 1, height: 20, color: AppColors.primaryA12, margin: const EdgeInsets.symmetric(horizontal: 2));
}

// ── Compact dilation countdown chip for the table's Actions column —
// web parity: single tap on the timer does nothing, only a double-tap
// opens the override confirmation; once unlocked it swaps to a plain
// "Secondary Exam" icon with no dialog at all. Same logic as
// `_DilationCountdownAction` below (still used by the View dialog's full
// detail layout), just sized to sit inline with the other row icons. ──────

class _DilationChip extends StatefulWidget {
  final int unlockTimeMs;
  final VoidCallback onOverride;
  const _DilationChip({required this.unlockTimeMs, required this.onOverride});

  @override
  State<_DilationChip> createState() => _DilationChipState();
}

class _DilationChipState extends State<_DilationChip> {
  Timer? _timer;
  String _text = '';
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final r = widget.unlockTimeMs - DateTime.now().millisecondsSinceEpoch;
    if (r <= 0) {
      _timer?.cancel();
      if (mounted) setState(() => _expired = true);
    } else {
      final mins = r ~/ 60000;
      final secs = (r % 60000) ~/ 1000;
      final txt = '$mins:${secs.toString().padLeft(2, '0')}';
      if (mounted && txt != _text) setState(() => _text = txt);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    final ok = await canStartSecondaryExam(context, widget.unlockTimeMs);
    if (ok) widget.onOverride();
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) {
      return TableIconAction(icon: Icons.remove_red_eye_outlined, tooltip: 'Secondary Exam', onTap: widget.onOverride);
    }
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Tooltip(
        message: 'Dilating — double-tap to override',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFF9800))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.hourglass_bottom_rounded, size: 12, color: Color(0xFFE65100)),
            const SizedBox(width: 3),
            Text(_text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
          ]),
        ),
      ),
    );
  }
}

// ── Detail view — the "View" action's modal ─────────────────────────────

class _PatientDetailView extends StatelessWidget {
  final Patient patient;
  final String currencySymbol;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onCheckin;
  final VoidCallback onPrimaryExam;
  final VoidCallback onSecondaryExam;
  final VoidCallback onPrintBill;
  final void Function(String label) onNotReady;

  const _PatientDetailView({required this.patient, required this.currencySymbol, required this.onClose, required this.onEdit, required this.onHistory, required this.onCheckin, required this.onPrimaryExam, required this.onSecondaryExam, required this.onPrintBill, required this.onNotReady});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final perm = PermissionService.instance;
    return AppDialog(
      size: AppDialogSize.large,
      header: EntityDialogHeader(
        name: p.fullName,
        pills: [
          Pill(p.patientCode, bg: AppColors.primaryA10, fg: AppColors.primary),
          if (p.age != null || p.gender != null) Pill([if (p.age != null) '${p.age}y', if (p.gender != null) p.genderDisplay].join(' · '), bg: AppColors.primaryA07, fg: AppColors.primary),
          ExamChip(label: 'Primary', done: p.primaryDoneAt != null, when: p.primaryDoneAt != null ? _fmtDate(p.primaryDoneAt) : null),
          ExamChip(label: 'Secondary', done: p.secondaryDoneAt != null, when: p.secondaryDoneAt != null ? _fmtDate(p.secondaryDoneAt) : null),
        ],
        facts: HeaderFacts([
          HeaderFact('Appointment', formatDateString(p.appointmentDate)),
          HeaderFact('Doctor', p.doctor?.name),
          HeaderFact('Case', p.caseType?.caseType),
          HeaderFact('Fee', p.caseFee != null ? '$currencySymbol${p.caseFee!.toInt()}' : null),
        ]),
        actions: [
          if (perm.can(Perm.opdPatientEdit)) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Edit', color: AppColors.primary),
        ],
        onClose: onClose,
      ),
      body: _body(p),
      actions: [
        AppSecondaryButton(label: 'Close', onPressed: onClose),
        // Same web-parity fix as `_actionsCell` above — gate by whether a
        // primary_examination row exists (`primaryExamination`), not by the
        // stricter `primaryDoneAt`.
        if (perm.can(Perm.opdExamPrimary) && p.primaryExamination == null) _actionBtn('Primary Exam', Icons.assignment_outlined, onPrimaryExam),
        if (perm.can(Perm.opdExamSecondary) && p.primaryExamination != null)
          p.unlockTimeMs != null
              ? _DilationCountdownAction(
                  unlockTimeMs: p.unlockTimeMs!,
                  onOverride: onSecondaryExam,
                  onExpired: _actionBtn('Secondary Exam', Icons.remove_red_eye_outlined, onSecondaryExam),
                )
              : _actionBtn('Secondary Exam', Icons.remove_red_eye_outlined, onSecondaryExam),
        if (perm.can(Perm.opdExamHistory)) _actionBtn('History', Icons.history_rounded, onHistory),
        if (perm.can(Perm.opdBillPrint)) _actionBtn('Print Bill', Icons.print_outlined, onPrintBill),
        if (perm.can(Perm.opdPatientRegister) && p.type == 'phone' && p.caseId == null) _actionBtn('Check-in', Icons.how_to_reg_rounded, onCheckin),
      ],
    );
  }

  Widget _body(Patient p) {
    final phone = p.contactNo?.trim() ?? '';
    final wa = p.whatsappNo?.trim() ?? '';
    return FactSheet(sections: [
      FactSection('', [
        Fact('Phone', phone.isEmpty ? null : phone),
        Fact('WhatsApp', wa.isEmpty || wa == phone ? null : wa),
        Fact('Location', p.location?.display),
        Fact('Occupation', p.occupation),
        Fact('Referrer', p.referrer?.name),
        Fact('Registered', p.createdAt == null ? null : _fmtDate(p.createdAt)),
      ]),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
    );
  }

  // Date+time (hospital-timezone-aware), matching web's `d M Y, h:i A`.
  String _fmtDate(DateTime? dt) => dt == null ? '—' : toDisplayDateTime(dt);
}

// ─── Dilation countdown action (View-dialog-sized, full button width) —
// web parity: single tap on the countdown does nothing, only a double-tap
// opens the override confirmation; once unlocked it swaps to [onExpired]
// (the plain "Secondary Exam" button) with no dialog at all. ───────────────

class _DilationCountdownAction extends StatefulWidget {
  final int unlockTimeMs;
  final VoidCallback onOverride;
  final Widget onExpired;
  const _DilationCountdownAction({required this.unlockTimeMs, required this.onOverride, required this.onExpired});

  @override
  State<_DilationCountdownAction> createState() => _DilationCountdownActionState();
}

class _DilationCountdownActionState extends State<_DilationCountdownAction> {
  Timer? _timer;
  String _text = '';
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final r = widget.unlockTimeMs - DateTime.now().millisecondsSinceEpoch;
    if (r <= 0) {
      _timer?.cancel();
      if (mounted) setState(() => _expired = true);
    } else {
      final mins = r ~/ 60000;
      final secs = (r % 60000) ~/ 1000;
      final txt = '$mins:${secs.toString().padLeft(2, '0')}';
      if (mounted && txt != _text) setState(() => _text = txt);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    final ok = await canStartSecondaryExam(context, widget.unlockTimeMs);
    if (ok) widget.onOverride();
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) return widget.onExpired;
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: const Color(0xFFFF9800)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.hourglass_bottom_rounded, size: 16, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Text(_text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
        ]),
      ),
    );
  }
}
