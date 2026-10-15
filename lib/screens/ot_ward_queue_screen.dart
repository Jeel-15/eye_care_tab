import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_ward_models.dart';
import '../services/ot_ward_service.dart';
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
import '../widgets/ot/ot_ward_detail_dialog.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_datetime_field.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/refreshable.dart';


/// Tablet Ward Entry Queue — web-parity table redesign (2026-09-19),
/// matching `resources/views/hospital/ot/accountant/ward.blade.php`'s
/// "Ward Entry Queue" panel exactly: a colored panel header, Show-entries +
/// search + a single full-page table (Patient Name / Phone / Status /
/// Payment / Actions — web has no OT Date column here) with "Showing X to
/// Y of Z entries" pagination — same shared `OtPanelHeader`/`ScaledDataTable`/
/// `TableToolsBar`/`TablePaginationFooter` widgets already used by
/// Patients, OT Appointments, OT Counsellor and OT Accountant, instead of
/// a fifth hand-duplicated copy of that scaffolding. No more list+detail
/// split — Actions always has a "View" button (web pull 2026-09-30: web
/// always renders this, on both Queue and History rows — an earlier version
/// of this comment incorrectly claimed only one button ever appears), plus
/// "Vitals & Eye Drops" on Queue rows only (`@unless($isHistory)`), which
/// opens `_WardDetailPane` (unchanged — vitals/eye-drops/status sections,
/// including the ready-to-send-to-OT-assistant flow) in a modal dialog
/// instead of a side detail-pane. The tablet's *old* list tile additionally
/// rendered its own inline "Send to OT Assistant" button, which the real web table
/// row never had (that action only exists inside the destination page's
/// Patient Status section) — removed as part of this redesign for exact
/// parity; `_WardDetailPane`'s own ready-banner send button still covers
/// that flow. Status badge now shows the raw `ot_status` value uppercased
/// (`PAYMENT_VERIFIED`, `IN_WARD`, `DILATED`) matching web's
/// `strtoupper($booking->ot_status)` exactly — the old humanized label
/// ("Payment Verified") didn't match the screenshot.
class OtWardQueueScreen extends StatefulWidget {
  const OtWardQueueScreen({super.key});

  @override
  State<OtWardQueueScreen> createState() => _OtWardQueueScreenState();
}

