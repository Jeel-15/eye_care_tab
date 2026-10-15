import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/medicine_models.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_assistant_models.dart';
import '../models/ot_booking_models.dart';
import '../services/ot_assistant_service.dart';
import '../services/permission_service.dart';
import '../utils/date_format.dart';
import '../utils/ot_status_style.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_section_header.dart';
import '../widgets/form_kit.dart';
import '../widgets/table_row_action.dart';
import '../widgets/ot/ot_assistant_detail_dialog.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/currency_format.dart';
import '../utils/app_date_picker.dart';
import '../utils/refreshable.dart';

/// Tablet OT Assistant Dashboard — web-parity table redesign (2026-09-19),
/// matching `resources/views/hospital/ot/assistant/dashboard.blade.php`'s
/// "Surgery Queue" panel exactly: a colored panel header, Show-entries +
/// search + a single full-page table (Name / [Surgeon, admin-only] /
/// Surgery Type / Package / Payment / Status / Action) with "Showing X to
/// Y of Z entries" pagination — same shared `OtPanelHeader`/
/// `ScaledDataTable`/`TableToolsBar`/`TablePaginationFooter` widgets
/// already used by Patients, OT Appointments, OT Counsellor, OT
/// Accountant and OT Ward, instead of a sixth hand-duplicated copy of that
/// scaffolding. No more list+detail split.
///
/// Web confirmed (`OtAssistantController::dashboard()`): Action always has
/// TWO buttons — "View" (a read-only info modal, always visible, no
/// permission gate) and "Operate" (navigates to the Surgery Recording
/// Form, gated by `ot_surgery_record`) — the tablet's previous card list
/// only had "Operate" with no View equivalent, added here as
/// `_AssistantViewDialog`. The Surgeon column itself is conditionally
/// rendered — entirely absent (not just blank) for a non-admin assistant,
/// shown with a `Dr. {name}` or `-` value only for
/// superuser/hospital_admin (`$seeAll`), matched exactly by building the
/// column list conditionally rather than always including it. Status
/// badge shows the raw `ot_status` uppercased (this queue is always
/// `READY` — the controller filters to `STATUS_READY` only). Operate now
/// opens `_AssistantDetailPane` (unchanged Surgery Recording form) in a
/// modal dialog instead of a side detail-pane.
class OtAssistantDashboardScreen extends StatefulWidget {
  final UserInfo user;

  const OtAssistantDashboardScreen({super.key, required this.user});

  @override
  State<OtAssistantDashboardScreen> createState() =>
      _OtAssistantDashboardScreenState();
}

