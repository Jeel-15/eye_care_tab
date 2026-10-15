import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/add_city_dialog.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../utils/date_format.dart';
import '../models/ot_appointment_models.dart';
import '../services/ot_appointment_service.dart';
import '../services/ot_slot_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/table_row_action.dart';
import '../widgets/app_dialog.dart';
import '../widgets/form_kit.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/app_date_picker.dart';

/// Opens the same edit dialog the dedicated screen's row Edit action uses —
/// exposed so [OtAppointmentDeskHomePanel]'s own compact preview rows can
/// reuse it without duplicating the dialog-building code.
Future<void> openOtAppointmentEditDialog(BuildContext context, OtAppointmentItem item, {required VoidCallback onSaved}) {
  return showPaneDialog<void>(
    context,
    barrierDismissible: false,
    builder: (dCtx) => OtAppointmentFormPane(
      key: ValueKey('ot_appt_form_edit_${item.id}'),
      item: item,
      onSaved: () {
        Navigator.pop(dCtx);
        onSaved();
      },
      onCancel: () => Navigator.pop(dCtx),
    ),
  );
}

// Matches web's `optional($appointment->appointment_date)->format('d M Y')`
// exactly — web's index table has no time column at all, only this date.
String _fmtAppointmentDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return toDisplayDate(d);
}

// Matches web's index Type badge: "OT" or Title-Case of phone/walk_in/online.
String _typeLabel(String type) => switch (type) {
  'phone' => 'Phone',
  'walk_in' => 'Walk-in',
  'online' => 'Online',
  'ot' => 'OT',
  _ => type,
};

/// Tablet OT Appointments — web-parity table redesign (2026-09-18), matching
/// `resources/views/hospital/ot/appointments/index.blade.php`'s real
/// DataTables-powered "Appointment Register" panel exactly: one single-page
/// table (APPT # / Patient / Mobile / Type / Date / Doctor / Status /
/// Action) with a status filter, client-side search + Show-entries +
/// "Showing X to Y of Z entries" pagination — no list+detail split, same as
/// the just-completed Patients screen redesign. Add/Edit now open the same
/// `OtAppointmentFormPane` in a modal dialog (the established
/// `dashboard_screen.dart` `_openWalkInFromOt` pattern already reused for
/// Patients) instead of a side detail-pane. All business logic (load/
/// confirm/cancel/save, slot-conflict lookups) is unchanged from before —
/// only the presentation moved from split-pane list tiles to table rows.
class OtAppointmentListScreen extends StatefulWidget {
  const OtAppointmentListScreen({super.key});

  @override
  State<OtAppointmentListScreen> createState() =>
      _OtAppointmentListScreenState();
}

class _OtAppointmentListScreenState extends State<OtAppointmentListScreen> {
  List<OtAppointmentItem> _items = [];
  bool _loading = true;
  String? _error;
  // Web pull 2026-10-07 — the 16-stage status filter was fully replaced by a
  // simple Booked/Completed tab system (new `ot_appointment` role's own
  // desk/dashboard). `meta.booked_count`/`meta.completed_count` are the
  // live per-tab totals, matching the tab pill badges.
  String _tab = 'booked';
  int _bookedCount = 0;
  int _completedCount = 0;
  // Web pull 2026-10-06 — index() defaults to today, widened via a
  // date-range picker. Defaulted client-side too, so the chip reads "Today"
  // rather than an empty placeholder on first open.
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _perPage = 10;
  int _currentPage = 1;

