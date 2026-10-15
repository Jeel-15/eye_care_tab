import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_discharge_models.dart';
import '../services/ot_discharge_service.dart';
import '../services/permission_service.dart';
import '../utils/date_format.dart';
import '../utils/ot_status_style.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/form_kit.dart';
import '../widgets/ot/ot_discharge_detail_dialog.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/table_row_action.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/app_date_picker.dart';
import '../utils/refreshable.dart';

/// Tablet Discharge & Invoices — web-parity table redesign (2026-09-19),
/// matching `resources/views/hospital/ot/billing/index.blade.php`'s
/// "Billing Desk" panel exactly: a colored panel header, Show-entries +
/// search + a single full-page table (Patient / OT Date / Status / Invoice
/// / Actions) with "Showing X to Y of Z entries" pagination — same shared
/// `OtPanelHeader`/`ScaledDataTable`/`TableToolsBar`/`TablePaginationFooter`
/// widgets already used by every other OT screen in this series, instead
/// of a seventh hand-duplicated copy of that scaffolding.
///
/// Web confirmed (`OtInvoiceController::index()`): the Actions cell is one
/// of TWO mutually-exclusive states per row, not a fixed button set —
/// `@if(!$hasInvoice)` a "Generate" (invoice) action, `@if($hasInvoice)`
/// the 3 print buttons (Bill Summary / Discharge / Certificate) — never
/// both. `$hasInvoice` comes straight off the booking list query, so no
/// separate per-row invoice fetch is needed to decide which state to show
/// (the old split-pane version fetched `OtInvoiceSummary` per booking just
/// to gate this, plus rendered a full invoice line-item/total-amount
/// summary card that has no equivalent trigger anywhere on this web page —
/// dropped here along with `ot_discharge_detail_screen.dart`/
/// `DischargeDetailPane`, now fully unused). Web also confirmed the
/// follow-up-date picker is part of the *initial* Generate action only
/// (an inline field there, a small dialog here — same
/// `_GenerateInvoiceDialog` already proven in the previous version) —
/// never shown again once an invoice exists; the 3 print buttons then
/// print directly with no extra dialog (Certificate's own "Rest Days"
/// prompt is a pre-existing tablet-side addition, unrelated to this
/// redesign, left as-is).
///
/// **Bug fixed while rewriting**: the old code gated the "Discharge"
/// print button with the SAME permission (`ot_discharge_generate`) used
/// for the header's "Generate Invoice" button. Web actually gates the
/// Generate action with `ot_billing_manage` and the Discharge print
/// button with `ot_discharge_generate` — two different permissions,
/// confirmed against the blade's `@haspermission` checks. Split into
/// `_canGenerateInvoice`/`_canDischargePrint` accordingly.

/// Closes a dialog that contains a text field safely. `unfocus()` only
/// *schedules* the focus change — it doesn't complete synchronously — so
/// popping the route immediately after it still tears the field down mid
/// focus-change and throws `InheritedElement`'s `_dependents.isEmpty`
/// assertion (a full red-screen crash, since it's thrown by the framework
/// during Element teardown, not inside any catchable app code). Deferring
/// the pop to `addPostFrameCallback` lets that scheduled change fully
/// resolve on its own frame first. Same pattern as `ot_ward_queue_screen.dart`
/// (see OT_WEB_PARITY_FIX_PRD.md §4.3) — the Rest Days dialog below was
/// written later and never got it, which is why Certificate was the only
/// one of the 3 print buttons that could crash (it's the only dialog with a
/// text field — and this one `autofocus: true`s it, making the race
/// near-guaranteed rather than merely possible).
void _closeDialogSafely<T>(BuildContext dialogContext, [T? result]) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (dialogContext.mounted) Navigator.pop(dialogContext, result);
  });
}

class OtDischargeDashboardScreen extends StatefulWidget {
  const OtDischargeDashboardScreen({super.key});

  @override
  State<OtDischargeDashboardScreen> createState() =>
      _OtDischargeDashboardScreenState();
}

