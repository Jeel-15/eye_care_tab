import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/date_format.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_booking_models.dart';
import '../services/ot_accountant_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/split_pane_scaffold.dart';
import '../utils/currency_format.dart';

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

/// Tablet Accountant / Billing (Round 3 Phase 5) — Pattern A (list + detail
/// split), matching `OtCounsellorDashboardScreen`/`OtAppointmentListScreen`.
/// Tapping a row used to push `OtPaymentScreen` as a full-screen route that
/// covered the whole dashboard (nav rail included) — a narrow, centered form
/// on a wide tablet screen with wasted space either side. See
/// OT_WEB_PARITY_FIX_PRD.md §6.4.
class OtAccountantDashboardScreen extends StatefulWidget {
  const OtAccountantDashboardScreen({super.key});

  @override
  State<OtAccountantDashboardScreen> createState() => _OtAccountantDashboardScreenState();
}

enum _PaneMode { list, detail }

class _OtAccountantDashboardScreenState extends State<OtAccountantDashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<OtBookingSummary> _items = [];
  OtPaginationMeta? _meta;
  OtMoneySummary? _moneySummary;
  bool _loading = true;
  String? _error;
  int _page = 1;

  _PaneMode _paneMode = _PaneMode.list;
  OtBookingSummary? _selected;

  static const _filters = ['today', 'completed', 'refunds'];
  String get _filter => _filters[_tabCtrl.index];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filters.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() => _page = 1);
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await OtAccountantService.instance.fetchBookings(filter: _filter, page: _page);
      if (mounted) setState(() { _items = result.items; _meta = result.meta; _moneySummary = result.moneySummary; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _open(OtBookingSummary item) {
    if (item.otStatus == OtStatus.surgeryRefused) {
      if ((item.refundableBalance ?? 0) > 0) _openRefund(item);
      return;
    }
    setState(() { _paneMode = _PaneMode.detail; _selected = item; });
  }

  void _openRefund(OtBookingSummary item) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RefundDialog(bookingId: item.id),
    ).then((_) => _load());
  }

  void _closePane() => setState(() { _paneMode = _PaneMode.list; _selected = null; });

  Future<void> _viewDetails(OtBookingSummary item) async {
    showDialog(context: context, builder: (_) => _ViewDetailsDialog(item: item));
  }

  Future<void> _viewLatestReceipt(OtBookingSummary item) async {
    try {
      final status = await OtAccountantService.instance.fetchPaymentStatus(item.id);
      if (status.payments.isEmpty) {
        if (mounted) showAppSnackBar(context, 'No payments recorded yet.');
        return;
      }
      if (mounted) showDialog(context: context, builder: (_) => _ReceiptDialog(paymentId: status.payments.last.id, patientName: item.patient?.fullName));
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SplitPaneScaffold(
      showDetail: _paneMode != _PaneMode.list,
      onBack: _closePane,
      listPane: _buildListPane(),
      detailPane: _buildDetailPane(),
      listPaneWidth: 420,
    );
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Accountant / Billing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            IconButton(onPressed: _loading ? null : _load, icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh'),
          ]),
        ),
        TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: 'Today'), Tab(text: 'Completed'), Tab(text: 'Refunds')],
        ),
        if (_moneySummary != null) Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: _buildMoneySummary()),
        const SizedBox(height: 8),
        Expanded(child: _buildBody()),
        if (_meta != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _meta!.currentPage, totalPages: _meta!.lastPage, onPageChange: (p) { setState(() => _page = p); _load(); })),
      ]),
    );
  }

  Widget _buildMoneySummary() {
    final s = _moneySummary!;
    Widget stat(String label, String value, Color color) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        stat('Collected', '${currentCurrencySymbol()}${s.collected.toStringAsFixed(0)}', AppColors.green),
        stat('Refunded', '${currentCurrencySymbol()}${s.refunded.toStringAsFixed(0)}', AppColors.red),
        stat('Net', '${currentCurrencySymbol()}${s.net.toStringAsFixed(0)}', AppColors.primary),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 90);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    if (_items.isEmpty) return AppEmptyState(message: 'No bookings here.', icon: Icons.account_balance_wallet_outlined, onRefresh: _load);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i];
        final selected = _paneMode == _PaneMode.detail && _selected?.id == item.id;
        return AnimatedListItem(
          index: i,
          child: Material(
          color: selected ? AppColors.primaryA08 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: () => _open(item),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primaryA08)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.patient?.fullName ?? 'Patient', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('${item.patient?.patientCode ?? ''}${item.surgeryDate != null ? ' · ${item.surgeryDate}' : ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    if (item.paymentStatus != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: paymentStatusColor(item.paymentStatus!).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text(paymentStatusLabel(item.paymentStatus!), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: paymentStatusColor(item.paymentStatus!))),
                      ),
                    ],
                    if (item.otStatus == OtStatus.surgeryRefused) ...[
                      const SizedBox(height: 6),
                      if ((item.refundableBalance ?? 0) > 0)
                        Text('Refundable: ${currentCurrencySymbol()}${item.refundableBalance!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange))
                      else
                        Text('Refunded: ${currentCurrencySymbol()}${(item.totalRefunded ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                    ],
                  ]),
                ),
                if (item.otStatus == OtStatus.surgeryRefused)
                  (item.refundableBalance ?? 0) > 0
                      ? OutlinedButton(
                          onPressed: () => _openRefund(item),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                          child: const Text('Refund', style: TextStyle(fontSize: 12)),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, color: AppColors.green)
                else ...[
                  IconButton(icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.textSecondary), tooltip: 'View', onPressed: () => _viewDetails(item)),
                  IconButton(icon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppColors.textSecondary), tooltip: 'Receipt', onPressed: () => _viewLatestReceipt(item)),
                ],
              ]),
            ),
          ),
          ),
        );
      },
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.detail && _selected != null) {
      return _panelBox(child: _PaymentDetailPane(key: ValueKey('billing-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', onClose: _closePane, onChanged: _load));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_wallet_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Tap a booking to view', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('its billing details.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
        ]),
      ),
    );
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
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
    setState(() { _loading = true; _loadError = null; });
    try {
      final data = await OtAccountantService.instance.fetchRefundFormData(widget.bookingId);
      if (mounted) {
        setState(() {
          _formData = data;
          _loading = false;
          _receiptCtrl.text = data.autoReceiptNumber;
          _reasonCtrl.text = 'Patient refused OT — full refund';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
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
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Widget _readRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Full Refund — Surgery Refused'),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const SizedBox(height: 120, child: AppSkeletonList(count: 2, itemHeight: 45, padding: EdgeInsets.zero))
            : _loadError != null
                ? Text(_loadError!, style: const TextStyle(color: AppColors.red))
                : Builder(builder: (_) {
                    final f = _formData!;
                    return SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Column(children: [
                            _readRow('Patient', f.booking.patient?.fullName ?? '—'),
                            _readRow('UHID', f.booking.patient?.patientCode ?? '—'),
                            _readRow('Total Paid', '${currentCurrencySymbol()}${f.totalPaid.toStringAsFixed(0)}'),
                            _readRow('Already Refunded', '${currentCurrencySymbol()}${f.totalRefunded.toStringAsFixed(0)}'),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Refund Amount (full)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('${currentCurrencySymbol()}${f.refundAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.red)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: ['cash', 'online'].map((m) => ChoiceChip(label: Text(m[0].toUpperCase() + m.substring(1)), selected: _paymentMode == m, onSelected: (_) => setState(() => _paymentMode = m))).toList()),
                        const SizedBox(height: 12),
                        TextFormField(controller: _receiptCtrl, decoration: const InputDecoration(labelText: 'Receipt Number', border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        TextFormField(controller: _reasonCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
                      ]),
                    );
                  }),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => _closeDialogSafely(context), child: const Text('Cancel')),
        if (_formData != null)
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Record Full Refund'),
          ),
      ],
    );
  }
}

// ── View details dialog ─────────────────────────────────────────────────────────

class _ViewDetailsDialog extends StatefulWidget {
  final OtBookingSummary item;
  const _ViewDetailsDialog({required this.item});

  @override
  State<_ViewDetailsDialog> createState() => _ViewDetailsDialogState();
}

class _ViewDetailsDialogState extends State<_ViewDetailsDialog> {
  bool _loading = true;
  String? _error;
  OtPaymentStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await OtAccountantService.instance.fetchPaymentStatus(widget.item.id);
      if (mounted) setState(() { _status = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Booking Details'),
      content: SizedBox(
        width: 340,
        child: _loading
            ? const SizedBox(height: 100, child: AppSkeletonList(count: 2, itemHeight: 35, padding: EdgeInsets.zero))
            : _error != null
                ? Text(_error!, style: const TextStyle(color: AppColors.red))
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Patient Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
                    const Divider(height: 16),
                    _row('Name', item.patient?.fullName ?? '—'),
                    _row('Contact', item.patient?.contactNo ?? '—'),
                    _row('Patient Code', item.patient?.patientCode ?? '—'),
                    _row('Location', item.patient?.location?.city ?? '—'),
                    const SizedBox(height: 14),
                    const Text('OT Payment Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
                    const Divider(height: 16),
                    _row('OT Date', item.surgeryDate ?? '—'),
                    _row('Package Amount', '${currentCurrencySymbol()}${_status!.requiredTotal.toStringAsFixed(0)}'),
                    _row('Payment Status', paymentStatusLabel(_status!.paymentStatus)),
                    if (_status!.paymentStatus == 'partially_paid') _row('Remaining Balance', '${currentCurrencySymbol()}${_status!.remainingBalance.toStringAsFixed(0)}'),
                    _row('Booking ID', '#${item.id}'),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Text(
                        '${item.patient?.fullName ?? 'This patient'} is scheduled for OT on ${item.surgeryDate ?? '—'}.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await OtAccountantService.instance.fetchReceipt(widget.paymentId);
      if (mounted) setState(() { _receipt = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 640),
        child: _loading
            ? const SizedBox(height: 200, child: AppSkeletonList(count: 2, itemHeight: 80, padding: EdgeInsets.zero))
            : _error != null
                ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: AppColors.red), textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const Text('Retry'))]))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: _ReceiptPreview(receipt: _receipt!, patientNameFallback: widget.patientName),
                    ),
                  ),
      ),
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
        decoration: BoxDecoration(color: const Color(0xFFF7FBFE), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primary.withValues(alpha: 0.10))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
          const SizedBox(height: 8),
          ...rows,
        ]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = receipt.payment;
    final remaining = (receipt.requiredTotal - receipt.totalPaid).clamp(0, double.infinity);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkNavy)),
            Text(p.receiptNumber ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      Text('${currentCurrencySymbol()}${p.packageAmount.toStringAsFixed(2)}', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary)),
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
        _row('Package Total', '${currentCurrencySymbol()}${receipt.requiredTotal.toStringAsFixed(0)}'),
        _row('Total Paid', '${currentCurrencySymbol()}${receipt.totalPaid.toStringAsFixed(0)}'),
        _row('Remaining', '${currentCurrencySymbol()}${remaining.toStringAsFixed(0)}'),
        _row('Status', paymentStatusLabel(receipt.bookingPaymentStatus ?? 'pending')),
      ]),
      const SizedBox(height: 4),
      const Text('This is a computer-generated receipt for OT surgery charges.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
      const SizedBox(height: 14),
      Align(alignment: Alignment.center, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
    ]);
  }
}

