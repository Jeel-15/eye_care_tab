import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../utils/date_format.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_booking_models.dart';
import '../services/auth_service.dart';
import '../services/ot_accountant_service.dart';
import '../services/settings_service.dart';
import '../services/ot_receipt_pdf_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/form_kit.dart';
import '../widgets/ot/ot_accountant_detail_dialog.dart';
import 'ot_money_report_screen.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/segmented_pill_toggle.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_row_action.dart';
import '../widgets/table_tools_bar.dart';
import '../utils/currency_format.dart';
import '../utils/refreshable.dart';

/// See the matching helper in `ot_ward_queue_screen.dart` for why this is
/// needed — `unfocus()` only schedules the focus change, it doesn't apply
/// synchronously, so popping right after it (pass 1's fix) still races.
/// Deferring to `addPostFrameCallback` lets that change resolve first.
void _closeDialogSafely(BuildContext dialogContext) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  });
}

/// Tablet OT Accountant Dashboard — web-parity table redesign (2026-09-18),
/// matching `resources/views/hospital/ot/accountant/dashboard.blade.php`'s
/// "Payment Queue" panel exactly: a colored panel header (title switches to
/// "Refund Queue" on the Refunds tab, matching web), a 3-way Pending /
/// Refunds / Completed segmented toggle + an all-time Collected/Returned
/// money pill in the header's trailing area, then Show-entries + search +
/// a single full-page table (Patient Name / Phone / Package Amount /
/// Status / Action — web has no OT Date column here) with "Showing X to Y
/// of Z entries" pagination
/// — same shared `OtPanelHeader`/`SegmentedPillToggle`/`ScaledDataTable`/
/// `TableToolsBar`/`TablePaginationFooter` widgets already used by
/// Patients, OT Appointments and OT Counsellor, instead of a fourth
/// hand-duplicated copy of that scaffolding.
///
/// Web confirmed (`OtAccountantController::dashboard()`): the 3 tabs are
/// real query-param filters `today`/`refunds`/`completed` labeled
/// "Pending"/"Refunds"/"Completed" (the tablet app's previous TabBar had
/// the right param values but the wrong label — "Today" — and the wrong
/// tab order); the table itself is a real client-side DataTable (full
/// per-tab result set rendered once, search/entries/pagination all run
/// browser-side) — mirrored here by fetching the whole tab in one request
/// (`perPage: 200`, matching the OT Appointments/Counsellor convention) and
/// doing search/pagination locally, not via server paging. All action
/// logic (View/Add Payment/Full Refund/Receipt, and every permission gate)
/// is unchanged from the previous card-list version — only the
/// presentation moved to table rows.
///
/// **Known gap:** web's money pill is a real link to a separate
/// "Collected vs Refunded" report page (`OtAccountantController::
/// moneyReport`) — that report screen doesn't exist in this tablet app, so
/// the pill here is informational only (not tappable) until that page is
/// built as its own task.
class OtAccountantDashboardScreen extends StatefulWidget {
  const OtAccountantDashboardScreen({super.key});

  @override
  State<OtAccountantDashboardScreen> createState() =>
      _OtAccountantDashboardScreenState();
}