class _OtDischargeDashboardScreenState extends State<OtDischargeDashboardScreen>
    implements Refreshable {
  List<OtBookingSummary> _items = [];
  bool _loading = true;
  String? _error;

  // Web pull 2026-09-19: Queue/All toggle — 'queue' (Billing Desk) or
  // 'history' (Discharged Patients, date-ranged).
  String _filter = 'queue';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _perPage = 10;
  int _page = 1;

  int? _busyId;
  OtDischargeDocType? _busyType;

  bool get _canGenerateInvoice =>
      PermissionService.instance.can(Perm.otBillingManage);
  bool get _canBillPrint => PermissionService.instance.can(Perm.otBillPrint);
  bool get _canDischargePrint =>
      PermissionService.instance.can(Perm.otDischargeGenerate);
  bool get _canCertificatePrint =>
      PermissionService.instance.can(Perm.otCertificatePrint);

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
      final result = await OtDischargeService.instance.fetchBookings(
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
  // the dashboard-home compact Discharge desk panel (see
  // `showOtDischargeBookingDetail`) so both surfaces always show the same
  // rich data instead of a 2-fact placeholder. Also fixes View being
  // rendered only on the History tab — web always shows it.
  void _showBookingView(OtBookingSummary item) =>
      showOtDischargeBookingDetail(context, item);

  Future<void> _generateInvoice(OtBookingSummary item) async {
    final result = await showDialog<_InvoiceDraft>(
      context: context,
      builder: (_) => const _GenerateInvoiceDialog(),
    );
    if (result == null) return;
    setState(() => _busyId = item.id);
    try {
      final r = await OtDischargeService.instance.generateInvoice(
        item.id,
        followUpDate: result.followUpDate,
      );
      if (!mounted) return;
      // Web pull 2026-09-28: generating the invoice no longer discharges the
      // booking — it only becomes Discharged once all 3 documents below are
      // printed (see the PRINTS x/3 badge in the table and _maybeAnnounceDischarged()).
      showAppSnackBar(
        context,
        'Invoice ${r.invoiceNumber} generated. Print all 3 documents to complete discharge.',
        isSuccess: true,
      );
      await _load();
      // Matches web's redirect-to-invoice-print after generate.
      if (mounted) await _print(item.id, OtDischargeDocType.invoice);
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _print(int bookingId, OtDischargeDocType type) async {
    int? restDays;
    if (type == OtDischargeDocType.certificate) {
      restDays = await _askRestDays();
      if (restDays == null) return;
    }
    setState(() {
      _busyId = bookingId;
      _busyType = type;
    });
    try {
      await OtDischargeService.instance.printDocument(
        bookingId,
        type,
        restDays: restDays,
      );
      // Web pull 2026-09-28: a print can be the one that completes the
      // 3-document discharge gate — reload so the row's PRINTS x/3 badge
      // (and, once all 3 are done, the STATUS column) reflects the real
      // server state instead of staying stale until the next manual refresh.
      await _load();
      if (mounted) _maybeAnnounceDischarged(bookingId);
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted)
        setState(() {
          _busyId = null;
          _busyType = null;
        });
    }
  }

  // One-time "now discharged" confirmation — web's new checklist UI shows
  // this state inline; the tablet table just gets a toast since the row's
  // own PRINTS x/3 → STATUS badge switch already carries the persistent
  // signal (see _rowCells/_actionsCell).
  void _maybeAnnounceDischarged(int bookingId) {
    final item = _items.where((b) => b.id == bookingId).firstOrNull;
    if (item == null) return;
    final done = item.dischargePrintsDone ?? 0;
    final total = item.dischargePrintsTotal ?? 3;
    if (done >= total && item.otStatus.toLowerCase() == 'discharged') {
      showAppSnackBar(
        context,
        'All documents printed — patient discharged.',
        isSuccess: true,
      );
    }
  }

  Future<int?> _askRestDays() => askOtDischargeCertificateRestDays(context);

  // ── Client-side search + pagination (web: real client-side DataTable
  // over the full result set — mirrored here) ──────────────────────────────

  List<OtBookingSummary> get _filteredItems {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
          (it) => (it.patient?.fullName.toLowerCase().contains(q) ?? false),
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
              icon: Icons.receipt_long_rounded,
              title: _filter == 'history'
                  ? 'Discharged Patients'
                  : 'Billing Desk',
              subtitle: _filter == 'history'
                  ? 'Completed discharges — view details and reprint documents.'
                  : 'Generate invoices and print discharge documents.',
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
    ScaledTableColumn('PATIENT', 170, grow: true),
    ScaledTableColumn('OT DATE', 100),
    ScaledTableColumn('STATUS', 120),
    ScaledTableColumn('INVOICE', 110),
    ScaledTableColumn('ACTIONS', 500, hug: true),
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
              : 'No records available for billing.',
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
    final hasInvoice = item.hasInvoice ?? false;
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
      _statusCell(item, hasInvoice),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (hasInvoice ? AppColors.green : AppColors.orange).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            hasInvoice ? 'Generated' : 'Pending',
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: hasInvoice ? AppColors.green : AppColors.orange,
            ),
          ),
        ),
      ),
      _actionsCell(item, hasInvoice),
    ];
  }

  // Web pull 2026-09-28 (`billing/index.blade.php`): while an invoice exists
  // but the booking isn't discharged yet, the desk list shows a "PRINTS x/3"
  // progress badge in place of the raw status — the raw `ot_status` would
  // just read "OPERATED" the whole time otherwise, which no longer tells
  // staff anything about how close discharge actually is.
  Widget _statusCell(OtBookingSummary item, bool hasInvoice) =>
      otDischargeStatusCell(item, hasInvoice);

  Widget _actionsCell(OtBookingSummary item, bool hasInvoice) {
    final isHistory = _filter == 'history';
    if (!hasInvoice) {
      // Web parity (web pull 2026-09-30): the blade's View button is
      // unconditional on every row, not just once an invoice exists or only
      // on the History tab — a prior version of this cell only ever showed
      // View when `isHistory`, silently dropping it from every Queue row
      // without an invoice yet.
      if (isHistory || !_canGenerateInvoice) {
        return Align(alignment: Alignment.centerLeft, child: _viewBtn(item));
      }
      final busy = _busyId == item.id;
      return Align(
        alignment: Alignment.centerLeft,
        child: ActionCluster(
          children: [
            _viewBtn(item),
            TableLabelAction(
              label: 'Generate Invoice',
              icon: Icons.receipt_rounded,
              tone: TableLabelTone.teal,
              busy: busy,
              onTap: busy ? null : () => _generateInvoice(item),
            ),
          ],
        ),
      );
    }
    return ActionCluster(
      children: [
        _viewBtn(item),
        if (_canBillPrint)
          _docBtn(item, OtDischargeDocType.summaryBill, 'Bill Summary'),
        if (_canDischargePrint)
          _docBtn(item, OtDischargeDocType.discharge, 'Discharge'),
        // Web parity (corrected 2026-09-29): the previous `!isHistory &&` guard
        // here was based on an incorrect assumption about what the blade does.
        // Read `hospital/ot/billing/index.blade.php` directly — its
        // `OtBooking::DISCHARGE_PRINTS` loop has no `$isHistory` condition at
        // all; all 3 documents (including Certificate) render on both the
        // Queue and History tabs, gated only by per-document permission, same
        // as Bill Summary/Discharge right above.
        if (_canCertificatePrint)
          _docBtn(item, OtDischargeDocType.certificate, 'Certificate'),
      ],
    );
  }

  Widget _viewBtn(OtBookingSummary item) => TableLabelAction(
    label: 'View',
    icon: Icons.visibility_outlined,
    onTap: () => _showBookingView(item),
  );

  // Web pull 2026-09-28: each print button gets a green checkmark once its
  // document is done (`billing/index.blade.php`) — re-printing an
  // already-done document is still allowed (the gate only cares whether it
  // has EVER been printed, not "only once"), this is just a status hint.
  DateTime? _printedAtFor(OtBookingSummary item, OtDischargeDocType type) =>
      otDischargeDocPrintedAt(item, type);

  Widget _docBtn(OtBookingSummary item, OtDischargeDocType type, String label) {
    final busy = _busyId == item.id && _busyType == type;
    final done = _printedAtFor(item, type) != null;
    return TableLabelAction(
      label: label,
      icon: done ? Icons.check_circle_rounded : Icons.picture_as_pdf_outlined,
      tone: done ? TableLabelTone.positive : TableLabelTone.secondary,
      busy: busy,
      onTap: busy ? null : () => _print(item.id, type),
    );
  }
}