// ── Payment detail pane (embedded in the detail pane, not a full screen) ───

class _PaymentDetailPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const _PaymentDetailPane({super.key, required this.bookingId, required this.patientName, required this.onClose, required this.onChanged});

  @override
  State<_PaymentDetailPane> createState() => _PaymentDetailPaneState();
}

class _PaymentDetailPaneState extends State<_PaymentDetailPane> {
  OtPaymentStatus? _status;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final status = await OtAccountantService.instance.fetchPaymentStatus(widget.bookingId);
      if (mounted) setState(() { _status = status; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  /// Client-side only — matches web exactly (`RCP-YYYYMM-XXXX`), no API
  /// call. See OT_WEB_PARITY_FIX_PRD.md §6.2.
  String _generateReceiptNumber() {
    final now = DateTime.now();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final rand = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'RCP-$ym-$rand';
  }

  Widget _readRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Future<void> _openPaymentDialog() async {
    bool loadingForm = true;
    String? formError;
    OtPaymentFormData? formData;
    final receiptCtrl = TextEditingController();
    String paymentMode = 'cash';
    bool saving = false;

    Future<void> loadFormData(void Function(void Function()) ss) async {
      try {
        final data = await OtAccountantService.instance.fetchPaymentFormData(widget.bookingId);
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

    await showDialog<void>(context: context, barrierDismissible: false, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      if (loadingForm && formData == null && formError == null) {
        loadFormData(ss);
      }
      final disabled = formData != null && formData!.remainingBalance <= 0 && formData!.defaultPackageAmount > 0;
      Future<void> save() async {
        ss(() => saving = true);
        try {
          final result = await OtAccountantService.instance.storePayment(widget.bookingId, receiptNumber: receiptCtrl.text.trim(), paymentMode: paymentMode);
          if (mounted) _closeDialogSafely(dCtx);
          await _load();
          widget.onChanged();
          if (mounted) showAppSnackBar(context, result.isFullyPaid ? 'Payment complete — booking moved to Ward' : 'Payment recorded', isSuccess: true);
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Record Payment'),
        content: SizedBox(
          width: 400,
          child: loadingForm
              ? const SizedBox(height: 100, child: AppSkeletonList(count: 2, itemHeight: 35, padding: EdgeInsets.zero))
              : formError != null
                  ? Text(formError!, style: const TextStyle(color: AppColors.red))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Column(children: [
                          _readRow('UHID', formData!.booking.patient?.patientCode ?? '—'),
                          _readRow('OT Package', formData!.counselling?.packageName ?? '—'),
                          _readRow('Total Amount', '${currentCurrencySymbol()}${formData!.requiredTotal.toStringAsFixed(0)}'),
                          _readRow('Amount Paid', '${currentCurrencySymbol()}${formData!.totalPaidSoFar.toStringAsFixed(0)}'),
                          _readRow('Payment Status', paymentStatusLabel(formData!.booking.paymentStatus ?? 'pending')),
                          _readRow('Mediclaim', (formData!.counselling?.mediclaim ?? false) ? 'YES' : 'NO'),
                          _readRow('Invoice Number', formData!.invoiceNumber ?? '—'),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // Amount is no longer editable — web pull 2026-08-07 removed
                      // partial payments; the server always charges the full
                      // remaining balance. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §2.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Amount to be Paid', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkNavy)),
                          Text('${currentCurrencySymbol()}${formData!.remainingBalance.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        ]),
                      ),
                      if (disabled) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Nothing remaining to pay.', style: const TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600)))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(enabled: !disabled, controller: receiptCtrl, decoration: const InputDecoration(labelText: 'Receipt Number', border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        IconButton(tooltip: 'Auto-generate', onPressed: disabled ? null : () => ss(() => receiptCtrl.text = _generateReceiptNumber()), icon: const Icon(Icons.autorenew_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, children: ['cash', 'online', 'mediclaim'].map((m) => ChoiceChip(label: Text(m[0].toUpperCase() + m.substring(1)), selected: paymentMode == m, onSelected: disabled ? null : (_) => ss(() => paymentMode = m))).toList())),
                    ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => _closeDialogSafely(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Payment')),
        ],
      );
    }));
    receiptCtrl.dispose();
  }

  Future<void> _viewReceipt(OtPaymentEntry payment) async {
    showDialog<void>(context: context, builder: (_) => _ReceiptDialog(paymentId: payment.id, patientName: widget.patientName));
  }

  Future<void> _viewBillingDetails() async {
    showDialog<void>(context: context, builder: (_) => _BillingDetailsPaneDialog(bookingId: widget.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onClose, tooltip: 'Close'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Billing', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 70)
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : _buildBody(),
      ),
    ]);
  }

  Widget _buildBody() {
    final s = _status!;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: paymentStatusColor(s.paymentStatus).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(paymentStatusLabel(s.paymentStatus), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: paymentStatusColor(s.paymentStatus)))),
              const Spacer(),
              OutlinedButton.icon(onPressed: _viewBillingDetails, icon: const Icon(Icons.description_outlined, size: 16), label: const Text('Billing Details')),
              const SizedBox(width: 10),
              if (s.paymentStatus != 'paid')
                ElevatedButton.icon(
                  onPressed: s.remainingBalance <= 0 && s.paymentStatus != 'unpriced' ? null : _openPaymentDialog,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Record Payment'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
            ]),
            const Divider(height: 28),
            Row(children: [
              Expanded(child: _stat('Required Total', '${currentCurrencySymbol()}${s.requiredTotal.toStringAsFixed(0)}')),
              Expanded(child: _stat('Total Paid', '${currentCurrencySymbol()}${s.totalPaid.toStringAsFixed(0)}')),
              Expanded(child: _stat('Remaining', '${currentCurrencySymbol()}${s.remainingBalance.toStringAsFixed(0)}', bold: true)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        if (s.payments.isNotEmpty) ...[
          const Text('Payment History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...s.payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _viewReceipt(p),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${currentCurrencySymbol()}${p.packageAmount.toStringAsFixed(0)} · ${p.paymentMode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          if (p.receiptNumber != null) Text('Receipt: ${p.receiptNumber}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ),
                      const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.textSecondary),
                    ]),
                  ),
                ),
              )),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value, {bool bold = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: bold ? 20 : 16, fontWeight: FontWeight.w800)),
      ]);
}

