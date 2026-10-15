import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../utils/date_format.dart';
import '../models/ot_assistant_models.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_counsellor_models.dart';
import '../models/ot_inventory_models.dart';
import '../services/ot_counsellor_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/ot/eye_choice_selector.dart';
import '../widgets/table_row_action.dart';
import '../widgets/form_kit.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';
import '../widgets/ot/signature_pad_field.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/currency_format.dart';
import '../utils/ot_status_style.dart';
import '../utils/view_facts.dart';
import '../widgets/ot/ot_booking_view_dialog.dart';
import '../utils/refreshable.dart';

// `payment_status` — unpriced | pending | partially_paid | paid — is the
// field web's own Payment Status column actually reads (not `ot_status`,
// which the pre-table version of this screen used, always rendering a flat
// "Paid"/"Complete" split regardless of the real payment state).
Color _paymentStatusColor(String? status) => switch (status) {
      'paid' => AppColors.green,
      'partially_paid' => AppColors.orange,
      'pending' => AppColors.orange,
      _ => AppColors.textDisabled,
    };

String _paymentStatusLabel(String? status) {
  if (status == null || status.isEmpty) return '—';
  return status.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

/// Tablet OT Counsellor Dashboard — web-parity table redesign (2026-09-18),
/// matching `resources/views/hospital/ot/counsellor/dashboard.blade.php`'s
/// two real DataTables panels exactly: "Awaiting Counselling" (Patient /
/// Phone / OT Doctor / OT Date / Eye / Surgery Type / Status / Action, each
/// row's Action opening the Counsel form) and read-only "Payment Status"
/// (Patient / Phone / OT Date / Package Amount / Status, no Action column)
/// — each with its own Show-entries + search + "Showing X to Y of Z
/// entries" pagination, same as the just-completed Patients and OT
/// Appointments redesigns. No more list+detail split — the Counsel form now
/// opens as a modal dialog (established `_openWalkInFromOt`/Patients/OT
/// Appointments pattern) instead of a side detail-pane. All business logic
/// (load/counselling save/consent save/send-to-billing) is unchanged —
/// only the presentation moved from split-pane list tiles to table rows.
///
String? _examWhen(DateTime? doneAt, String? doctorName) {
  if (doneAt == null) return null;
  final atText = toDisplayDateTime(doneAt);
  final by = doctorDisplayName(doctorName);
  return by == null ? atText : '$atText · $by';
}

Future<void> showOtCounsellorBookingView(BuildContext context, OtBookingSummary item) {
  final p = item.patient;
  final statusColor = otStatusColor(item.otStatus);
  return showRecordView(
    context,
    name: p?.fullName ?? 'Patient',
    pills: [
      ...patientIdentityPills(p),
      Pill(OtStatus.label(item.otStatus), bg: statusColor.withValues(alpha: 0.10), fg: statusColor, outlined: true),
      ExamChip(label: 'Primary', done: p?.primaryDoneAt != null, when: _examWhen(p?.primaryDoneAt, p?.primaryExamination?.doctorName)),
      ExamChip(label: 'Secondary', done: p?.secondaryDoneAt != null, when: _examWhen(p?.secondaryDoneAt, p?.secondaryExamination?.doctorName)),
    ],
    facts: [
      HeaderFact('Eye', item.eye),
      HeaderFact('Surgery', item.otType),
      HeaderFact('Doctor', doctorDisplayName(p?.doctor?.name)),
      HeaderFact('Visit', formatDateString(p?.appointmentDate, fallback: '')),
    ],
    sections: [
      FactSection('Registration', patientRecordFacts(p, consultingDoctor: false, occupation: true, caseType: true, fee: true, referrer: true, registeredAt: true, markReturning: true)),
    ],
  );
}

Future<void> openOtCounsellingForm(BuildContext context, OtBookingSummary item, {VoidCallback? onBillingSent}) {
  return showPaneDialog<void>(
    context,
    wide: true,
    barrierDismissible: false,
    builder: (dCtx) => _CounsellingFormPane(
      key: ValueKey('counselling-${item.id}'),
      bookingId: item.id,
      patientName: item.patient?.fullName ?? 'Patient',
      onCancel: () => Navigator.pop(dCtx),
      onBillingSent: () {
        Navigator.pop(dCtx);
        onBillingSent?.call();
      },
    ),
  );
}

class OtCounsellorDashboardScreen extends StatefulWidget {
  const OtCounsellorDashboardScreen({super.key});

  @override
  State<OtCounsellorDashboardScreen> createState() => _OtCounsellorDashboardScreenState();
}

class _OtCounsellorDashboardScreenState extends State<OtCounsellorDashboardScreen> implements Refreshable {
  List<OtBookingSummary> _pendingBookings = [];
  List<OtBookingSummary> _completeBookings = [];
  List<OtBookingSummary> _paymentStatus = [];
  bool _loading = true;
  String? _error;

  // Web pull 2026-10-05: the Queue/All toggle was removed — three tables
  // now show simultaneously (Booking Patient / Complete Patient / Payment
  // Status), each with its own independent date range (defaults to today,
  // widenable). Matches `OtCounsellorController::dashboard()`'s
  // `booking_from_date`/`booking_to_date`, `from_date`/`to_date`,
  // `pay_from_date`/`pay_to_date` exactly.
  DateTime _bookingFromDate = DateTime.now();
  DateTime _bookingToDate = DateTime.now();
  DateTime _completeFromDate = DateTime.now();
  DateTime _completeToDate = DateTime.now();
  DateTime _payFromDate = DateTime.now();
  DateTime _payToDate = DateTime.now();

  final TextEditingController _bookingSearchCtrl = TextEditingController();
  String _bookingSearch = '';
  int _bookingPerPage = 10;
  int _bookingPage = 1;

  final TextEditingController _completeSearchCtrl = TextEditingController();
  String _completeSearch = '';
  int _completePerPage = 10;
  int _completePage = 1;

  final TextEditingController _paymentSearchCtrl = TextEditingController();
  String _paymentSearch = '';
  int _paymentPerPage = 10;
  int _paymentPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bookingSearchCtrl.dispose();
    _completeSearchCtrl.dispose();
    _paymentSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _bookingPage = 1; _completePage = 1; _paymentPage = 1; });
    try {
      final results = await Future.wait([
        OtCounsellorService.instance.fetchBookings(
          filter: 'queue',
          fromDate: toIsoDate(_bookingFromDate),
          toDate: toIsoDate(_bookingToDate),
        ),
        OtCounsellorService.instance.fetchBookings(
          filter: 'history',
          fromDate: toIsoDate(_completeFromDate),
          toDate: toIsoDate(_completeToDate),
        ),
        OtCounsellorService.instance.fetchBookings(
          filter: 'payments',
          fromDate: toIsoDate(_payFromDate),
          toDate: toIsoDate(_payToDate),
        ),
      ]);
      if (mounted) {
        setState(() {
          _pendingBookings = results[0].items;
          _completeBookings = results[1].items;
          _paymentStatus = results[2].filter == 'payments' ? results[2].items : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _setBookingDateRange(DateTimeRange r) {
    setState(() { _bookingFromDate = r.start; _bookingToDate = r.end; });
    _load();
  }

  void _setCompleteDateRange(DateTimeRange r) {
    setState(() { _completeFromDate = r.start; _completeToDate = r.end; });
    _load();
  }

  void _setPayDateRange(DateTimeRange r) {
    setState(() { _payFromDate = r.start; _payToDate = r.end; });
    _load();
  }

  Future<void> _showBookingView(OtBookingSummary item) => showOtCounsellorBookingView(context, item);

  Future<void> _openCounselling(OtBookingSummary item) => openOtCounsellingForm(context, item, onBillingSent: _load);

  // ── Client-side search + pagination, independently per table (mirrors
  // web's two separate real DataTables instances) ──────────────────────────

  List<OtBookingSummary> _searchOf(List<OtBookingSummary> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((it) =>
        (it.patient?.fullName.toLowerCase().contains(q) ?? false) ||
        (it.patient?.contactNo?.toLowerCase().contains(q) ?? false) ||
        (it.otDoctor?.name.toLowerCase().contains(q) ?? false) ||
        (it.otType?.toLowerCase().contains(q) ?? false)).toList();
  }

  int _lastPageOf(int total, int perPage) => (perPage <= 0 || total == 0) ? 1 : (total / perPage).ceil().clamp(1, 999999);

  List<OtBookingSummary> _pageOf(List<OtBookingSummary> all, int perPage, int page) {
    if (perPage <= 0) return all;
    final start = (page - 1) * perPage;
    if (start >= all.length) return const [];
    return all.sublist(start, (start + perPage).clamp(0, all.length));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 80);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    return AppRefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildBookingPanel(),
          const SizedBox(height: 20),
          _buildCompletePanel(),
          const SizedBox(height: 20),
          _buildPaymentPanel(),
        ]),
      ),
    );
  }

  Widget _panelCard({required Widget header, required Widget body}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [header, body]),
    );
  }

  // ── Booking Patient (pending) ────────────────────────────────────────────

  // Web parity (web pull 2026-10-05, `counsellor/dashboard.blade.php`'s
  // `#otBookingPatientTable`): Patient / Phone / Eye / Surgery Type /
  // Status / Action — Action now always shows both View and Counsel
  // together (web stopped gating them behind a Queue/All toggle).
  static const _bookingColumns = [
    ScaledTableColumn('PATIENT', 170, grow: true),
    ScaledTableColumn('PHONE', 120),
    ScaledTableColumn('EYE', 60),
    ScaledTableColumn('SURGERY TYPE', 170, grow: true),
    ScaledTableColumn('STATUS', 160),
    ScaledTableColumn('ACTION', 190, hug: true),
  ];

  Widget _buildBookingPanel() {
    final all = _searchOf(_pendingBookings, _bookingSearch);
    final lastPage = _lastPageOf(all.length, _bookingPerPage);
    final rows = _pageOf(all, _bookingPerPage, _bookingPage);
    final start = _bookingPerPage <= 0 ? 1 : ((_bookingPage - 1) * _bookingPerPage) + 1;
    final end = _bookingPerPage <= 0 ? all.length : (_bookingPage * _bookingPerPage).clamp(0, all.length);

    return _panelCard(
      header: OtPanelHeader(
        icon: Icons.hourglass_top_rounded,
        title: 'Booking Patient',
        actions: [
          OtDateRangeChip(from: _bookingFromDate, to: _bookingToDate, onChanged: _setBookingDateRange),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableToolsBar(
          perPage: _bookingPerPage,
          onPerPageChanged: (v) => setState(() { _bookingPerPage = v; _bookingPage = 1; }),
          searchCtrl: _bookingSearchCtrl,
          onSearchChanged: (v) => setState(() { _bookingSearch = v; _bookingPage = 1; }),
        ),
        ScaledDataTable(
          columns: _bookingColumns,
          rows: rows.map(_bookingRowCells).toList(),
          emptyMessage: _bookingSearch.isNotEmpty ? 'No results match your search.' : 'No bookings awaiting counselling in this date range.',
        ),
        TablePaginationFooter(
          total: all.length,
          currentPage: _bookingPage,
          lastPage: lastPage,
          onPrev: () => setState(() => _bookingPage--),
          onNext: () => setState(() => _bookingPage++),
          start: start,
          end: end,
        ),
      ]),
    );
  }

  List<Widget> _bookingRowCells(OtBookingSummary item) {
    return [
      Text(item.patient?.fullName ?? 'Patient', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: item.eye != null ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(item.eye!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))) : const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      Text(item.otType ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: otStatusColor(item.otStatus).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(OtStatus.label(item.otStatus).toUpperCase(), maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: otStatusColor(item.otStatus), letterSpacing: 0.3))))),
      Align(
        alignment: Alignment.centerLeft,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TableLabelAction(label: 'View', icon: Icons.visibility_outlined, onTap: () => _showBookingView(item)),
          const SizedBox(width: 10),
          TableLabelAction(label: 'Counsel', icon: Icons.forum_rounded, tone: TableLabelTone.primary, onTap: () => _openCounselling(item)),
        ]),
      ),
    ];
  }

  // ── Complete Patient ─────────────────────────────────────────────────────

  // Web parity (`#otCounsellingTable` on the new layout): same columns as
  // Booking Patient but read-only (View only) — counselling/consent/billing
  // for these bookings is already done.
  static const _completeColumns = [
    ScaledTableColumn('PATIENT', 170, grow: true),
    ScaledTableColumn('PHONE', 120),
    ScaledTableColumn('EYE', 60),
    ScaledTableColumn('SURGERY TYPE', 170, grow: true),
    ScaledTableColumn('STATUS', 160),
    ScaledTableColumn('ACTION', 140, hug: true),
  ];

  Widget _buildCompletePanel() {
    final all = _searchOf(_completeBookings, _completeSearch);
    final lastPage = _lastPageOf(all.length, _completePerPage);
    final rows = _pageOf(all, _completePerPage, _completePage);
    final start = _completePerPage <= 0 ? 1 : ((_completePage - 1) * _completePerPage) + 1;
    final end = _completePerPage <= 0 ? all.length : (_completePage * _completePerPage).clamp(0, all.length);

    return _panelCard(
      header: OtPanelHeader(
        icon: Icons.task_alt_rounded,
        title: 'Complete Patient',
        actions: [
          OtDateRangeChip(from: _completeFromDate, to: _completeToDate, onChanged: _setCompleteDateRange),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableToolsBar(
          perPage: _completePerPage,
          onPerPageChanged: (v) => setState(() { _completePerPage = v; _completePage = 1; }),
          searchCtrl: _completeSearchCtrl,
          onSearchChanged: (v) => setState(() { _completeSearch = v; _completePage = 1; }),
        ),
        ScaledDataTable(
          columns: _completeColumns,
          rows: rows.map(_completeRowCells).toList(),
          emptyMessage: _completeSearch.isNotEmpty ? 'No results match your search.' : 'No bookings in this date range.',
        ),
        TablePaginationFooter(
          total: all.length,
          currentPage: _completePage,
          lastPage: lastPage,
          onPrev: () => setState(() => _completePage--),
          onNext: () => setState(() => _completePage++),
          start: start,
          end: end,
        ),
      ]),
    );
  }

  List<Widget> _completeRowCells(OtBookingSummary item) {
    return [
      Text(item.patient?.fullName ?? 'Patient', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: item.eye != null ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(item.eye!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))) : const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      Text(item.otType ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: otStatusColor(item.otStatus).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(OtStatus.label(item.otStatus).toUpperCase(), maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: otStatusColor(item.otStatus), letterSpacing: 0.3))))),
      Align(
        alignment: Alignment.centerLeft,
        child: TableLabelAction(label: 'View', icon: Icons.visibility_outlined, onTap: () => _showBookingView(item)),
      ),
    ];
  }

  // ── Payment Status (read-only) ───────────────────────────────────────────

  // Web parity: `#otPaymentStatusTable` — Patient / Phone / Package Amount /
  // Status only, no Date column.
  static const _psColumns = [
    ScaledTableColumn('PATIENT', 180, grow: true),
    ScaledTableColumn('PHONE', 130),
    ScaledTableColumn('PACKAGE AMOUNT', 150),
    ScaledTableColumn('STATUS', 140),
  ];

  Widget _buildPaymentPanel() {
    final all = _searchOf(_paymentStatus, _paymentSearch);
    final lastPage = _lastPageOf(all.length, _paymentPerPage);
    final rows = _pageOf(all, _paymentPerPage, _paymentPage);
    final start = _paymentPerPage <= 0 ? 1 : ((_paymentPage - 1) * _paymentPerPage) + 1;
    final end = _paymentPerPage <= 0 ? all.length : (_paymentPage * _paymentPerPage).clamp(0, all.length);

    return _panelCard(
      header: OtPanelHeader(
        icon: Icons.shield_outlined,
        title: 'Payment Status',
        subtitle: 'Bookings billing has taken payment on',
        actions: [
          OtDateRangeChip(from: _payFromDate, to: _payToDate, onChanged: _setPayDateRange),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TableToolsBar(
          perPage: _paymentPerPage,
          onPerPageChanged: (v) => setState(() { _paymentPerPage = v; _paymentPage = 1; }),
          searchCtrl: _paymentSearchCtrl,
          onSearchChanged: (v) => setState(() { _paymentSearch = v; _paymentPage = 1; }),
        ),
        ScaledDataTable(
          columns: _psColumns,
          rows: rows.map(_paymentRowCells).toList(),
          emptyMessage: _paymentSearch.isNotEmpty ? 'No results match your search.' : 'No bookings yet.',
        ),
        TablePaginationFooter(
          total: all.length,
          currentPage: _paymentPage,
          lastPage: lastPage,
          onPrev: () => setState(() => _paymentPage--),
          onNext: () => setState(() => _paymentPage++),
          start: start,
          end: end,
        ),
      ]),
    );
  }

  List<Widget> _paymentRowCells(OtBookingSummary item) {
    return [
      Text(item.patient?.fullName ?? 'Patient', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(item.packageAmount != null ? '${currentCurrencySymbol()}${item.packageAmount!.toStringAsFixed(2)}' : '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _paymentStatusColor(item.paymentStatus).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(_paymentStatusLabel(item.paymentStatus).toUpperCase(), maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _paymentStatusColor(item.paymentStatus), letterSpacing: 0.3))))),
    ];
  }
}

// ── Counselling form pane (embedded in a modal Dialog — see
// `_openCounselling` above — not a full screen or side detail-pane) —
// matches _AppointmentFormPane's header/body vocabulary exactly. ───────────

class _CounsellingFormPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onCancel;
  final VoidCallback onBillingSent;

  const _CounsellingFormPane({super.key, required this.bookingId, required this.patientName, required this.onCancel, required this.onBillingSent});

  @override
  State<_CounsellingFormPane> createState() => _CounsellingFormPaneState();
}