class _InvoiceDraft {
  final String? followUpDate;
  const _InvoiceDraft({this.followUpDate});
}

class _GenerateInvoiceDialog extends StatefulWidget {
  const _GenerateInvoiceDialog();

  @override
  State<_GenerateInvoiceDialog> createState() => _GenerateInvoiceDialogState();
}

class _GenerateInvoiceDialogState extends State<_GenerateInvoiceDialog> {
  // Web's Billing Desk only exposes a Follow-up Date field next to the
  // Generate button, pre-filled with today+7 — no Tax Amount/Discount
  // fields exist in the real UI even though the backend accepts them (see
  // OT_DISCHARGE_INVOICES_WEB_PARITY_FIX_PLAN.md).
  late DateTime _followUpDate = DateTime.now().add(const Duration(days: 7));

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _followUpDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.receipt_long_rounded,
        title: 'Generate Invoice',
        subtitle: 'Discharges the booking',
        onClose: () => Navigator.pop(context),
      ),
      body: InkWell(
        onTap: _pickFollowUp,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InputDecorator(
          decoration: appFieldDecoration(
            'Follow-up Date',
            suffix: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.primaryA50,
            ),
          ),
          child: Text(toDisplayDate(_followUpDate)),
        ),
      ),
      actions: [
        AppSecondaryButton(onPressed: () => Navigator.pop(context)),
        AppPrimaryButton(
          label: 'Generate',
          onPressed: () => Navigator.pop(
            context,
            _InvoiceDraft(followUpDate: _fmt(_followUpDate)),
          ),
        ),
      ],
    );
  }
}