class _OtAccountantDashboardScreenState
    extends State<OtAccountantDashboardScreen>
    implements Refreshable {
  static const _filters = ['today', 'refunds', 'completed'];
  static const _filterLabels = {
    'today': 'Pending',
    'refunds': 'Refunds',
    'completed': 'Completed',
  };

  String _filter = 'today';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  List<OtBookingSummary> _items = [];
  OtMoneySummary? _moneySummary;
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  int _perPage = 10;
  int _page = 1;

  bool get _canBillPrint => PermissionService.instance.can(Perm.otBillPrint);
  bool get _canPaymentRecord =>
      PermissionService.instance.can(Perm.otPaymentRecord);

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
      // Web pull 2026-10-05 (commit 65865858) — all three tabs (not just
      // Completed) default to today and accept the same date filter.
      final result = await OtAccountantService.instance.fetchBookings(
        filter: _filter,
        fromDate: toIsoDate(_fromDate),
        toDate: toIsoDate(_toDate),
        perPage: 200,
      );
      if (mounted)
        setState(() {
          _items = result.items;
          _moneySummary = result.moneySummary;
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

  // ── Client-side search + pagination (mirrors web's real DataTables
  // instance over the full per-tab result set) ─────────────────────────────

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

  void _openAddPayment(OtBookingSummary item) {
    // Web: Add Payment on the row → createPayment form (ot_payment_record).
    // Do NOT open the detail pane that loads payment-status (ot_invoice_view).
    openOtRecordPaymentDialog(context, bookingId: item.id, onSaved: _load);
  }

  void _openRefund(OtBookingSummary item) {
    openOtFullRefundDialog(context, bookingId: item.id, onDone: _load);
  }

  // Web parity (web pull 2026-09-30, `_payment-view-modal.blade.php`) —
  // shared with the dashboard-home compact Accountant desk panel (see
  // `showOtAccountantBookingDetail`) so both surfaces always show the same
  // data instead of drifting apart.
  void _viewDetails(OtBookingSummary item) =>
      showOtAccountantBookingDetail(context, item);

  Future<void> _viewLatestReceipt(OtBookingSummary item) async {
    final paymentId = item.latestPaymentId;
    if (paymentId == null) {
      if (mounted) showAppSnackBar(context, 'No payments recorded yet.');
      return;
    }
    if (mounted) {
      openOtPaymentReceiptDialog(
        context,
        paymentId: paymentId,
        patientName: item.patient?.fullName,
      );
    }
  }

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
            _buildHeader(),
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

  // Web parity: the panel title itself switches to "Refund Queue" on the
  // Refunds tab (`OtAccountantController::dashboard()`), not just the tab
  // pill — matched here.
  Widget _buildHeader() {
    final title = switch (_filter) {
      'refunds' => 'Refund Queue',
      'completed' => 'Completed Payments',
      _ => 'Payment Queue',
    };
    return OtPanelHeader(
      icon: Icons.account_balance_wallet_rounded,
      title: title,
      actions: [
        SegmentedPillToggle<String>(
          options: _filters
              .map((f) => (value: f, label: _filterLabels[f]!))
              .toList(),
          selected: _filter,
          onChanged: _setFilter,
          trackColor: Colors.white.withValues(alpha: 0.15),
          activeColor: Colors.white,
          activeTextColor: AppColors.primary,
          inactiveTextColor: Colors.white.withValues(alpha: 0.85),
        ),
        // Web pull 2026-10-05 (commit 65865858) — date range shows on every
        // tab now, not just Completed.
        const SizedBox(width: 10),
        OtDateRangeChip(from: _fromDate, to: _toDate, onChanged: _setDateRange),
        const SizedBox(width: 10),
        if (_moneySummary != null) _moneyPill(_moneySummary!),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _moneyPill(OtMoneySummary s) {
    final parts = [
      'Collected ${currentCurrencySymbol()}${s.collected.toStringAsFixed(0)}',
      'Returned ${currentCurrencySymbol()}${s.refunded.toStringAsFixed(0)}',
      if (s.refundsPending > 0) 'Pending refunds ${s.refundsPending}',
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openOtMoneyReport(context),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────
  //
  // Web parity: `hospital.ot.accountant.dashboard` table — Patient Name /
  // Phone / Package Amount / Status / Action. No OT Date column.
  static const _columns = [
    ScaledTableColumn('PATIENT NAME', 160, grow: true),
    ScaledTableColumn('PHONE', 120),
    ScaledTableColumn('PACKAGE AMOUNT', 130),
    ScaledTableColumn('STATUS', 150),
    ScaledTableColumn('ACTION', 400, hug: true),
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
              : 'No bookings in payment queue.',
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
    final isRefunds =
        _filter == 'refunds' || item.otStatus == OtStatus.surgeryRefused;
    final canAddPayment =
        _canPaymentRecord && !isRefunds && ps != 'paid' && ps != 'unpriced';
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: paymentStatusColor(ps).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    paymentStatusLabel(ps, verbose: true).toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: paymentStatusColor(ps),
                      letterSpacing: 0.3,
                    ),
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
      ActionCluster(
        children: [
          _tableActionBtn(
            icon: Icons.visibility_outlined,
            label: 'View',
            onTap: () => _viewDetails(item),
          ),
          if (isRefunds)
            (item.refundableBalance ?? 0) > 0
                ? _tableActionBtn(
                    icon: Icons.replay_rounded,
                    label: 'Full Refund',
                    color: AppColors.red,
                    onTap: () => _openRefund(item),
                  )
                : _tableActionLabel('Refund Done')
          else if (ps == 'unpriced')
            _tableActionLabel('Package Not Set')
          else if (canAddPayment)
            _tableActionBtn(
              icon: Icons.add_circle_outline_rounded,
              label: ps == 'partially_paid' ? 'Add Balance' : 'Add Payment',
              color: AppColors.primary,
              onTap: () => _openAddPayment(item),
            ),
          if (_canBillPrint && item.latestPaymentId != null && !isRefunds)
            _tableActionBtn(
              icon: Icons.print_outlined,
              label: 'Receipt',
              onTap: () => _viewLatestReceipt(item),
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

  Widget _tableActionLabel(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Full refund dialog ───────────────────────────────────────────────────────
// Amount is never editable — always the full refundable balance, matching
// web exactly (no partial-refund UI exists). See
// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.

class _RefundDialog extends StatefulWidget {
  final int bookingId;
  const _RefundDialog({required this.bookingId});

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  bool _loading = true;
  String? _loadError;
  OtRefundFormData? _formData;
  bool _saving = false;

  final _receiptCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _paymentMode = 'cash';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receiptCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await OtAccountantService.instance.fetchRefundFormData(
        widget.bookingId,
      );
      if (mounted) {
        setState(() {
          _formData = data;
          _loading = false;
          _receiptCtrl.text = data.autoReceiptNumber;
          _reasonCtrl.text = 'Patient refused OT — full refund';
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await OtAccountantService.instance.storeRefund(
        widget.bookingId,
        paymentMode: _paymentMode,
        receiptNumber: _receiptCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        _closeDialogSafely(context);
        showAppSnackBar(context, 'Full refund recorded', isSuccess: true);
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

  Widget _readRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.replay_rounded,
        title: 'Full Refund — Surgery Refused',
        subtitle: _formData?.booking.patient?.fullName,
        colors: const [AppColors.redDark, AppColors.red],
        onClose: _saving ? null : () => _closeDialogSafely(context),
      ),
      body: _loading
          ? const SizedBox(
              height: 120,
              child: AppSkeletonList(
                count: 2,
                itemHeight: 45,
                padding: EdgeInsets.zero,
              ),
            )
          : _loadError != null
          ? Text(_loadError!, style: const TextStyle(color: AppColors.red))
          : Builder(
              builder: (_) {
                final f = _formData!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFill,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          _readRow(
                            'Patient',
                            f.booking.patient?.fullName ?? '—',
                          ),
                          _readRow(
                            'UHID',
                            f.booking.patient?.patientCode ?? '—',
                          ),
                          _readRow(
                            'Total Paid',
                            '${currentCurrencySymbol()}${f.totalPaid.toStringAsFixed(0)}',
                          ),
                          _readRow(
                            'Already Refunded',
                            '${currentCurrencySymbol()}${f.totalRefunded.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Refund Amount (full)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${currentCurrencySymbol()}${f.refundAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: ['cash', 'online']
                          .map(
                            (m) => ChoiceChip(
                              label: Text(m[0].toUpperCase() + m.substring(1)),
                              selected: _paymentMode == m,
                              onSelected: (_) =>
                                  setState(() => _paymentMode = m),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _receiptCtrl,
                      decoration: appFieldDecoration('Receipt Number'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 2,
                      decoration: appFieldDecoration('Reason'),
                    ),
                  ],
                );
              },
            ),
      actions: [
        AppSecondaryButton(
          onPressed: _saving ? null : () => _closeDialogSafely(context),
        ),
        if (_formData != null)
          AppPrimaryButton(
            label: 'Record Full Refund',
            color: AppColors.red,
            loading: _saving,
            onPressed: _save,
          ),
      ],
    );
  }
}

// ── Receipt dialog ─────────────────────────────────────────────────────────────

class _ReceiptDialog extends StatefulWidget {
  final int paymentId;
  final String? patientName;
  const _ReceiptDialog({required this.paymentId, this.patientName});

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  bool _loading = true;
  String? _error;
  OtPaymentReceipt? _receipt;
  bool _printing = false;

  bool get _canBillPrint => PermissionService.instance.can(Perm.otBillPrint);

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
      final r = await OtAccountantService.instance.fetchReceipt(
        widget.paymentId,
      );
      if (mounted)
        setState(() {
          _receipt = r;
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

  Future<void> _printOrShare(OtPaymentReceipt receipt) async {
    setState(() => _printing = true);
    try {
      final hospital = AuthService.instance.cachedHospital;
      // Web's Settings → Print "Letter Pad" toggle — see
      // OtReceiptPdfService.generatePdf()'s doc comment. Best-effort: a
      // failed fetch just falls back to the existing branded header.
      bool letterPadAvailable = false;
      try {
        final settings = await SettingsService.instance.fetchSettings();
        letterPadAvailable = settings.letterPadAvailable;
      } catch (_) {}
      final bytes = await OtReceiptPdfService.instance.generatePdf(
        hospitalName: hospital?.name ?? '',
        receipt: receipt,
        currencySymbol: currentCurrencySymbol(),
        patientNameFallback: widget.patientName,
        hospitalLogoUrl: hospital?.logoUrl,
        letterPadAvailable: letterPadAvailable,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name:
            'Receipt_${receipt.payment.receiptNumber ?? receipt.payment.id}.pdf',
      );
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.receipt_long_rounded,
        title: 'Payment Receipt',
        subtitle: receipt?.payment.receiptNumber,
        onClose: () => Navigator.pop(context),
      ),
      body: _loading
          ? const SizedBox(
              height: 200,
              child: AppSkeletonList(
                count: 2,
                itemHeight: 80,
                padding: EdgeInsets.zero,
              ),
            )
          : _error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          : _ReceiptPreview(
              receipt: receipt!,
              patientNameFallback: widget.patientName,
            ),
      actions: [
        AppSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        if (receipt != null && _canBillPrint)
          AppPrimaryButton(
            label: 'Print / Share',
            icon: Icons.print_outlined,
            loading: _printing,
            onPressed: () => _printOrShare(receipt),
          ),
      ],
    );
  }
}

// Matches web's `d M Y, h:i A` receipt timestamp format exactly.
String _fmtPaidAt(String? raw) => formatDateTimeString(raw);

class _ReceiptPreview extends StatelessWidget {
  final OtPaymentReceipt receipt;
  final String? patientNameFallback;

  const _ReceiptPreview({required this.receipt, this.patientNameFallback});

  Widget _box(String title, List<Widget> rows) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FBFE),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.darkNavy,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = receipt.payment;
    final remaining = (receipt.requiredTotal - receipt.totalPaid).clamp(
      0,
      double.infinity,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${currentCurrencySymbol()}${p.packageAmount.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 18),
        _box('Patient', [
          _row('Name', receipt.patient?.fullName ?? patientNameFallback ?? '—'),
          _row('UHID', receipt.patient?.patientCode ?? '—'),
          _row('Mobile', receipt.patient?.contactNo ?? '—'),
        ]),
        _box('Payment Details', [
          _row('Receipt No.', p.receiptNumber ?? '—'),
          _row('Mode', p.paymentMode.toUpperCase()),
          _row('Mediclaim', p.hasMediclaim ? 'Yes' : 'No'),
          _row('Paid At', _fmtPaidAt(p.paidAt)),
          _row('Recorded By', p.recordedBy?.name ?? '—'),
        ]),
        _box('Package Balance', [
          _row(
            'Package Total',
            '${currentCurrencySymbol()}${receipt.requiredTotal.toStringAsFixed(0)}',
          ),
          _row(
            'Total Paid',
            '${currentCurrencySymbol()}${receipt.totalPaid.toStringAsFixed(0)}',
          ),
          _row(
            'Remaining',
            '${currentCurrencySymbol()}${remaining.toStringAsFixed(0)}',
          ),
          _row(
            'Status',
            paymentStatusLabel(
              receipt.bookingPaymentStatus ?? 'pending',
              verbose: true,
            ),
          ),
        ]),
        const SizedBox(height: 4),
        const Text(
          'This is a computer-generated receipt for OT surgery charges.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── Shared entry points ──────────────────────────────────────────────────
// Extracted so the dashboard home's compact Accountant desk panel calls the
// exact same dialogs/service calls as this dedicated screen's own Payment
// Queue table, instead of a second, drifting copy of each dialog.

/// Client request (2026-10-14): a re-type-to-confirm safety step before
/// Record Payment actually submits — the amount itself is never editable
/// (it's always the server-computed remaining balance shown above), this
/// just makes the accountant consciously re-enter the figure they're about
/// to record, instead of a single tap finalizing a transaction that can't
/// be un-recorded from here. Returns true only once the typed value
/// numerically matches the shown amount.
Future<bool> _confirmOtPaymentAmount(BuildContext context, double amount) async {
  final ctrl = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dCtx) => StatefulBuilder(
      builder: (_, ss) {
        final entered = double.tryParse(ctrl.text.trim());
        final matches = entered != null && (entered - amount).abs() < 0.005;
        final showMismatch = ctrl.text.trim().isNotEmpty && !matches;
        return AppDialog(
          size: AppDialogSize.small,
          header: AppDialogHeader(
            icon: Icons.task_alt_rounded,
            title: 'Confirm Payment Amount',
            onClose: () => Navigator.pop(dCtx, false),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Re-enter the amount below to confirm you are recording the correct payment.', style: TextStyle(fontSize: 13.5)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Text(
                  '${currentCurrencySymbol()}${amount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Confirm Amount',
                  errorText: showMismatch ? 'Does not match the amount above' : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => ss(() {}),
                onSubmitted: (_) {
                  if (matches) Navigator.pop(dCtx, true);
                },
              ),
            ],
          ),
          actions: [
            AppSecondaryButton(onPressed: () => Navigator.pop(dCtx, false)),
            AppPrimaryButton(
              label: 'Confirm & Record Payment',
              onPressed: matches ? () => Navigator.pop(dCtx, true) : null,
            ),
          ],
        );
      },
    ),
  );
  return confirmed == true;
}

/// Opens the same "Record Payment" dialog the Payment Queue table's "Add
/// Payment"/"Add Balance" action uses.
Future<void> openOtRecordPaymentDialog(
  BuildContext context, {
  required int bookingId,
  required VoidCallback onSaved,
}) async {
  bool loadingForm = true;
  String? formError;
  OtPaymentFormData? formData;
  final receiptCtrl = TextEditingController();
  String paymentMode = 'cash';
  bool saving = false;

  // Client-side only — matches web exactly (`RCP-YYYYMM-XXXX`), no API
  // call. See OT_WEB_PARITY_FIX_PRD.md §6.2 (mirrors mobile's
  // ot_payment_screen.dart _generateReceiptNumber(), missing here before).
  String generateReceiptNumber() {
    final now = DateTime.now();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final rand = (now.millisecondsSinceEpoch % 10000).toString().padLeft(
      4,
      '0',
    );
    return 'RCP-$ym-$rand';
  }

  // [highlight] is for the figures a mistake here actually costs money over
  // (Total Amount / Amount Paid) — bigger and in the brand color so they
  // read at a glance instead of blending into the plain UHID/Mediclaim rows.
  Widget readRow(String label, String value, {bool highlight = false}) => Padding(
    padding: EdgeInsets.symmetric(vertical: highlight ? 4 : 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: highlight ? AppColors.darkNavy : AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 11.5,
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Future<void> loadFormData(void Function(void Function()) ss) async {
    try {
      final data = await OtAccountantService.instance.fetchPaymentFormData(
        bookingId,
      );
      formData = data;
      loadingForm = false;
      receiptCtrl.text = data.autoReceiptNumber;
      paymentMode = data.defaultPaymentMode;
      ss(() {});
    } catch (e) {
      formError = e.toString().replaceFirst('Exception: ', '');
      loadingForm = false;
      ss(() {});
    }
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dCtx) => StatefulBuilder(
      builder: (_, ss) {
        if (loadingForm && formData == null && formError == null) {
          loadFormData(ss);
        }
        final disabled =
            formData != null &&
            formData!.remainingBalance <= 0 &&
            formData!.defaultPackageAmount > 0;
        Future<void> save() async {
          ss(() => saving = true);
          try {
            final result = await OtAccountantService.instance.storePayment(
              bookingId,
              receiptNumber: receiptCtrl.text.trim(),
              paymentMode: paymentMode,
            );
            _closeDialogSafely(dCtx);
            onSaved();
            if (dCtx.mounted)
              showAppSnackBar(
                dCtx,
                result.isFullyPaid
                    ? 'Payment complete — booking moved to Ward'
                    : 'Payment recorded',
                isSuccess: true,
              );
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
            icon: Icons.payments_rounded,
            title: 'Record Payment',
            subtitle: formData?.booking.patient?.fullName,
            onClose: saving ? null : () => _closeDialogSafely(dCtx),
          ),
          body: loadingForm
              ? const SizedBox(
                  height: 100,
                  child: AppSkeletonList(
                    count: 2,
                    itemHeight: 35,
                    padding: EdgeInsets.zero,
                  ),
                )
              : formError != null
              ? Text(formError!, style: const TextStyle(color: AppColors.red))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFill,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          readRow(
                            'UHID',
                            formData!.booking.patient?.patientCode ?? '—',
                          ),
                          readRow(
                            'OT Package',
                            formData!.counselling?.packageName ?? '—',
                          ),
                          readRow(
                            'Total Amount',
                            '${currentCurrencySymbol()}${formData!.requiredTotal.toStringAsFixed(0)}',
                            highlight: true,
                          ),
                          readRow(
                            'Amount Paid',
                            '${currentCurrencySymbol()}${formData!.totalPaidSoFar.toStringAsFixed(0)}',
                            highlight: true,
                          ),
                          readRow(
                            'Payment Status',
                            paymentStatusLabel(
                              formData!.booking.paymentStatus ?? 'pending',
                            ),
                          ),
                          readRow(
                            'Mediclaim',
                            (formData!.counselling?.mediclaim ?? false)
                                ? 'YES'
                                : 'NO',
                          ),
                          readRow(
                            'Invoice Number',
                            formData!.invoiceNumber ?? '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The one figure actually being collected right now — made
                    // big enough to read at arm's length, matching the mobile
                    // app's "Amount to be Paid" card (previously missing here
                    // entirely; only Total/Paid showed, with no remaining-
                    // balance readout on this dialog at all).
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'AMOUNT TO BE PAID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currentCurrencySymbol()}${formData!.remainingBalance.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Payment Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryA70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['cash', 'online', 'mediclaim']
                          .map(
                            (m) => ChoiceChip(
                              label: Text(m[0].toUpperCase() + m.substring(1)),
                              selected: paymentMode == m,
                              onSelected: disabled
                                  ? null
                                  : (_) => ss(() => paymentMode = m),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: receiptCtrl,
                            enabled: !disabled,
                            decoration: appFieldDecoration('Receipt Number'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Auto-generate',
                          onPressed: disabled
                              ? null
                              : () => ss(
                                  () => receiptCtrl.text =
                                      generateReceiptNumber(),
                                ),
                          icon: const Icon(Icons.autorenew_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
          actions: [
            AppSecondaryButton(
              onPressed: saving ? null : () => _closeDialogSafely(dCtx),
            ),
            if (formData != null && !disabled)
              AppPrimaryButton(
                label: 'Record Payment',
                loading: saving,
                onPressed: () async {
                  if (await _confirmOtPaymentAmount(dCtx, formData!.remainingBalance)) save();
                },
              ),
          ],
        );
      },
    ),
  );
  receiptCtrl.dispose();
}

/// Opens the same "Full Refund — Surgery Refused" dialog the Refund Queue
/// table's "Full Refund" action uses.
Future<void> openOtFullRefundDialog(
  BuildContext context, {
  required int bookingId,
  required VoidCallback onDone,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RefundDialog(bookingId: bookingId),
  ).then((_) => onDone());
}

/// Opens the same payment-receipt preview dialog the Payment Queue/Completed
/// Payments tables' "Receipt" action uses.
Future<void> openOtPaymentReceiptDialog(
  BuildContext context, {
  required int paymentId,
  String? patientName,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _ReceiptDialog(paymentId: paymentId, patientName: patientName),
  );
}