// ── Billing details dialog (Pattern A detail pane's own dialog — separate
// from the list-level _ViewDetailsDialog, different data shape) ───────────

class _BillingDetailsPaneDialog extends StatefulWidget {
  final int bookingId;
  const _BillingDetailsPaneDialog({required this.bookingId});

  @override
  State<_BillingDetailsPaneDialog> createState() => _BillingDetailsPaneDialogState();
}

class _BillingDetailsPaneDialogState extends State<_BillingDetailsPaneDialog> {
  bool _loading = true;
  String? _error;
  OtPaymentFormData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await OtAccountantService.instance.fetchPaymentFormData(widget.bookingId);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Widget _readRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Billing Details'),
      content: SizedBox(
        width: 320,
        child: _loading
            ? const SizedBox(height: 100, child: AppSkeletonList(count: 2, itemHeight: 35, padding: EdgeInsets.zero))
            : _error != null
                ? Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: AppColors.red)), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Retry'))])
                : Builder(builder: (_) {
                    final d = _data!;
                    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _readRow('Patient', d.booking.patient?.fullName ?? '—'),
                      _readRow('UHID', d.booking.patient?.patientCode ?? '—'),
                      _readRow('OT Package', d.counselling?.packageName ?? '—'),
                      _readRow('Total Amount', '${currentCurrencySymbol()}${d.requiredTotal.toStringAsFixed(0)}'),
                      _readRow('Amount Paid', '${currentCurrencySymbol()}${d.totalPaidSoFar.toStringAsFixed(0)}'),
                      _readRow('Remaining Balance', '${currentCurrencySymbol()}${d.remainingBalance.toStringAsFixed(0)}'),
                      _readRow('Mediclaim', (d.counselling?.mediclaim ?? false) ? 'YES' : 'NO'),
                      _readRow('Payment Status', paymentStatusLabel(d.booking.paymentStatus ?? 'pending')),
                      _readRow('Invoice Number', d.invoiceNumber ?? '—'),
                    ]);
                  }),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