/// Opens the same "Rest Days" prompt the Certificate print button uses
/// before printing — shared with the dashboard home's compact Discharge
/// Counter desk panel so both call the exact same dialog.
Future<int?> askOtDischargeCertificateRestDays(BuildContext context) async {
  final ctrl = TextEditingController(text: '7');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.event_busy_rounded,
        title: 'Rest Days',
        subtitle: 'Discharge certificate',
        onClose: () => _closeDialogSafely(ctx),
      ),
      body: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: appFieldDecoration('Rest Days', hint: '1-90'),
      ),
      actions: [
        AppSecondaryButton(onPressed: () => _closeDialogSafely(ctx)),
        AppPrimaryButton(
          label: 'Print',
          icon: Icons.print_rounded,
          onPressed: () => _closeDialogSafely<int>(
            ctx,
            int.tryParse(ctrl.text.trim())?.clamp(1, 90),
          ),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

/// Opens the same "Generate Invoice" (follow-up date) dialog the Billing
/// Desk table's Generate action uses — returns the chosen follow-up date
/// (`Y-m-d`) or null if cancelled. Shared with the dashboard home's compact
/// Discharge Counter desk panel so both call the exact same dialog widget.
Future<String?> showOtGenerateInvoiceDialog(BuildContext context) async {
  final result = await showDialog<_InvoiceDraft>(
    context: context,
    builder: (_) => const _GenerateInvoiceDialog(),
  );
  return result?.followUpDate;
}

/// The printed-at timestamp for one of the 3 discharge documents — same
/// lookup the Billing Desk table's per-document checkmark uses. Shared with
/// the dashboard home's compact Discharge Counter desk panel.
DateTime? otDischargeDocPrintedAt(
  OtBookingSummary item,
  OtDischargeDocType type,
) => switch (type) {
  OtDischargeDocType.summaryBill => item.summaryBillPrintedAt,
  OtDischargeDocType.discharge => item.dischargePrintedAt,
  OtDischargeDocType.certificate => item.certificatePrintedAt,
  _ => null,
};

/// The Billing Desk table's STATUS cell — while an invoice exists but the
/// booking isn't discharged yet, shows a "PRINTS x/3" progress badge in
/// place of the raw status (web pull 2026-09-28, `billing/index.blade.php`).
/// Shared with the dashboard home's compact Discharge Counter desk panel so
/// both compute this exactly the same way.
Widget otDischargeStatusCell(OtBookingSummary item, bool hasInvoice) {
  final done = item.dischargePrintsDone;
  final total = item.dischargePrintsTotal;
  final showPrintsBadge =
      hasInvoice &&
      done != null &&
      total != null &&
      item.otStatus.toLowerCase() != 'discharged';
  if (showPrintsBadge) {
    final complete = done >= total;
    final color = complete ? AppColors.green : AppColors.orange;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          'PRINTS $done/$total',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
  return Align(
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
  );
}