class _OtAssistantDashboardScreenState extends State<OtAssistantDashboardScreen>
    implements Refreshable {
  List<OtBookingSummary> _items = [];
  bool _loading = true;
  String? _error;

  // Web pull 2026-09-19: Queue/All toggle — 'queue' (Surgery Queue) or
  // 'history' (Surgery History, date-ranged).
  String _filter = 'queue';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _perPage = 10;
  int _page = 1;

  bool get _canSurgery => PermissionService.instance.can(Perm.otSurgeryRecord);
  // Matches web's `isSuperUser() || role.slug === 'hospital_admin'` exactly
  // (OtAssistantController::dashboard()) — admins see the Surgeon column
  // and every ready booking, not just their own.
  bool get _seeAll =>
      (widget.user.role?.isSuper ?? false) ||
      widget.user.role?.slug == 'hospital_admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      // Web pull 2026-10-05 (commit 65865858) — both tabs default to today
      // and accept the same date filter, not just History.
      final result = await OtAssistantService.instance.fetchBookings(
        filter: _filter,
        fromDate: toIsoDate(_fromDate),
        toDate: toIsoDate(_toDate),
        perPage: 200,
      );
      if (mounted)
        setState(() {
          _items = result.items;
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

  void _setFilter(String f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _search = '';
      _searchCtrl.clear();
    });
    _load();
  }

  void _setDateRange(DateTimeRange r) {
    setState(() {
      _fromDate = r.start;
      _toDate = r.end;
    });
    _load();
  }

  // Web parity (web pull 2026-09-30, `_view-modal.blade.php`) — shared with
  // the dashboard-home compact OT Assistant desk panel (see
  // `showOtAssistantBookingDetail`) so both surfaces always show the same
  // data instead of drifting apart.
  void _viewDetails(OtBookingSummary item) =>
      showOtAssistantBookingDetail(context, item);

  Future<void> _operate(OtBookingSummary item) async {
    await openOtSurgeryRecordingPane(
      context,
      bookingId: item.id,
      patientName: item.patient?.fullName ?? 'Patient',
      onSaved: _load,
    );
  }

  // ── Client-side search + pagination (web: real client-side DataTable
  // over the full result set — mirrored here) ──────────────────────────────

  List<OtBookingSummary> get _filteredItems {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (it) =>
              (it.patient?.fullName.toLowerCase().contains(q) ?? false) ||
              (it.otDoctor?.name.toLowerCase().contains(q) ?? false) ||
              (it.otType?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  int get _lastPage {
    final total = _filteredItems.length;
    if (_perPage <= 0 || total == 0) return 1;
    return (total / _perPage).ceil().clamp(1, 999999);
  }

  List<OtBookingSummary> get _pageItems {
    final all = _filteredItems;
    if (_perPage <= 0) return all;
    final start = (_page - 1) * _perPage;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + _perPage).clamp(0, all.length));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OtPanelHeader(
              icon: Icons.handyman_rounded,
              title: _filter == 'history' ? 'Surgery History' : 'Surgery Queue',
              subtitle: _filter == 'history'
                  ? 'Operated / discharged patients — view only.'
                  : 'Patients ready for OT — record the surgery.',
              actions: [
                SegmentedPillToggle<String>(
                  options: const [
                    (value: 'queue', label: 'Queue'),
                    (value: 'history', label: 'All'),
                  ],
                  selected: _filter,
                  onChanged: _setFilter,
                  trackColor: Colors.white.withValues(alpha: 0.15),
                  activeColor: Colors.white,
                  activeTextColor: AppColors.primary,
                  inactiveTextColor: Colors.white.withValues(alpha: 0.85),
                ),
                // Web pull 2026-10-05 (commit 65865858) — date range shows
                // on both tabs now, not just History.
                const SizedBox(width: 10),
                OtDateRangeChip(
                  from: _fromDate,
                  to: _toDate,
                  onChanged: _setDateRange,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
              ],
            ),
            TableToolsBar(
              perPage: _perPage,
              onPerPageChanged: (v) => setState(() {
                _perPage = v;
                _page = 1;
              }),
              searchCtrl: _searchCtrl,
              onSearchChanged: (v) => setState(() {
                _search = v;
                _page = 1;
              }),
            ),
            Expanded(child: _buildTableArea()),
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────

  List<ScaledTableColumn> get _columns => [
    const ScaledTableColumn('NAME', 160, grow: true),
    if (_seeAll) const ScaledTableColumn('SURGEON', 130, grow: true),
    // Web parity (`assistant/dashboard.blade.php`): OT Date column only
    // exists on the History/All tab, not Queue.
    if (_filter == 'history') const ScaledTableColumn('OT DATE', 100),
    const ScaledTableColumn('SURGERY TYPE', 150, grow: true),
    const ScaledTableColumn('PACKAGE', 130),
    const ScaledTableColumn('PAYMENT', 110),
    const ScaledTableColumn('STATUS', 110),
    const ScaledTableColumn('ACTION', 230, hug: true),
  ];

  Widget _buildTableArea() {
    if (_loading) return const AppSkeletonList();
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    return AppRefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ScaledDataTable(
          columns: _columns,
          rows: _pageItems.map(_rowCells).toList(),
          emptyMessage: _search.isNotEmpty
              ? 'No results match your search.'
              : 'No bookings ready for surgery.',
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final total = _filteredItems.length;
    final start = _perPage <= 0 ? 1 : ((_page - 1) * _perPage) + 1;
    final end = _perPage <= 0 ? total : (_page * _perPage).clamp(0, total);
    return TablePaginationFooter(
      total: total,
      currentPage: _page,
      lastPage: _lastPage,
      start: start,
      end: end,
      onPrev: () => setState(() => _page--),
      onNext: () => setState(() => _page++),
    );
  }

  List<Widget> _rowCells(OtBookingSummary item) {
    final ps = item.paymentStatus;
    return [
      Text(
        item.patient?.fullName ?? 'Patient',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      if (_seeAll)
        Text(
          item.otDoctor != null ? 'Dr. ${item.otDoctor!.name}' : '-',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      if (_filter == 'history')
        Text(
          formatPlainDate(item.surgeryDate) ?? '—',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      Text(
        item.otType ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryA08,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '${currentCurrencySymbol()}${(item.packageAmount ?? 0).toStringAsFixed(2)}',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      ps != null
          ? Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paymentStatusColor(ps).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  paymentStatusLabel(ps),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: paymentStatusColor(ps),
                  ),
                ),
              ),
            )
          : const Text(
              '—',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: otStatusColor(item.otStatus).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            item.otStatus.toUpperCase(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: otStatusColor(item.otStatus),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      ActionCluster(
        children: [
          _tableActionBtn(
            icon: Icons.visibility_outlined,
            label: 'View',
            onTap: () => _viewDetails(item),
          ),
          if (_filter != 'history' && _canSurgery)
            _tableActionBtn(
              icon: Icons.local_hospital_outlined,
              label: 'Operate',
              color: AppColors.primary,
              onTap: () => _operate(item),
            ),
        ],
      ),
    ];
  }

  Widget _tableActionBtn({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return TableLabelAction(
      icon: icon,
      label: label,
      onTap: onTap,
      tone: tableLabelToneFor(color),
    );
  }
}

// ── Surgery Record detail pane (embedded, not a full screen) ───────────────

/// One `_medicineRows` line — medicine is a dropdown pick (not free text, see
/// OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md G5) so it always resolves against
/// `Medicine::exists` server-side; dose stays free text like web.
class _MedRow {
  String? medicine;
  final TextEditingController doseCtrl = TextEditingController();
  _MedRow({this.medicine});
  void dispose() => doseCtrl.dispose();
}

class _AssistantDetailPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const _AssistantDetailPane({
    super.key,
    required this.bookingId,
    required this.patientName,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_AssistantDetailPane> createState() => _AssistantDetailPaneState();
}

class _AssistantDetailPaneState extends State<_AssistantDetailPane> {
  bool _loading = true;
  String? _loadError;
  OtSurgeryFormData? _formData;
  bool _saving = false;

  bool get _canLensRecord => PermissionService.instance.can(Perm.otLensRecord);
  bool get _canMedsTakehome =>
      PermissionService.instance.can(Perm.otMedsTakehome);

  final _otRoomCtrl = TextEditingController();
  final _complicationNotesCtrl = TextEditingController();
  final _bloodLossCtrl = TextEditingController();
  final _lensCompanyCtrl = TextEditingController();
  final _lensModelCtrl = TextEditingController();
  final _estimatedPowerCtrl = TextEditingController();
  final _lensCostCtrl = TextEditingController();

  String? _surgeryName;
  DateTime _surgeryDate = DateTime.now();
  // Eye Operated is locked to the booking's own eye (Recommend Surgery
  // selection) — matches web's `$lockedEye`, not a user-editable picker.
  String _lockedEye = 'RE';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _complicationStatus = 'none';
  String? _lensCategory;
  String? _lensType;
  String? _lensImplantation;
  int? _medicineGroupId;
  final List<_MedRow> _medicineRows = [_MedRow()];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _otRoomCtrl.dispose();
    _complicationNotesCtrl.dispose();
    _bloodLossCtrl.dispose();
    _lensCompanyCtrl.dispose();
    _lensModelCtrl.dispose();
    _estimatedPowerCtrl.dispose();
    _lensCostCtrl.dispose();
    for (final r in _medicineRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final formData = await OtAssistantService.instance.fetchSurgeryFormData(
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _formData = formData;

        final bookingEye = formData.booking.eye;
        _lockedEye =
            (bookingEye == 'RE' || bookingEye == 'LE' || bookingEye == 'Both')
            ? bookingEye!
            : 'RE';

        final apptSurgeryDate = formData.booking.surgeryDate;
        _surgeryDate = apptSurgeryDate != null
            ? (parseApiPlainDate(apptSurgeryDate) ?? DateTime.now())
            : DateTime.now();

        final otType = formData.booking.otType;
        if (otType != null &&
            formData.surgeryTypes.any((t) => t.surgeryName == otType)) {
          _surgeryName = otType;
        }

        final c = formData.counselling;
        _lensCategory = c?.lensCategory;
        _lensCompanyCtrl.text = c?.lensCompany ?? '';
        _lensModelCtrl.text = c?.lensModel ?? '';
        _lensType = c?.lensType;
        _estimatedPowerCtrl.text = c?.estimatedPower?.toString() ?? '';
        _lensCostCtrl.text = c?.lensCost != null
            ? c!.lensCost!.toStringAsFixed(2)
            : '';
        _lensImplantation = c?.lensImplantation == null
            ? null
            : (c!.lensImplantation! ? 'yes' : 'no');

        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _pickSurgeryDate() async {
    final date = await showAppDatePicker(
      context: context,
      initialDate: _surgeryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _surgeryDate = date);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = (isStart ? _startDateTime : _endDateTime) ?? DateTime.now();
    final date = await showAppDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart)
        _startDateTime = combined;
      else
        _endDateTime = combined;
    });
  }

  void _addMedicineRow() => setState(() => _medicineRows.add(_MedRow()));

  /// Removing the last remaining row clears it instead of deleting it —
  /// matches web's JS behaviour exactly (a row is always present).
  void _removeMedicineRow(int i) {
    if (_medicineRows.length == 1) {
      setState(() {
        _medicineRows[i].medicine = null;
        _medicineRows[i].doseCtrl.clear();
      });
      return;
    }
    setState(() {
      _medicineRows[i].dispose();
      _medicineRows.removeAt(i);
    });
  }

  /// Wipes and rebuilds the medicine row list from the selected group's
  /// items — matches web's quick-fill behaviour, incl. composing dose from
  /// `frequency + duration` (not dosage text).
  void _applyMedicineGroup(MedGroup group) {
    setState(() {
      for (final r in _medicineRows) {
        r.dispose();
      }
      _medicineRows.clear();
      _medicineGroupId = group.id;
      for (final item in group.items) {
        if (item.medicineName == null || item.medicineName!.isEmpty) continue;
        _medicineRows.add(
          _MedRow(medicine: item.medicineName)
            ..doseCtrl.text = item.quickFillDose,
        );
      }
      if (_medicineRows.isEmpty) _medicineRows.add(_MedRow());
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
  String _fmtDisplayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtDisplayDateTime(DateTime? d) => d == null
      ? 'Select'
      : '${_fmtDisplayDate(d)} ${TimeOfDay.fromDateTime(d).format(context)}';

  Future<void> _save() async {
    if (_surgeryName == null || _surgeryName!.isEmpty) {
      showAppSnackBar(context, 'Surgery name is required', isError: true);
      return;
    }
    if (_complicationStatus != 'none' &&
        _complicationNotesCtrl.text.trim().isEmpty) {
      showAppSnackBar(
        context,
        'Complication notes are required when a complication is recorded',
        isError: true,
      );
      return;
    }
    if (_startDateTime != null &&
        _endDateTime != null &&
        !_endDateTime!.isAfter(_startDateTime!)) {
      showAppSnackBar(
        context,
        'End time must be after start time',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await OtAssistantService.instance.storeSurgery(
        widget.bookingId,
        surgeryDate: _fmtDate(_surgeryDate),
        surgeryName: _surgeryName!,
        otRoom: _otRoomCtrl.text.trim().isEmpty
            ? null
            : _otRoomCtrl.text.trim(),
        eyeOperated: _lockedEye,
        startTime: _startDateTime == null
            ? null
            : _fmtDateTime(_startDateTime!),
        endTime: _endDateTime == null ? null : _fmtDateTime(_endDateTime!),
        complicationStatus: _complicationStatus,
        complicationNotes: _complicationNotesCtrl.text.trim().isEmpty
            ? null
            : _complicationNotesCtrl.text.trim(),
        bloodLoss: _bloodLossCtrl.text.trim().isEmpty
            ? null
            : _bloodLossCtrl.text.trim(),
        medicineGroupId: _medicineGroupId,
        otMedicines: _medicineRows
            .where((r) => (r.medicine ?? '').isNotEmpty)
            .map(
              (r) => OtSurgeryMedicineLine(
                medicine: r.medicine!,
                dose: r.doseCtrl.text.trim().isEmpty
                    ? null
                    : r.doseCtrl.text.trim(),
              ),
            )
            .toList(),
        lensCategory: _lensCategory,
        lensCompany: _lensCompanyCtrl.text.trim().isEmpty
            ? null
            : _lensCompanyCtrl.text.trim(),
        lensModel: _lensModelCtrl.text.trim().isEmpty
            ? null
            : _lensModelCtrl.text.trim(),
        lensType: _lensType,
        estimatedPower: double.tryParse(_estimatedPowerCtrl.text.trim()),
        lensCost: double.tryParse(_lensCostCtrl.text.trim()),
        lensImplantation: _lensImplantation,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Surgery recorded successfully.',
        isSuccess: true,
      );
      widget.onSaved();
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

  InputDecoration _deco(String label, {String? hint}) =>
      appFieldDecoration(label, hint: hint);

  // Compact inline Yes/No — was two full-width Expanded boxes (each
  // stretched to half the row for just one word). A plain label + two
  // small chips reads just as clearly in a fraction of the width/height.
  Widget _lensImplantRow() {
    return Row(
      children: [
        Text(
          'Lens Implantation',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        ChoiceChip(
          label: const Text('Yes'),
          selected: _lensImplantation == 'yes',
          onSelected: (_) => setState(() => _lensImplantation = 'yes'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('No'),
          selected: _lensImplantation == 'no',
          onSelected: (_) => setState(() => _lensImplantation = 'no'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.primary),
              onPressed: widget.onClose,
              tooltip: 'Close',
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.blueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surgery Recording Form',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _formData != null
                        ? '${widget.patientName}${_formData!.booking.eye != null ? ' · ${_formData!.booking.eye}' : ''}'
                        : widget.patientName,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 5, itemHeight: 90)
              : _loadError != null
              ? AppErrorState(message: _loadError!, onRetry: _load)
              : _buildForm(),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final formData = _formData!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'A. Patient & Booking Details',
                  icon: Icons.badge_outlined,
                ),
                Wrap(
                  spacing: 32,
                  runSpacing: 6,
                  children: [
                    _readOnlyRow(
                      'Patient Name',
                      formData.booking.patient?.fullName ?? '—',
                    ),
                    _readOnlyRow(
                      'Phone',
                      formData.booking.patient?.contactNo ?? '—',
                    ),
                    _readOnlyRow(
                      'Package',
                      '${currentCurrencySymbol()}${(formData.counselling?.packageAmount ?? formData.booking.packageAmount ?? 0).toStringAsFixed(2)}',
                    ),
                    _readOnlyRow(
                      'Mediclaim',
                      (formData.counselling?.mediclaim ??
                              formData.booking.hasMediclaim ??
                              false)
                          ? 'YES'
                          : 'NO',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 220,
                  child: InkWell(
                    onTap: _pickSurgeryDate,
                    child: InputDecorator(
                      decoration: _deco('OT Date *'),
                      child: Text(_fmtDisplayDate(_surgeryDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const AppSectionHeader(
                  title: 'B. Surgery Details',
                  icon: Icons.local_hospital_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _surgeryName,
                        isExpanded: true,
                        decoration: _deco(
                          'Surgery Name *',
                          hint: 'Select surgery...',
                        ),
                        items: formData.surgeryTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.surgeryName,
                                child: Text(
                                  t.surgeryName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _surgeryName = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InputDecorator(
                        decoration: _deco('Eye Operated'),
                        child: Text(
                          _lockedEye,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _otRoomCtrl,
                        decoration: _deco('OT Room', hint: 'e.g. OT-1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(isStart: true),
                        child: InputDecorator(
                          decoration: _deco('Start Time'),
                          child: Text(_fmtDisplayDateTime(_startDateTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(isStart: false),
                        child: InputDecorator(
                          decoration: _deco('End Time'),
                          child: Text(_fmtDisplayDateTime(_endDateTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['none', 'minor', 'major']
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c[0].toUpperCase() + c.substring(1)),
                          selected: _complicationStatus == c,
                          onSelected: (_) =>
                              setState(() => _complicationStatus = c),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _complicationNotesCtrl,
                        maxLines: 2,
                        decoration: _deco(
                          'Complication Notes',
                          hint:
                              'Only required if complication status is minor/major',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _bloodLossCtrl,
                        decoration: _deco(
                          'Blood Loss',
                          hint: 'e.g. Minimal, 50ml',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_canLensRecord) ...[
                  const AppSectionHeader(
                    title: 'C. Lens Selection',
                    icon: Icons.remove_red_eye_outlined,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Auto-filled from Counsellor form — confirm or adjust if needed before saving surgery.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _lensCategory,
                          isExpanded: true,
                          decoration: _deco('Lens Category', hint: 'Select...'),
                          items: const [
                            DropdownMenuItem(
                              value: 'standard',
                              child: Text('Standard'),
                            ),
                            DropdownMenuItem(
                              value: 'premium',
                              child: Text('Premium'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _lensCategory = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lensCompanyCtrl,
                          decoration: _deco('Lens Company'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lensModelCtrl,
                          decoration: _deco('Lens Model'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _lensType,
                          isExpanded: true,
                          decoration: _deco('Lens Type', hint: 'Select...'),
                          items: formData.lensTypes
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _lensType = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _estimatedPowerCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _deco('Estimated Power'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lensCostCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _deco(
                            'Lens Cost (${currentCurrencySymbol()})',
                            hint: 'Enter lens cost',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _lensImplantRow(),
                  const SizedBox(height: 16),
                ],

                if (_canMedsTakehome) ...[
                  AppSectionHeader(
                    title: 'D. In-Ward Medicines',
                    icon: Icons.medication_outlined,
                    trailing: TextButton.icon(
                      onPressed: _addMedicineRow,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text(
                        'Add Medicine',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (formData.medicineGroups.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: _medicineGroupId,
                      isExpanded: true,
                      decoration: _deco(
                        'Quick-fill from OT Medicine Group',
                        hint: 'Select group (optional)...',
                      ),
                      items: formData.medicineGroups
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(
                                g.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _applyMedicineGroup(
                          formData.medicineGroups.firstWhere((g) => g.id == v),
                        );
                      },
                    ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _medicineRows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _medicineRows[i].medicine,
                              isExpanded: true,
                              decoration: _deco(
                                'Medicine',
                                hint: 'Select medicine...',
                              ),
                              items: formData.medicines
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _medicineRows[i].medicine = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _medicineRows[i].doseCtrl,
                              decoration: _deco('Dose / Frequency'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                              color: AppColors.red,
                            ),
                            onPressed: () => _removeMedicineRow(i),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 200,
              child: AppPrimaryButton(
                label: 'Save Surgery',
                icon: Icons.save_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyRow(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// Opens the same Surgery Recording Form pane the Surgery Queue table's
/// "Operate" action uses — shared with the dashboard home's compact OT
/// Assistant desk panel so both call the exact same code path instead of a
/// second copy of `_AssistantDetailPane`.
Future<void> openOtSurgeryRecordingPane(
  BuildContext context, {
  required int bookingId,
  required String patientName,
  required VoidCallback onSaved,
}) {
  return showPaneDialog<void>(
    context,
    wide: true,
    barrierDismissible: false,
    builder: (dCtx) => _AssistantDetailPane(
      key: ValueKey('assistant-$bookingId'),
      bookingId: bookingId,
      patientName: patientName,
      onClose: () => Navigator.pop(dCtx),
      onSaved: () {
        Navigator.pop(dCtx);
        onSaved();
      },
    ),
  );
}