class _OtWardQueueScreenState extends State<OtWardQueueScreen>
    implements Refreshable {
  List<OtBookingSummary> _items = [];
  bool _loading = true;
  String? _error;

  // Web pull 2026-09-19: Queue/All toggle — 'queue' (Ward Entry Queue) or
  // 'history' (Ward History, date-ranged).
  String _filter = 'queue';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _perPage = 10;
  int _page = 1;

  // Web parity (`ward.blade.php`'s Dilate column) — a live mm:ss countdown
  // to each row's dilation-unlock time, ticking every second via a plain
  // rebuild (cheap — no refetch) rather than a per-row Timer.
  Timer? _dilateTicker;

  @override
  void initState() {
    super.initState();
    _load();
    _dilateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dilateTicker?.cancel();
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
      final result = await OtWardService.instance.fetchBookings(
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
  // the dashboard-home compact Ward Management desk panel (see
  // `showOtWardBookingDetail`) so both surfaces always show the same data
  // instead of drifting apart.
  void _showBookingView(OtBookingSummary item) =>
      showOtWardBookingDetail(context, item);

  Future<void> _open(OtBookingSummary item) async {
    await openOtWardEntryPane(
      context,
      bookingId: item.id,
      patientName: item.patient?.fullName ?? 'Patient',
      initialOtStatus: item.otStatus,
    );
    // A booking that just became READY leaves this queue on web (see
    // OtAccountantController::wardIndex's status filter) — refresh so the
    // list reflects that the moment the dialog closes.
    _load();
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
              (it.patient?.contactNo?.toLowerCase().contains(q) ?? false),
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
              icon: Icons.bed_rounded,
              title: _filter == 'history' ? 'Ward History' : 'Ward Entry Queue',
              subtitle: _filter == 'history'
                  ? 'Patients who completed ward and moved to OT / discharge.'
                  : 'Patients on the ward — paid, in ward, or dilated — before OT assignment.',
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

  static const _columns = [
    ScaledTableColumn('PATIENT NAME', 170, grow: true),
    ScaledTableColumn('PHONE', 120),
    ScaledTableColumn('STATUS', 150),
    ScaledTableColumn('DILATE', 110),
    ScaledTableColumn('PAYMENT', 110),
    ScaledTableColumn('ACTIONS', 340, hug: true),
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
              : 'No records available for ward workflow.',
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
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call_rounded, size: 12, color: AppColors.primaryA55),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              item.patient?.contactNo ?? '—',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: otStatusColor(item.otStatus),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
      _dilateCell(item),
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
      // Web parity: `ward.blade.php` always renders View, plus
      // "Vitals & Eye Drops" only `@unless($isHistory)` — previously this
      // app only ever showed one or the other, silently dropping View on
      // the Queue tab entirely.
      ActionCluster(
        children: [
          TableLabelAction(
            label: 'View',
            icon: Icons.visibility_outlined,
            onTap: () => _showBookingView(item),
          ),
          if (_filter != 'history')
            TableLabelAction(
              label: 'Vitals & Eye Drops',
              icon: Icons.monitor_heart_outlined,
              tone: TableLabelTone.primary,
              onTap: () => _open(item),
            ),
        ],
      ),
    ];
  }

  Widget _dilateCell(OtBookingSummary item) {
    final unlockAt = _dilateUnlockAt(item);
    if (unlockAt == null) {
      return const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
    }
    final ready = !unlockAt.isAfter(DateTime.now());
    final color = ready ? AppColors.green : AppColors.orange;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Text(_dilateCountdownLabel(unlockAt), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// Web parity (`ward.blade.php`'s Dilate column) — the latest logged dose
// with dilate='Yes' and a dilation_time set, resolved to the actual
// wall-clock moment it unlocks (administered_at + dilation_time minutes).
// Null when no such dose has been logged.
DateTime? _dilateUnlockAt(OtBookingSummary item) {
  OtEyeDropEntry? latest;
  DateTime? latestAt;
  for (final d in item.dilationEntries) {
    if (d.dilate != 'Yes' || d.dilationTime == null) continue;
    final at = DateTime.tryParse(d.administeredAt ?? '');
    if (at == null) continue;
    if (latestAt == null || at.isAfter(latestAt)) {
      latest = d;
      latestAt = at;
    }
  }
  if (latest == null || latestAt == null) return null;
  return latestAt.add(Duration(minutes: latest.dilationTime!));
}

String _dilateCountdownLabel(DateTime unlockAt) {
  final diff = unlockAt.difference(DateTime.now());
  if (diff.isNegative) return 'Ready';
  final m = diff.inMinutes;
  final s = diff.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ── Ward detail pane (embedded in the detail pane, not a full screen) ──────
// Vitals/Eye Drops/Status are stacked vertically (not the old 3-way side-by-
// side Row) so they read naturally in the narrower detail-pane width —
// same vertical-sections convention as the Counselling pane.

class _WardDetailPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final String? initialOtStatus;
  final VoidCallback onClose;

  const _WardDetailPane({
    super.key,
    required this.bookingId,
    required this.patientName,
    this.initialOtStatus,
    required this.onClose,
  });

  @override
  State<_WardDetailPane> createState() => _WardDetailPaneState();
}

class _WardDetailPaneState extends State<_WardDetailPane> {
  static final _genFmt = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
  ];

  OtVerificationHeader? _header;
  OtVitalsItem? _vitals;
  List<OtEyeDropEntry> _eyeDrops = [];
  bool _loading = true;
  String? _loadError;

  String? _currentOtStatus;
  bool _sendingReady = false;

  // ── Vitals form — always visible, pre-filled from the latest save ───────
  late final TextEditingController _bpCtrl,
      _pulseCtrl,
      _rbsCtrl,
      _tempCtrl,
      _spo2Ctrl,
      _hba1cCtrl;
  bool _savingVitals = false;

  // ── Status form ───────────────────────────────────────────────────────
  String _status = 'preparing';
  bool _savingStatus = false;
  String? _statusError;

  // ── Eye-drop form (add new dose) ─────────────────────────────────────
  final _doseCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _dilationTimeCtrl = TextEditingController();
  String? _medicineName;
  String _eye = 'RE';
  DateTime _administeredAt = toHospitalTime(DateTime.now());
  // Web pull 2026-10-10 — "Dilate?" Yes/No; dilation time (minutes) is
  // required only when Yes.
  bool _dilate = false;
  bool _savingDrop = false;
  String? _medicineError, _doseError, _dilationTimeError;

  bool get _canWriteVitals => PermissionService.instance.can(Perm.otPreopEntry);
  bool get _canWriteDrops =>
      PermissionService.instance.can(Perm.otDilationTrack);
  // Web gates the whole ward page — including "send to OT Assistant" — by
  // ot_ward_entry alone; the API's mark-ready route enforces the same key.
  // ot_surgery_ready is a different feature (OT Assistant's own "ready to
  // operate" action) and must not gate this button.
  bool get _canSurgeryReady => PermissionService.instance.can(Perm.otWardEntry);

  @override
  void initState() {
    super.initState();
    _currentOtStatus = widget.initialOtStatus;
    _bpCtrl = TextEditingController();
    _pulseCtrl = TextEditingController();
    _rbsCtrl = TextEditingController();
    _tempCtrl = TextEditingController();
    _spo2Ctrl = TextEditingController();
    _hba1cCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _bpCtrl,
      _pulseCtrl,
      _rbsCtrl,
      _tempCtrl,
      _spo2Ctrl,
      _hba1cCtrl,
      _doseCtrl,
      _remarksCtrl,
      _dilationTimeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // Web embeds assistants on the ward page under ot_ward_entry.
      // Do NOT call /config/users here — that requires user_*_view and
      // blocks ward-only staff (Access denied on open).
      final results = await Future.wait([
        OtWardService.instance.fetchVerificationHeader(widget.bookingId),
        OtWardService.instance.fetchVitals(widget.bookingId),
        OtWardService.instance.fetchEyeDrops(widget.bookingId),
      ]);
      if (mounted) {
        final header = results[0] as OtVerificationHeader;
        final vitals = results[1] as OtVitalsItem?;
        final eyeDrops = results[2] as List<OtEyeDropEntry>;
        setState(() {
          _header = header;
          _vitals = vitals;
          _eyeDrops = eyeDrops;
          _loading = false;
          // Re-seed the always-visible form fields from the latest server
          // state — this is what "direct fill" means here: the same field
          // the user types into already holds the saved value.
          _bpCtrl.text = vitals?.bp ?? '';
          _pulseCtrl.text = vitals?.pulse ?? '';
          _rbsCtrl.text = vitals?.rbs?.toString() ?? '';
          _tempCtrl.text = vitals?.temperature?.toString() ?? '';
          _spo2Ctrl.text = vitals?.spo2?.toString() ?? '';
          _hba1cCtrl.text = vitals?.hba1c?.toString() ?? '';
          _status = vitals?.preOpStatus ?? 'preparing';
          final eyeOptions = switch (header.eye) {
            'RE' => const ['RE'],
            'LE' => const ['LE'],
            _ => const ['RE', 'LE'],
          };
          if (!eyeOptions.contains(_eye)) _eye = eyeOptions.first;
          _doseCtrl.text =
              '${(_eyeDrops.isEmpty ? 0 : _eyeDrops.map((e) => e.doseNumber).reduce((a, b) => a > b ? a : b)) + 1}';
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loadError = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _saveVitals() async {
    setState(() => _savingVitals = true);
    try {
      // Card 1 is clinical vitals only — the current pre_op_status is
      // carried forward unchanged from the Status section's own state.
      final status = await OtWardService.instance.storeVitals(
        widget.bookingId,
        {
          'bp': _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim(),
          // API/web: pulse is string (nullable|string|max:20) — not int.
          'pulse': _pulseCtrl.text.trim().isEmpty
              ? null
              : _pulseCtrl.text.trim(),
          'rbs': double.tryParse(_rbsCtrl.text.trim()),
          'temperature': double.tryParse(_tempCtrl.text.trim()),
          'spo2': double.tryParse(_spo2Ctrl.text.trim()),
          'hba1c': double.tryParse(_hba1cCtrl.text.trim()),
          'pre_op_status': _vitals?.preOpStatus ?? 'preparing',
        },
      );
      if (!mounted) return;
      setState(() {
        _currentOtStatus = status;
        _savingVitals = false;
      });
      showAppSnackBar(context, 'Vitals saved.', isSuccess: true);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _savingVitals = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  bool get _statusIsReady => _status == 'ready_for_surgery';

  Future<void> _saveStatus() async {
    setState(() {
      // Web pull 2026-10-12 — the OT Assistant picker is gone; Ready for OT
      // now auto-resolves the assistant from the linked doctor's "Connected
      // OT Assistant" profile field, so this is caught client-side before
      // the save round-trip instead of after a 422.
      _statusError = _statusIsReady && _header?.defaultOtAssistant == null
          ? "This doctor has no active OT Assistant connected. Connect one on the doctor's profile (Users → Edit Doctor) before marking Ready for OT."
          : null;
    });
    if (_statusError != null) return;

    setState(() => _savingStatus = true);
    try {
      final status = await OtWardService.instance
          .storeVitals(widget.bookingId, {
            'pre_op_status': _status,
            'assign_staff': true,
          });
      if (!mounted) return;
      setState(() {
        _currentOtStatus = status;
        _savingStatus = false;
      });
      showAppSnackBar(context, 'Status saved.', isSuccess: true);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _savingStatus = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _logEyeDrop() async {
    final dose = int.tryParse(_doseCtrl.text.trim());
    final dilationTime = int.tryParse(_dilationTimeCtrl.text.trim());
    setState(() {
      _medicineError = _medicineName == null ? 'Required' : null;
      _doseError = (dose == null || dose < 1 || dose > 20)
          ? 'Must be 1-20'
          : null;
      _dilationTimeError = _dilate && (dilationTime == null || dilationTime < 1 || dilationTime > 180)
          ? 'Enter the dilation time (minutes)'
          : null;
    });
    if (_medicineError != null || _doseError != null || _dilationTimeError != null) return;

    setState(() => _savingDrop = true);
    try {
      await OtWardService.instance.addEyeDrop(
        widget.bookingId,
        medicineName: _medicineName!,
        eye: _eye,
        doseNumber: dose!,
        administeredAt: toApiDateTimeLocal(_administeredAt),
        remarks: _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
        dilate: _dilate ? 'Yes' : 'No',
        dilationTime: _dilate ? dilationTime : null,
      );
      if (!mounted) return;
      setState(() {
        _savingDrop = false;
        _remarksCtrl.clear();
        _medicineName = null;
        _administeredAt = toHospitalTime(DateTime.now());
        _dilate = false;
        _dilationTimeCtrl.clear();
      });
      showAppSnackBar(context, 'Dose logged.', isSuccess: true);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _savingDrop = false);
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _sendToOtAssistant() async {
    setState(() => _sendingReady = true);
    try {
      final status = await OtWardService.instance.markReady(widget.bookingId);
      if (mounted) {
        setState(() {
          _currentOtStatus = status;
          _sendingReady = false;
        });
        showAppSnackBar(
          context,
          'Patient is ready and handed off to OT Assistant',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReady = false);
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
                color: AppColors.primaryA10,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.bed_rounded,
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
                    'Ward Entry',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _header != null
                        ? '${_header!.patientName} · UHID ${_header!.uhid}${_header!.surgeryType != null ? ' · ${_header!.surgeryType}' : ''}'
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
              ? const AppSkeletonList(count: 5, itemHeight: 70)
              : _loadError != null
              ? AppErrorState(message: _loadError!, onRetry: _load)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReadyBanner(),
                      _buildVitalsPanel(),
                      const SizedBox(height: 16),
                      _buildEyeDropsPanel(),
                      const SizedBox(height: 16),
                      _buildStatusPanel(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReadyBanner() {
    final status = _currentOtStatus;
    if (status == null) return const SizedBox.shrink();
    final eligibleStatuses = {'payment_verified', 'in_ward'};
    final preOpReady = _vitals?.preOpStatus == 'ready_for_surgery';
    final showButton = eligibleStatuses.contains(status) && preOpReady;
    Color bg;
    Color fg;
    String label;
    if (status == 'ready') {
      bg = AppColors.green.withValues(alpha: 0.12);
      fg = AppColors.green;
      label = 'READY — sent to OT Assistant';
    } else if (eligibleStatuses.contains(status)) {
      bg = const Color(0xFFF1F5F9);
      fg = AppColors.textSecondary;
      label = preOpReady
          ? 'Ready to send to OT Assistant?'
          : 'Save Ready + OT Assistant first';
    } else {
      bg = AppColors.orangeA12;
      fg = AppColors.orange;
      label = 'Current status: ${status.toUpperCase()}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            status == 'ready' ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          if (showButton && _canSurgeryReady)
            ElevatedButton.icon(
              onPressed: _sendingReady ? null : _sendToOtAssistant,
              icon: _sendingReady
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 15),
              label: const Text(
                'READY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Patient Status',
            icon: Icons.assignment_turned_in_outlined,
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: !_canWriteVitals,
            child: Opacity(
              opacity: _canWriteVitals ? 1 : 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kOtPreOpStatuses
                        .map(
                          (s) => ChoiceChip(
                            label: Text(otPreOpStatusLabel(s)),
                            selected: _status == s,
                            onSelected: (_) => setState(() {
                              _status = s;
                              _statusError = null;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  // Web pull 2026-10-12 — web's Patient Status card is just
                  // the status radios + Save button, nothing else ("No
                  // doctor / OT Assistant fields here — both are assigned
                  // automatically on save," per the blade's own comment). A
                  // prior pass here added a read-only "Doctor/OT Assistant
                  // (auto-assigned)" field, which still looked like a
                  // pickable form field even though it wasn't one — removed
                  // per client feedback 2026-10-14 to match web's actual
                  // minimal UI exactly. The auto-assign logic itself is
                  // unchanged (still fully server-side); _statusError below
                  // still catches the one case worth warning about before a
                  // round-trip.
                ],
              ),
            ),
          ),
          if (_statusError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusError!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ),
          if (_canWriteVitals) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: 'Save Status',
                loading: _savingStatus,
                onPressed: _saveStatus,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Vitals',
            icon: Icons.monitor_heart_outlined,
          ),
          if (_vitals?.enteredBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(
                'Last entered by ${_vitals!.enteredBy!.name}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
          IgnorePointer(
            ignoring: !_canWriteVitals,
            child: Opacity(
              opacity: _canWriteVitals ? 1 : 0.6,
              child: Column(
                children: [
                  AppFormRow(
                    children: [
                      TextFormField(
                        controller: _bpCtrl,
                        decoration: appFieldDecoration(
                          'BP',
                          hint: 'e.g. 120/80',
                        ),
                      ),
                      TextFormField(
                        controller: _pulseCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: appFieldDecoration('Pulse', hint: 'bpm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppFormRow(
                    children: [
                      TextFormField(
                        controller: _rbsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _genFmt,
                        decoration: appFieldDecoration('RBS', hint: 'mg/dL'),
                      ),
                      TextFormField(
                        controller: _tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _genFmt,
                        decoration: appFieldDecoration(
                          'Temperature',
                          hint: '°F',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppFormRow(
                    children: [
                      TextFormField(
                        controller: _spo2Ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _genFmt,
                        decoration: appFieldDecoration('SpO2', hint: '%'),
                      ),
                      TextFormField(
                        controller: _hba1cCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: _genFmt,
                        decoration: appFieldDecoration('HbA1c', hint: '%'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_canWriteVitals) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: 'Save Vitals',
                loading: _savingVitals,
                onPressed: _saveVitals,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEyeDropsPanel() {
    final eyeOptions = switch (_header?.eye) {
      'RE' => const ['RE'],
      'LE' => const ['LE'],
      _ => const ['RE', 'LE'],
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryA08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Eye Drop Register',
            icon: Icons.water_drop_outlined,
          ),
          const SizedBox(height: 10),
          if (_eyeDrops.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No doses logged yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else ...[
            // API returns doses oldest-first (administered_at asc, matching
            // web); reversed here so the most recent dose — the one a nurse
            // actually needs to see — is the first thing on screen, not the
            // one scrolled furthest away.
            ..._eyeDrops.reversed.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealA12,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '#${d.doseNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.medicineName} · ${d.eye}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (d.dilate == 'Yes')
                              Text(
                                'Dilated${d.dilationTime != null ? ' · ${d.dilationTime} mins' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tealDark,
                                ),
                              ),
                            if (d.remarks != null && d.remarks!.isNotEmpty)
                              Text(
                                d.remarks!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (d.administeredAt != null)
                        Text(
                          formatDateTimeString(d.administeredAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(height: 1, color: AppColors.primaryA08),
            const SizedBox(height: 14),
          ],
          if (_canWriteDrops) ...[
            Text(
              'LOG NEW DOSE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _medicineName,
              isExpanded: true,
              decoration: appFieldDecoration(
                'Medicine Name *',
              ).copyWith(errorText: _medicineError),
              items: (_header?.otMedicines ?? const [])
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.name,
                      child: Text(m.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _medicineName = v;
                _medicineError = null;
              }),
            ),
            if ((_header?.otMedicines ?? const []).isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'No ward medicines — add from Ward Medicine',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            AppFormRow(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eye',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      children: eyeOptions
                          .map(
                            (e) => ChoiceChip(
                              label: Text(e),
                              selected: _eye == e,
                              onSelected: (_) => setState(() => _eye = e),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _doseCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: appFieldDecoration(
                    'Dose #',
                  ).copyWith(errorText: _doseError),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OtDateTimeField(
              label: 'Administered At',
              value: _administeredAt,
              onChanged: (v) => setState(() => _administeredAt = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksCtrl,
              decoration: appFieldDecoration('Remarks'),
            ),
            const SizedBox(height: 14),
            // Web pull 2026-10-10 — "Dilate?" Yes/No; dilation time
            // (minutes) only required/shown when Yes.
            AppFormRow(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dilate',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Yes'),
                          selected: _dilate,
                          onSelected: (_) => setState(() {
                            _dilate = true;
                            _dilationTimeError = null;
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('No'),
                          selected: !_dilate,
                          onSelected: (_) => setState(() {
                            _dilate = false;
                            _dilationTimeCtrl.clear();
                            _dilationTimeError = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_dilate)
                  TextFormField(
                    controller: _dilationTimeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: appFieldDecoration('Dilation Time', hint: 'mins').copyWith(errorText: _dilationTimeError),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: 'Log Dose',
                loading: _savingDrop,
                onPressed: _logEyeDrop,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens the same Ward Entry (vitals / eye-drops / status) pane the Ward
/// Entry Queue table's "Vitals & Eye Drops" action uses — shared with the
/// dashboard home's compact Ward Management desk panel so both call the
/// exact same code path instead of a second copy of `_WardDetailPane`.
Future<void> openOtWardEntryPane(
  BuildContext context, {
  required int bookingId,
  required String patientName,
  String? initialOtStatus,
}) {
  return showPaneDialog<void>(
    context,
    wide: true,
    barrierDismissible: false,
    builder: (dCtx) => _WardDetailPane(
      key: ValueKey('ward-$bookingId'),
      bookingId: bookingId,
      patientName: patientName,
      initialOtStatus: initialOtStatus,
      onClose: () => Navigator.pop(dCtx),
    ),
  );
}