  bool get _canEdit => PermissionService.instance.can(Perm.otAppointmentEdit);

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });
    try {
      // perPage generous enough to cover a full result set in one page,
      // matching web's own "client-side DataTable" index — search/
      // Show-entries/pagination below all operate on this full list, same
      // as web's real DataTables instance.
      final result = await OtAppointmentService.instance.list(
        tab: _tab,
        fromDate: toIsoDate(_from),
        toDate: toIsoDate(_to),
        perPage: 200,
      );
      if (mounted)
        setState(() {
          _items = result.items;
          _bookedCount = result.bookedCount;
          _completedCount = result.completedCount;
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

  void _selectTab(String tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _load();
  }

  // ── Client-side search + pagination (mirrors web's real DataTables
  // instance, which loads the full result set once and does everything
  // below — search, Show-entries, pagination — purely in the browser) ──────

  List<OtAppointmentItem> get _searchedItems {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (it) =>
              it.fullName.toLowerCase().contains(q) ||
              it.mobileNo.toLowerCase().contains(q) ||
              it.appointmentNumber.toLowerCase().contains(q) ||
              (it.doctor?.name.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  int get _lastPage {
    final total = _searchedItems.length;
    if (_perPage <= 0 || total == 0) return 1;
    return (total / _perPage).ceil().clamp(1, 999999);
  }

  List<OtAppointmentItem> get _pageItems {
    final all = _searchedItems;
    if (_perPage <= 0) return all;
    final start = (_currentPage - 1) * _perPage;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + _perPage).clamp(0, all.length));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          _buildToolsBar(),
          Expanded(child: _buildTableArea()),
          _buildPaginationBar(),
        ],
      ),
    );
  }

  // Matches web's dark-navy "Appointment Register" panel header exactly
  // (same chrome `OtPanelHeader` also gives the OT Counsellor Dashboard's
  // two panels) — was previously a plain white header, under-matching the
  // real web screenshot.
  Widget _buildHeader() {
    return OtPanelHeader(
      icon: Icons.event_note_rounded,
      title: 'Appointment Register',
      subtitle:
          'Pre-registration appointments booked over phone/walk-in/online/referral.',
      actions: [
        _tabToggle(),
        const SizedBox(width: 6),
        _dateRangeChip(),
        const SizedBox(width: 6),
        IconButton(
          onPressed: _load,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // Web pull 2026-10-07 — the 16-stage status filter dropdown was replaced
  // by this simple Booked/Completed tab toggle (mirrors the new
  // `ot_appointment` role's dashboard desk panel's own tabs).
  Widget _tabToggle() {
    return SegmentedPillToggle<String>(
      options: [
        (value: 'booked', label: 'Booked ($_bookedCount)'),
        (value: 'completed', label: 'Completed ($_completedCount)'),
      ],
      selected: _tab,
      onChanged: _selectTab,
      trackColor: Colors.white.withValues(alpha: 0.15),
      activeColor: Colors.white,
      activeTextColor: AppColors.darkNavy,
      inactiveTextColor: Colors.white,
    );
  }

  Widget _dateRangeChip() {
    final sameDay =
        _from.year == _to.year && _from.month == _to.month && _from.day == _to.day;
    final today = DateTime.now();
    final isToday = sameDay && _from.year == today.year && _from.month == today.month && _from.day == today.day;
    final label = isToday
        ? 'Today'
        : sameDay
            ? toDisplayDate(_from)
            : '${toDisplayDate(_from)} – ${toDisplayDate(_to)}';
    return InkWell(
      onTap: _pickRange,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Widget _buildToolsBar() {
    return TableToolsBar(
      perPage: _perPage,
      onPerPageChanged: (v) => setState(() {
        _perPage = v;
        _currentPage = 1;
      }),
      searchCtrl: _searchCtrl,
      onSearchChanged: (v) => setState(() {
        _search = v;
        _currentPage = 1;
      }),
      searchHint: 'Search name, mobile or #...',
      searchWidth: 240,
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────
  //
  // Web parity: `hospital.ot.appointments.partials.table` — APPT# / Patient /
  // Mobile / Type / Date / Doctor / Status / Action columns, rendered by the
  // shared [ScaledDataTable] (fixed-width columns that scale up together to
  // fill available width, horizontal scroll fallback when tight).

  static const _columns = [
    ScaledTableColumn('APPT #', 96),
    ScaledTableColumn('PATIENT', 132, grow: true),
    ScaledTableColumn('MOBILE', 100),
    ScaledTableColumn('TYPE', 66),
    ScaledTableColumn('DATE', 88),
    ScaledTableColumn('DOCTOR', 110, grow: true),
    ScaledTableColumn('STATUS', 140),
    ScaledTableColumn('ACTION', 160, hug: true),
  ];

  Widget _buildTableArea() {
    if (_loading) return const AppSkeletonList();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.red,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: ScaledDataTable(
        columns: _columns,
        rows: _pageItems.map(_rowCells).toList(),
        emptyMessage: _search.isNotEmpty
            ? 'No results match your search.'
            : 'No appointments found.',
      ),
    );
  }

  List<Widget> _rowCells(OtAppointmentItem item) => [
    Text(
      item.appointmentNumber,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    Text(
      item.fullName,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.darkNavy,
      ),
    ),
    Text(
      item.mobileNo,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    _typeChip(item.appointmentType),
    Text(
      _fmtAppointmentDate(item.appointmentDate),
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
      item.doctor?.name ?? '—',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: StatusBadge.otAppointmentStage(
              item.stageBadgeClass,
              item.stageLabel,
            ),
          ),
          if ((item.stageSub ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.stageSub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    ),
    _actionsCell(item),
  ];

  Widget _typeChip(String type) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryA08,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          _typeLabel(type),
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
    );
  }

  // Web pull 2026-10-07 — Walk-In and Delete row actions are both gone from
  // this screen entirely (appointment creation now only happens via the
  // dashboard's "+ OT Appointment" quick-action; this undoes the earlier
  // Delete feature too). Edit is the sole remaining action, and only on the
  // Booked tab.
  Widget _actionsCell(OtAppointmentItem item) {
    final canEditRow = _tab == 'booked' && _canEdit;
    if (!canEditRow) {
      return Text(
        '-',
        style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TableIconAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          kind: TableActionKind.edit,
          onTap: () => openOtAppointmentEditDialog(context, item, onSaved: _load),
        ),
      ],
    );
  }

  Widget _buildPaginationBar() {
    final total = _searchedItems.length;
    final start = _perPage <= 0 ? 1 : ((_currentPage - 1) * _perPage) + 1;
    final end = _perPage <= 0
        ? total
        : ((_currentPage * _perPage)).clamp(0, total);
    return TablePaginationFooter(
      total: total,
      currentPage: _currentPage,
      lastPage: _lastPage,
      start: start,
      end: end,
      onPrev: () => setState(() => _currentPage--),
      onNext: () => setState(() => _currentPage++),
    );
  }
}

// ── Add / Edit form pane (Pattern C — matches PatientFormScreen's 2-column
// field grid, now embedded in a modal Dialog instead of a split-pane detail
// panel — see `_openAddDialog`/`_openEditDialog` above). Public (not
// `_AppointmentFormPane`) so the dashboard's "OT Appointment" quick-action
// button can reuse this exact same add form in its own dialog — mirrors
// web's `route('hospital.ot.appointments.create')` link, matching what the
// Walk-in/Phone buttons already do with `PatientFormScreen`. ───────────────

class OtAppointmentFormPane extends StatefulWidget {
  final OtAppointmentItem? item;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const OtAppointmentFormPane({
    super.key,
    required this.item,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<OtAppointmentFormPane> createState() => _OtAppointmentFormPaneState();
}

class _OtAppointmentFormPaneState extends State<OtAppointmentFormPane> {
  // Matches web's real 4 types exactly (_form.blade.php) — 'ot', not
  // 'referral', which never existed on web at all. See
  // OT_BUGS_ROUND4_AUDIT.md.
  static const _types = ['phone', 'walk_in', 'online', 'ot'];
  static const _typeLabels = {
    'phone': 'Phone',
    'walk_in': 'Walk-in',
    'online': 'Online',
    'ot': 'OT',
  };
  static const _genders = ['male', 'female', 'other'];

  late final TextEditingController _nameCtrl,
      _middleCtrl,
      _surnameCtrl,
      _mobileCtrl,
      _whatsappCtrl,
      _ageCtrl,
      _occupationCtrl;
  String _type = 'ot';
  String _gender = 'male';
  DateTime? _date;
  OtSlotItem? _selectedSlot;
  int? _doctorId;
  int? _referrerId;
  int? _locationId;

  OtAppointmentFormData? _formData;
  bool _loadingForm = true;
  String? _formError;
  bool _saving = false;
  String? _nameErr,
      _surnameErr,
      _mobileErr,
      _ageErr,
      _dateErr,
      _doctorErr,
      _locationErr;

  List<OtSlotAppointmentConflict> _slotConflicts = [];
  bool _loadingSlot = false;

  // Matched against loaded slots once form data arrives (§1 field-order:
  // Appointment Time is a select of OtSlot rows on web, not a free time
  // picker — see OT_WEB_PARITY_FIX_PRD.md §1).
  String? _pendingSlotTime;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _nameCtrl = TextEditingController(text: it?.patientName ?? '');
    _middleCtrl = TextEditingController(text: it?.middleName ?? '');
    _surnameCtrl = TextEditingController(text: it?.surname ?? '');
    _mobileCtrl = TextEditingController(text: it?.mobileNo ?? '');
    _whatsappCtrl = TextEditingController(text: it?.whatsappNo ?? '');
    _ageCtrl = TextEditingController(text: it != null ? '${it.age}' : '');
    _occupationCtrl = TextEditingController(text: it?.occupation ?? '');
    _type = it?.appointmentType ?? 'ot';
    _gender = it?.gender ?? 'male';
    _doctorId = it?.doctor?.id;
    _referrerId = it?.referrerId;
    _locationId = it?.location?.id;
    if (it != null && it.appointmentDate.isNotEmpty)
      _date = parseApiPlainDate(it.appointmentDate);
    // The API returns appointment_time with seconds ("14:30:00" — a MySQL
    // TIME column, no Eloquent cast), but slots compare on "HH:mm" only
    // (_slotTimeStr) — truncate here or the match below always silently
    // fails and the saved slot never shows as selected.
    final rawTime = it?.appointmentTime;
    _pendingSlotTime = (rawTime != null && rawTime.length >= 5)
        ? rawTime.substring(0, 5)
        : rawTime;
    _loadFormData();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _middleCtrl,
      _surnameCtrl,
      _mobileCtrl,
      _whatsappCtrl,
      _ageCtrl,
      _occupationCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final data = await OtAppointmentService.instance.fetchFormData();
      if (mounted) {
        setState(() {
          _formData = data;
          _loadingForm = false;
          if (_pendingSlotTime != null) {
            final match = data.slots
                .where((s) => _slotTimeStr(s) == _pendingSlotTime)
                .toList();
            if (match.isNotEmpty) _selectedSlot = match.first;
          }
        });
        if (_date != null && _selectedSlot != null) _refreshSlotConflicts();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _formError = e.toString().replaceFirst('Exception: ', '');
          _loadingForm = false;
        });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: widget.item == null
          ? now
          : now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateErr = null;
      });
      _refreshSlotConflicts();
    }
  }

  /// Raw `HH:mm` (matches web's `Carbon::parse($slot->start_time)->format('H:i')`
  /// stored value) derived from the slot's start time — `null`/short values
  /// return null so a slot with no configured start time is never selectable
  /// as a time filter.
  String? _slotTimeStr(OtSlotItem s) =>
      (s.startTime != null && s.startTime!.length >= 5)
      ? s.startTime!.substring(0, 5)
      : null;

  /// 12-hour display clock ("09:00 AM") matching web's `format('h:i A')`.
  String _fmtClock(String? raw) {
    if (raw == null || raw.length < 5) return '';
    final h = int.tryParse(raw.substring(0, 2)) ?? 0;
    final m = raw.substring(3, 5);
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }

  String _slotLabel(OtSlotItem s) => s.startTime != null && s.endTime != null
      ? '${s.slotName} (${_fmtClock(s.startTime)} - ${_fmtClock(s.endTime)})'
      : s.slotName;

  /// On Date + Time change, shows a chip list of patients already booked in
  /// that exact slot — mirrors web's AJAX slot-occupancy panel (hidden if
  /// none). See OT_WEB_PARITY_FIX_PRD.md §1.1.
  Future<void> _refreshSlotConflicts() async {
    final timeStr = _selectedSlot != null ? _slotTimeStr(_selectedSlot!) : null;
    if (_date == null || timeStr == null) {
      setState(() => _slotConflicts = []);
      return;
    }
    final dateStr = toIsoDate(_date!);
    setState(() => _loadingSlot = true);
    try {
      final conflicts = await OtAppointmentService.instance.slotAppointments(
        date: dateStr,
        time: timeStr,
        excludeId: widget.item?.id,
      );
      if (mounted)
        setState(() {
          _slotConflicts = conflicts;
          _loadingSlot = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _slotConflicts = [];
          _loadingSlot = false;
        });
    }
  }

  Future<void> _addCity() async {
    final loc = await showAddCityDialog(context);
    if (loc == null || !mounted) return;
    setState(() {
      _formData = OtAppointmentFormData(
        doctors: _formData!.doctors,
        locations: [
          ..._formData!.locations,
          OtAppointmentLocation(
            id: loc.id,
            name: loc.city,
            district: loc.district,
            state: loc.state,
          ),
        ],
        referrers: _formData!.referrers,
        slots: _formData!.slots,
        nextAppointmentNumber: _formData!.nextAppointmentNumber,
      );
      _locationId = loc.id;
      _locationErr = null;
    });
    showAppSnackBar(context, 'City "${loc.city}" added.', isSuccess: true);
  }

  Future<void> _save() async {
    final age = int.tryParse(_ageCtrl.text.trim());
    setState(() {
      _nameErr = _nameCtrl.text.trim().isEmpty ? 'Required' : null;
      _surnameErr = _surnameCtrl.text.trim().isEmpty ? 'Required' : null;
      _mobileErr = _mobileCtrl.text.trim().isEmpty ? 'Required' : null;
      _ageErr = age == null ? 'Invalid' : null;
      _dateErr = _date == null ? 'Required' : null;
      _doctorErr = _doctorId == null ? 'Select a doctor' : null;
      _locationErr = _locationId == null ? 'Select a location' : null;
    });
    if ([
      _nameErr,
      _surnameErr,
      _mobileErr,
      _ageErr,
      _dateErr,
      _doctorErr,
      _locationErr,
    ].any((e) => e != null))
      return;

    setState(() => _saving = true);
    try {
      final body = {
        'appointment_type': _type,
        'appointment_date': toIsoDate(_date!),
        if (_selectedSlot != null)
          'appointment_time': _slotTimeStr(_selectedSlot!),
        'doctor_id': _doctorId,
        'patient_name': _nameCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'mobile_no': _mobileCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim(),
        'age': age,
        'gender': _gender,
        'occupation': _occupationCtrl.text.trim(),
        if (_referrerId != null) 'referrer_id': _referrerId,
        'location_id': _locationId,
      };
      if (widget.item == null) {
        await OtAppointmentService.instance.create(body);
      } else {
        await OtAppointmentService.instance.update(widget.item!.id, body);
      }
      if (mounted) showAppSnackBar(context, 'Saved.', isSuccess: true);
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

  // ── Layout helpers (matches PatientFormScreen's Pattern C field grid) ────

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) return Column(children: [a, b]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _spaced(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 14), child: child);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.primary),
              onPressed: widget.onCancel,
              tooltip: 'Cancel',
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryA10,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.event_note_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Appointment' : 'New Appointment',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update appointment details'
                        : 'Pre-registration — patient hasn\'t arrived yet',
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
          child: _loadingForm
              ? const AppSkeletonList(count: 5, itemHeight: 60)
              : _formError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: AppColors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(_formError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _loadingForm = true);
                            _loadFormData();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(child: _buildForm()),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final formData = _formData!;
    final apptNumber =
        widget.item?.appointmentNumber ?? formData.nextAppointmentNumber;
    final selectedLoc = _locationId == null
        ? const <OtAppointmentLocation>[]
        : formData.locations.where((l) => l.id == _locationId).toList();
    final district = selectedLoc.isNotEmpty
        ? (selectedLoc.first.district ?? '—')
        : '—';
    final state = selectedLoc.isNotEmpty
        ? (selectedLoc.first.state ?? '—')
        : '—';

    // Field order below matches web's `_form.blade.php` exactly (client
    // requirement: same fields, same order, no more/no less) — Appointment
    // ID → Type → Date → Time → Contact/WhatsApp → First/Surname/Middle →
    // Doctor → City/District/State → Age/Gender → Occupation → Referred By.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _spaced(
          TextFormField(
            enabled: false,
            controller: TextEditingController(text: apptNumber),
            decoration: appFieldDecoration('Appointment ID'),
          ),
        ),
        _spaced(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APPOINTMENT TYPE *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _types
                    .map(
                      (t) => ChoiceChip(
                        label: Text(_typeLabels[t]!),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        _row2(
          _spaced(
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: appFieldDecoration(
                  'Date *',
                ).copyWith(errorText: _dateErr),
                child: Text(_date == null ? 'Select' : toIsoDate(_date!)),
              ),
            ),
          ),
          _spaced(
            DropdownButtonFormField<OtSlotItem>(
              initialValue: _selectedSlot,
              isExpanded: true,
              decoration: appFieldDecoration('Time', hint: 'Select slot...'),
              items: formData.slots
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        _slotLabel(s),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedSlot = v);
                _refreshSlotConflicts();
              },
            ),
          ),
        ),
        if (_loadingSlot || _slotConflicts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _loadingSlot
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Text(
                            'Already booked:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        ..._slotConflicts.map(
                          (c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orangeA12,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        _row2(
          _spaced(
            TextFormField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appFieldDecoration(
                'Mobile No *',
              ).copyWith(errorText: _mobileErr),
            ),
          ),
          _spaced(
            TextFormField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appFieldDecoration(
                'WhatsApp No',
                hint: 'Same if blank',
              ),
            ),
          ),
        ),
        _row2(
          _spaced(
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: appFieldDecoration(
                'First Name *',
              ).copyWith(errorText: _nameErr),
            ),
          ),
          _spaced(
            TextFormField(
              controller: _surnameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: appFieldDecoration(
                'Surname *',
              ).copyWith(errorText: _surnameErr),
            ),
          ),
        ),
        _spaced(
          TextFormField(
            controller: _middleCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: appFieldDecoration('Middle Name'),
          ),
        ),
        _spaced(
          DropdownButtonFormField<int>(
            initialValue: _doctorId,
            isExpanded: true,
            decoration: appFieldDecoration(
              'Doctor *',
              hint: 'Select doctor...',
            ).copyWith(errorText: _doctorErr),
            items: formData.doctors
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _doctorId = v;
              _doctorErr = null;
            }),
          ),
        ),
        _spaced(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addCity,
                  icon: Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    'Add City',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: _locationId,
                isExpanded: true,
                decoration: appFieldDecoration(
                  'City *',
                  hint: 'Select city...',
                ).copyWith(errorText: _locationErr),
                items: formData.locations
                    .map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _locationId = v;
                  _locationErr = null;
                }),
              ),
            ],
          ),
        ),
        // Web always renders District/State (empty/readonly until a city is
        // chosen) rather than hiding them — matched here.
        _row2(
          _spaced(
            TextFormField(
              enabled: false,
              controller: TextEditingController(text: district),
              decoration: appFieldDecoration('District'),
            ),
          ),
          _spaced(
            TextFormField(
              enabled: false,
              controller: TextEditingController(text: state),
              decoration: appFieldDecoration('State'),
            ),
          ),
        ),
        _row2(
          _spaced(
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appFieldDecoration(
                'Age *',
              ).copyWith(errorText: _ageErr),
            ),
          ),
          _spaced(
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: appFieldDecoration('Gender *'),
              items: _genders
                  .map(
                    (g) => DropdownMenuItem(
                      value: g,
                      child: Text(g[0].toUpperCase() + g.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
          ),
        ),
        _spaced(
          TextFormField(
            controller: _occupationCtrl,
            decoration: appFieldDecoration('Occupation'),
          ),
        ),
        _spaced(
          DropdownButtonFormField<int?>(
            initialValue: _referrerId,
            isExpanded: true,
            decoration: appFieldDecoration(
              'Referred By',
              hint: 'Select referrer...',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              ...formData.referrers.map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(r.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _referrerId = v),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppPrimaryButton(
                label: 'Save',
                loading: _saving,
                onPressed: _save,
              ),
            ),
            const SizedBox(width: 12),
            AppSecondaryButton(onPressed: widget.onCancel),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