/// Web parity (`ot/counsellor/form.blade.php`): ONE pane holding THREE
/// independent forms/actions, always simultaneously visible with no
/// step-gating — Counselling (`storeCounselling`), Informed Consent
/// (`storeConsent`), and Send to Billing. Previously split into
/// `_CounsellingFormPane` → `_ConsentFormPane` pane-mode transition; web has
/// never had that step-by-step structure, so this was merged back into one
/// pane.
class _CounsellingFormPaneState extends State<_CounsellingFormPane> {
  static final _genFmt = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];

  bool _loading = true;
  String? _loadError;
  OtCounsellingDetail? _detail;
  bool _savingCounselling = false;

  bool get _canConsent => PermissionService.instance.can(Perm.otConsentCapture);

  // Usually just `detail.otSurgeryTypes` (the active list) — but if this
  // booking's already-saved `ot_type` was since deactivated/renamed, it
  // won't be in that list, and the dropdown would show blank despite the
  // value being genuinely saved (Bug #3, OT_BUGS_ROUND4_AUDIT.md). Mirrors
  // the backend's own tolerance for this exact situation
  // (storeCounselling()'s "already-set-but-since-deactivated" fallback).
  List<OtSurgeryTypeOption> _surgeryTypeOptions = [];

  int? _selectedPackageId;

  late final TextEditingController _diagnosisCtrl, _lensCompanyCtrl, _lensModelCtrl, _lensCostCtrl, _otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl;
  String _eye = 'Both';
  // Replaces the old surgery_type_confirmed checkbox — required, matches
  // web exactly. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  String? _otType;
  bool _mediclaim = false;
  String _lensCategory = 'standard';
  String? _lensType;
  // Web pull 2026-10-13: "Estimated Power" → "Lens Power" dropdown sourced
  // from the active Lens Power master, not a free numeric input. Keeps the
  // field name `estimated_power` server-side (no rename).
  double? _estimatedPower;
  String _roomCategory = 'general';
  // Web parity: this field is a hidden `<input>` on web, only ever set by
  // the OT Package dropdown's JS, never a control the counsellor types
  // into directly — no visible field for it here either.
  String? _packageName;
  String _paymentMode = 'cash';
  // Now required on web (was optional) — null until the user actively
  // answers, so "not yet answered" is distinguishable from "No".
  bool? _bloodReportsVerified;
  bool? _bloodReportsNormal;

  // ── Consent form state ───────────────────────────────────────────────────
  final _patientSigCtrl = SignatureController(penStrokeWidth: 2, penColor: AppColors.darkNavy);
  final _guardianSigCtrl = SignatureController(penStrokeWidth: 2, penColor: AppColors.darkNavy);
  final _witnessCtrl = TextEditingController();
  bool _consentGiven = false;
  bool _savingConsent = false;
  bool _consentSaved = false;

  // ── Send to billing state ────────────────────────────────────────────────
  bool _sendingToBilling = false;
  String? _otStatus;

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl = TextEditingController();
    _lensCompanyCtrl = TextEditingController();
    _lensModelCtrl = TextEditingController();
    _lensCostCtrl = TextEditingController(text: '0');
    _otChargesCtrl = TextEditingController(text: '0');
    _surgeonChargesCtrl = TextEditingController(text: '0');
    _nursingChargesCtrl = TextEditingController(text: '0');
    _consumablesChargesCtrl = TextEditingController(text: '0');
    for (final c in [_otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl, _lensCostCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_diagnosisCtrl, _lensCompanyCtrl, _lensModelCtrl, _lensCostCtrl, _otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl, _witnessCtrl]) {
      c.dispose();
    }
    _patientSigCtrl.dispose();
    _guardianSigCtrl.dispose();
    super.dispose();
  }

  double get _totalEstimate =>
      (double.tryParse(_otChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_surgeonChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_nursingChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_consumablesChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_lensCostCtrl.text.trim()) ?? 0);

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final detail = await OtCounsellorService.instance.fetchCounsellingDetail(widget.bookingId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
          _otStatus = detail.booking.otStatus;
          _surgeryTypeOptions = detail.otSurgeryTypes;
          // `eye`/`ot_type` are NOT real columns on the counselling record —
          // storeCounselling() only ever persists them onto the booking row
          // (`$booking->update(['eye' => ..., 'ot_type' => ...])`). Reading
          // them from `detail.counselling` first was always wrong: that
          // field is either genuinely absent (ot_type — silently null, so
          // the dropdown showed no selection) or has a model-level fallback
          // baked in (eye — OtCounsellingItem.fromJson defaults a missing
          // key to 'Both', which is a non-null value that always won the
          // old `??` chain before it could ever reach the real value on
          // `detail.booking`). `detail.booking.eye`/`.otType` are the actual
          // source of truth and correctly parsed already. See
          // OT_BUGS_ROUND4_AUDIT.md Bug #3 (live-testing follow-up).
          _eye = detail.booking.eye ?? 'Both';
          _otType = detail.booking.otType;
          if (_otType != null && _surgeryTypeOptions.every((t) => t.surgeryName != _otType)) {
            _surgeryTypeOptions = [
              OtSurgeryTypeOption(id: -1, surgeryName: _otType!),
              ..._surgeryTypeOptions,
            ];
          }
          final c = detail.counselling;
          if (c != null) {
            _diagnosisCtrl.text = c.diagnosis ?? '';
            _mediclaim = c.mediclaim;
            _lensCategory = c.lensCategory ?? 'standard';
            _lensCompanyCtrl.text = c.lensCompany ?? '';
            _lensModelCtrl.text = c.lensModel ?? '';
            _lensType = c.lensType;
            _estimatedPower = c.estimatedPower;
            _lensCostCtrl.text = c.lensCost?.toString() ?? '0';
            _packageName = c.packageName;
            _roomCategory = c.roomCategory;
            _otChargesCtrl.text = c.otCharges.toString();
            _surgeonChargesCtrl.text = c.surgeonCharges.toString();
            _nursingChargesCtrl.text = c.nursingCharges.toString();
            _consumablesChargesCtrl.text = c.consumablesCharges.toString();
            _paymentMode = c.paymentMode;
            _bloodReportsVerified = c.bloodReportsVerified;
            _bloodReportsNormal = c.bloodReportsNormal;
            // Best-effort: pre-select the matching package option by name +
            // room category (lens_cost is no longer a meaningful match key).
            final match = detail.packageCostOptions.where((p) => p.packageName == c.packageName && p.roomCategory == c.roomCategory).toList();
            if (match.isNotEmpty) _selectedPackageId = match.first.id;
          }
          final consent = detail.consent;
          if (consent != null) {
            _consentGiven = consent.consentGiven;
            _witnessCtrl.text = consent.witnessName ?? '';
            _consentSaved = consent.consentGiven;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  /// Selecting a package auto-fills package name, room category, and all 4
  /// charge fields — but NOT lens cost, which is a manually-typed field,
  /// fully decoupled from the package (web pull 2026-08-07). See
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  void _selectPackage(OtPackageMasterItem pkg) {
    setState(() {
      _selectedPackageId = pkg.id;
      _roomCategory = pkg.roomCategory;
      _packageName = pkg.packageName;
      _otChargesCtrl.text = pkg.otCharges.toString();
      _surgeonChargesCtrl.text = pkg.surgeonCharges.toString();
      _nursingChargesCtrl.text = pkg.nursingCharges.toString();
      _consumablesChargesCtrl.text = pkg.consumablesCharges.toString();
    });
  }

  // Web parity (web pull 2026-10-13): "Lens Power" dropdown sourced from
  // the active Lens Power master, "★ " prefix for favourites, "+{power}D"
  // label. A legacy value that no longer matches any active master row
  // stays selectable as its own "(previously saved)" option, so resaving
  // the form without touching this field never silently wipes legacy data.
  Widget _buildLensPowerDropdown() {
    final powers = _detail?.lensPowers ?? const [];
    final matchesMaster = _estimatedPower != null && powers.any((p) => p.power == _estimatedPower);
    return DropdownButtonFormField<double>(
      initialValue: _estimatedPower,
      isExpanded: true,
      decoration: _deco('Lens Power'),
      items: [
        for (final p in powers)
          DropdownMenuItem(value: p.power, child: Text('${p.isFavourite ? '★ ' : ''}+${p.power.toStringAsFixed(2)}D')),
        if (_estimatedPower != null && !matchesMaster)
          DropdownMenuItem(value: _estimatedPower, child: Text('+${_estimatedPower!.toStringAsFixed(2)}D (previously saved)')),
      ],
      onChanged: (v) => setState(() => _estimatedPower = v),
    );
  }

  Future<void> _saveCounselling() async {
    if (_otType == null) {
      showAppSnackBar(context, 'Surgery type is required', isError: true);
      return;
    }
    if (_bloodReportsVerified == null || _bloodReportsNormal == null) {
      showAppSnackBar(context, 'Blood reports verified/normal must be answered', isError: true);
      return;
    }
    setState(() => _savingCounselling = true);
    try {
      final counselling = OtCounsellingItem(
        diagnosis: _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
        eye: _eye,
        otType: _otType,
        mediclaim: _mediclaim,
        lensCategory: _lensCategory,
        lensCompany: _lensCompanyCtrl.text.trim().isEmpty ? null : _lensCompanyCtrl.text.trim(),
        lensModel: _lensModelCtrl.text.trim().isEmpty ? null : _lensModelCtrl.text.trim(),
        lensType: _lensType,
        estimatedPower: _estimatedPower,
        lensCost: double.tryParse(_lensCostCtrl.text.trim()),
        packageName: _packageName,
        roomCategory: _roomCategory,
        otCharges: double.tryParse(_otChargesCtrl.text.trim()) ?? 0,
        surgeonCharges: double.tryParse(_surgeonChargesCtrl.text.trim()) ?? 0,
        nursingCharges: double.tryParse(_nursingChargesCtrl.text.trim()) ?? 0,
        consumablesCharges: double.tryParse(_consumablesChargesCtrl.text.trim()) ?? 0,
        paymentMode: _paymentMode,
        bloodReportsVerified: _bloodReportsVerified!,
        bloodReportsNormal: _bloodReportsNormal!,
        notes: null,
      );
      final totalEstimate = await OtCounsellorService.instance.storeCounselling(widget.bookingId, counselling);
      if (!mounted) return;
      setState(() => _savingCounselling = false);
      showAppSnackBar(context, 'Counselling saved — estimate ${currentCurrencySymbol()}${totalEstimate.toStringAsFixed(0)}', isSuccess: true);
    } catch (e) {
      if (mounted) {
        setState(() => _savingCounselling = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _saveConsent() async {
    if (!_consentGiven) {
      showAppSnackBar(context, 'Consent must be given to proceed', isError: true);
      return;
    }
    setState(() => _savingConsent = true);
    try {
      final patientSig = await exportSignatureDataUri(_patientSigCtrl);
      final guardianSig = await exportSignatureDataUri(_guardianSigCtrl);
      await OtCounsellorService.instance.storeConsent(
        widget.bookingId,
        consentGiven: _consentGiven,
        patientSignatureDataUri: patientSig,
        guardianSignatureDataUri: guardianSig,
        witnessName: _witnessCtrl.text.trim().isEmpty ? null : _witnessCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() { _savingConsent = false; _consentSaved = true; });
      showAppSnackBar(context, 'Consent saved', isSuccess: true);
    } catch (e) {
      if (mounted) {
        setState(() => _savingConsent = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _sendToBilling() async {
    setState(() => _sendingToBilling = true);
    try {
      await OtCounsellorService.instance.sendToBilling(widget.bookingId);
      if (!mounted) return;
      showAppSnackBar(context, 'Sent to Billing', isSuccess: true);
      widget.onBillingSent();
    } catch (e) {
      if (mounted) {
        setState(() => _sendingToBilling = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  /// Yes/No pair for a field that's `required boolean` on the backend
  /// (blood_reports_verified/normal, web pull 2026-08-07 — was an optional
  /// checkbox defaulting to false before). `null` means "not yet answered",
  /// checked in `_saveCounselling()` before submit.
  Widget _requiredYesNo(String label, bool? value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ChoiceChip(label: const Text('Yes'), selected: value == true, onSelected: (_) => onChanged(true)),
      const SizedBox(width: 8),
      ChoiceChip(label: const Text('No'), selected: value == false, onSelected: (_) => onChanged(false)),
    ]);
  }

  InputDecoration _deco(String label, {String? suffix}) => appFieldDecoration(label).copyWith(suffixText: suffix);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Close'),
        Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.blueLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(AppRadius.md)), child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Counselling', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 70, padding: EdgeInsets.zero)
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : _buildForm(),
      ),
    ]);
  }

  // Web parity: one scrollable pane, three independent sections/cards
  // (Diagnosis/Lens/Package, Informed Consent, Ready for Billing) — no
  // forced step order, each has its own save action.
  Widget _buildForm() {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildCounsellingSection(),
            const SizedBox(height: 24),
            if (_canConsent) ...[
              _buildConsentSection(),
              const SizedBox(height: 24),
            ],
            _buildBillingCard(),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildCounsellingSection() {
    final detail = _detail!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppSectionHeader(title: 'Diagnosis, Lens & Package', icon: Icons.assignment_outlined),
      TextFormField(controller: _diagnosisCtrl, maxLines: 2, decoration: _deco('Diagnosis')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _otType,
        isExpanded: true,
        decoration: _deco('Surgery Type *'),
        items: _surgeryTypeOptions.map((t) => DropdownMenuItem(value: t.surgeryName, child: Text(t.surgeryName, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) => setState(() => _otType = v),
      ),
      const SizedBox(height: 14),
      EyeChoiceSelector(value: _eye, onChanged: (e) => setState(() => _eye = e)),
      const SizedBox(height: 20),

      const AppSectionHeader(title: 'Lens Selection', icon: Icons.remove_red_eye_outlined),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(initialValue: _lensType, isExpanded: true, decoration: _deco('Lens Type'), items: kOtLensTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setState(() => _lensType = v)),
        ),
        const SizedBox(width: 12),
        Wrap(spacing: 8, children: ['standard', 'premium'].map((c) => ChoiceChip(label: Text(c[0].toUpperCase() + c.substring(1)), selected: _lensCategory == c, onSelected: (_) => setState(() => _lensCategory = c))).toList()),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(controller: _lensCompanyCtrl, decoration: _deco('Lens Company'))),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _lensModelCtrl, decoration: _deco('Lens Model'))),
        const SizedBox(width: 12),
        Expanded(child: _buildLensPowerDropdown()),
      ]),
      const SizedBox(height: 20),

      // Web parity: always visible to anyone who can open this page — web
      // has no separate permission gate for this section (ot_package_set is
      // defined but never enforced anywhere for this screen;
      // ot_counselling_fill alone is what gates page access).
      const AppSectionHeader(title: 'Package & Cost Estimate', icon: Icons.card_giftcard_rounded),
      DropdownButtonFormField<int>(
        initialValue: _selectedPackageId,
        isExpanded: true,
        decoration: _deco('OT Package'),
        items: detail.packageCostOptions.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.packageName} · ${p.roomCategory[0].toUpperCase()}${p.roomCategory.substring(1)}', overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) {
          if (v == null) return;
          _selectPackage(detail.packageCostOptions.firstWhere((p) => p.id == v));
        },
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: ['general', 'private'].map((r) => ChoiceChip(label: Text(r[0].toUpperCase() + r.substring(1)), selected: _roomCategory == r, onSelected: (_) => setState(() => _roomCategory = r))).toList()),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: TextFormField(controller: _otChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('OT Charges', suffix: currentCurrencySymbol()))),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _surgeonChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Surgeon Charges', suffix: currentCurrencySymbol()))),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _nursingChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Nursing Charges', suffix: currentCurrencySymbol()))),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(controller: _consumablesChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Consumables', suffix: currentCurrencySymbol()))),
        const SizedBox(width: 12),
        // Web parity: Lens Cost lives in the Package/Cost section (next to
        // Nursing/Consumables), not in Lens Selection — it's decoupled from
        // package selection (manually typed, folded into Total Estimate).
        Expanded(child: TextFormField(controller: _lensCostCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Lens Cost', suffix: currentCurrencySymbol()))),
      ]),
      const SizedBox(height: 12),
      // Matches web exactly: Total Estimate = ot_charges + surgeon_charges
      // + nursing_charges + consumables_charges + lens_cost (web pull
      // 2026-08-07 changed this from lens_cost-only). See
      // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA22)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Estimate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${currentCurrencySymbol()}${_totalEstimate.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ]),
      ),
      const SizedBox(height: 20),

      // Web parity: Mediclaim lives here — right after Total Estimate,
      // before Payment Mode — not up near Surgery Type/Eye.
      Row(children: [
        Checkbox(value: _mediclaim, onChanged: (v) => setState(() => _mediclaim = v ?? false)),
        const Text('Mediclaim', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      // Web pull 2026-10-13 (same one that dropped the counselling form's
      // old mediclaim↔payment_mode JS auto-sync): Mediclaim and Payment
      // Mode are independent fields now — a mediclaim booking can still be
      // paid cash/online, and a non-mediclaim one can still route through
      // "Mediclaim" as its payment mode. Previously this hid Cash/Online
      // entirely whenever Mediclaim was checked.
      Wrap(spacing: 8, children: ['cash', 'online', 'mediclaim'].map((m) => ChoiceChip(label: Text(m[0].toUpperCase() + m.substring(1)), selected: _paymentMode == m, onSelected: (_) => setState(() => _paymentMode = m))).toList()),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _requiredYesNo('Blood reports verified *', _bloodReportsVerified, (v) => setState(() => _bloodReportsVerified = v))),
        const SizedBox(width: 20),
        Expanded(child: _requiredYesNo('Blood reports normal *', _bloodReportsNormal, (v) => setState(() => _bloodReportsNormal = v))),
      ]),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 220,
          child: AppPrimaryButton(label: 'Save Counselling', icon: Icons.save_rounded, color: AppColors.teal, loading: _savingCounselling, onPressed: _saveCounselling),
        ),
      ),
    ]);
  }

  Widget _buildConsentSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppSectionHeader(title: 'Informed Consent', icon: Icons.draw_rounded),
        Row(children: [
          Checkbox(value: _consentGiven, onChanged: (v) => setState(() => _consentGiven = v ?? false)),
          const Text('Patient / guardian has given consent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        // Web parity: Witness Name comes right after Consent Given, before
        // the signature pads.
        SizedBox(
          width: 400,
          child: TextFormField(controller: _witnessCtrl, decoration: appFieldDecoration('Witness Name')),
        ),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SignaturePadField(label: 'Patient Signature', controller: _patientSigCtrl, height: 200)),
          const SizedBox(width: 20),
          Expanded(child: SignaturePadField(label: 'Guardian Signature (optional)', controller: _guardianSigCtrl, height: 200)),
        ]),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 180,
            child: AppPrimaryButton(label: 'Save Consent', icon: Icons.draw_rounded, loading: _savingConsent, onPressed: _saveConsent),
          ),
        ),
      ]),
    );
  }

  // Matches web's separate "Ready for Billing?" card exactly — its own
  // section with a status subtitle, not just a button glued onto another
  // form's action row.
  Widget _buildBillingCard() {
    final alreadySent = _otStatus == OtStatus.counselled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      constraints: const BoxConstraints(maxWidth: 560),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ready for Billing?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Requires counselling saved and consent given.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 210,
          child: AppPrimaryButton(
            label: alreadySent ? 'Already Sent to Billing' : 'Send to Billing',
            icon: alreadySent ? Icons.check_circle_outline_rounded : Icons.send_rounded,
            color: AppColors.green,
            loading: _sendingToBilling,
            onPressed: (alreadySent || !_consentSaved || _sendingToBilling) ? null : _sendToBilling,
          ),
        ),
      ]),
    );
  }
}
