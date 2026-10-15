import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/permissions.dart';
import '../../models/ot_accountant_models.dart';
import '../../models/ot_booking_models.dart';
import '../../screens/ot_accountant_dashboard_screen.dart';
import '../../services/ot_accountant_service.dart';
import '../../services/permission_service.dart';
import '../../utils/currency_format.dart';
import '../../utils/refreshable.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';
import 'ot_accountant_detail_dialog.dart';

/// Dashboard-home compact desk panel for the Accountant role — mirrors
/// web's `accountant-panel.blade.php` shown directly under the existing
/// "Pending Patients / Refunds / Completed" stat cards. Reuses
/// `OtAccountantService.fetchBookings()` (the same call
/// `OtAccountantDashboardScreen`'s own Payment Queue table uses) plus that
/// screen's own `openOtRecordPaymentDialog`/`openOtFullRefundDialog`/
/// `openOtPaymentReceiptDialog` entry points and `showOtAccountantBookingDetail`,
/// so every button here runs the exact same code path as the dedicated
/// Accountant / Billing screen — just a smaller table with fewer columns
/// (no OT Date, matching web's compact panel exactly).
class AccountantDeskHomePanel extends StatefulWidget {
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;

  const AccountantDeskHomePanel({
    super.key,
    required this.onOpenFullPage,
    this.requestedTab,
    this.onDeskTab,
    this.onCounts,
  });

  @override
  State<AccountantDeskHomePanel> createState() =>
      _AccountantDeskHomePanelState();
}

class _AccountantDeskHomePanelState extends State<AccountantDeskHomePanel>
    implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'Payment Queue'),
    (key: 'refunds', label: 'Refund Queue'),
    (key: 'history', label: 'Completed Payments'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtBookingSummary>> _items = {};
  final Map<String, int> _counts = {};

  bool get _canPaymentRecord =>
      PermissionService.instance.can(Perm.otPaymentRecord);
  bool get _canBillPrint => PermissionService.instance.can(Perm.otBillPrint);

  @override
  void initState() {
    super.initState();
    if (widget.requestedTab != null) _activeTab = widget.requestedTab!;
    _load();
  }

  @override
  void didUpdateWidget(covariant AccountantDeskHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.requestedTab;
    if (next != null && next != _activeTab) setState(() => _activeTab = next);
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        OtAccountantService.instance.fetchBookings(filter: 'queue', perPage: 8),
        OtAccountantService.instance.fetchBookings(
          filter: 'refunds',
          perPage: 8,
        ),
        OtAccountantService.instance.fetchBookings(
          filter: 'history',
          perPage: 8,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _items['queue'] = results[0].items;
        _items['refunds'] = results[1].items;
        _items['history'] = results[2].items;
        _counts['queue'] = results[0].meta.total;
        _counts['refunds'] = results[1].meta.total;
        _counts['history'] = results[2].meta.total;
        _loading = false;
      });
      widget.onCounts?.call(Map<String, int>.from(_counts));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // Web parity (web pull 2026-09-30) — shared with the full OT Accountant
  // Dashboard screen (see `showOtAccountantBookingDetail`) so both surfaces
  // always show the same rich detail instead of drifting apart.
  void _viewDetails(OtBookingSummary item) =>
      showOtAccountantBookingDetail(context, item);

  Future<void> _viewLatestReceipt(OtBookingSummary item) async {
    final paymentId = item.latestPaymentId;
    if (paymentId == null) return;
    await openOtPaymentReceiptDialog(
      context,
      paymentId: paymentId,
      patientName: item.patient?.fullName,
    );
  }

  static const _columns = [
    ScaledTableColumn('PATIENT NAME', 170, grow: true),
    ScaledTableColumn('PHONE', 110),
    ScaledTableColumn('PACKAGE AMOUNT', 140),
    ScaledTableColumn('STATUS', 140),
    ScaledTableColumn('ACTION', 220, hug: true),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    return DeskHomePanel(
      icon: Icons.account_balance_wallet_rounded,
      title: switch (_activeTab) {
        'refunds' => 'Refund Queue',
        'history' => 'Completed Payments',
        _ => 'Payment Queue',
      },
      totalCount: _counts[_activeTab] ?? 0,
      onOpenFullPage: widget.onOpenFullPage,
      tabs: _tabDefs
          .map(
            (t) => DeskHomePanelTab(
              key: t.key,
              label: t.label,
              count: _counts[t.key] ?? 0,
            ),
          )
          .toList(),
      activeTab: _activeTab,
      onTabChanged: (t) {
        setState(() => _activeTab = t);
        widget.onDeskTab?.call(t);
      },
      loading: _loading,
      error: _error,
      onRetry: _load,
      columns: _columns,
      rows: items.map(_rowCells).toList(),
      emptyMessage: switch (_activeTab) {
        'refunds' => 'No refunds pending.',
        'history' => 'No completed payments today.',
        _ => 'No bookings in payment queue.',
      },
    );
  }

  List<Widget> _rowCells(OtBookingSummary item) {
    final ps = item.paymentStatus;
    final isRefunds =
        _activeTab == 'refunds' || item.otStatus == OtStatus.surgeryRefused;
    final canAddPayment =
        _canPaymentRecord && !isRefunds && ps != 'paid' && ps != 'unpriced';
    // OtBookingSummary doesn't carry a separate "total paid" field — the
    // refunds tab's paid-so-far figure is derived as refundable balance +
    // already-refunded (both present on the refunds list rows), matching
    // the amount that was actually paid before any refund.
    final paidSoFar = (item.refundableBalance ?? 0) + (item.totalRefunded ?? 0);

    String statusLabel;
    Color statusColor;
    if (isRefunds) {
      final refundable = item.refundableBalance ?? 0;
      final refunded = item.totalRefunded ?? 0;
      if (refundable <= 0 && refunded > 0) {
        statusLabel = 'Fully Refunded';
        statusColor = AppColors.green;
      } else if (refundable > 0) {
        statusLabel = 'Refund Pending';
        statusColor = AppColors.red;
      } else {
        statusLabel = 'Surgery Refused';
        statusColor = AppColors.textSecondary;
      }
    } else {
      statusLabel = paymentStatusLabel(ps ?? 'pending', verbose: true);
      statusColor = paymentStatusColor(ps ?? 'pending');
    }

    return [
      deskPatientNameCell(
        name: item.patient?.fullName ?? 'Patient',
        subLine: item.patient?.patientCode,
        avatarColors: const [AppColors.teal, AppColors.tealDark],
      ),
      Text(
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
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${currentCurrencySymbol()}${(item.packageAmount ?? 0).toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (isRefunds)
            Text(
              'Paid ${currentCurrencySymbol()}${paidSoFar.toStringAsFixed(0)} · Refunded ${currentCurrencySymbol()}${(item.totalRefunded ?? 0).toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            )
          else if (ps == 'partially_paid' && item.remainingBalance != null)
            Text(
              'Balance: ${currentCurrencySymbol()}${item.remainingBalance!.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          deskStatusPill(statusLabel.toUpperCase(), statusColor),
          if (isRefunds && (item.refundableBalance ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'To return: ${currentCurrencySymbol()}${item.refundableBalance!.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
      ActionCluster(
        children: [
          deskTableActionBtn(
            icon: Icons.visibility_outlined,
            label: 'View',
            onTap: () => _viewDetails(item),
          ),
          if (isRefunds)
            (item.refundableBalance ?? 0) > 0
                ? deskTableActionBtn(
                    icon: Icons.replay_rounded,
                    label: 'Full Refund',
                    color: AppColors.red,
                    onTap: () => openOtFullRefundDialog(
                      context,
                      bookingId: item.id,
                      onDone: _load,
                    ),
                  )
                : deskTableActionLabel('Refund Done')
          else if (ps == 'unpriced')
            deskTableActionLabel('Package Not Set')
          else if (canAddPayment)
            deskTableActionBtn(
              icon: Icons.add_circle_outline_rounded,
              label: ps == 'partially_paid' ? 'Add Balance' : 'Add Payment',
              color: AppColors.primary,
              onTap: () => openOtRecordPaymentDialog(
                context,
                bookingId: item.id,
                onSaved: _load,
              ),
            ),
          if (_canBillPrint && item.latestPaymentId != null && !isRefunds)
            deskTableActionBtn(
              icon: Icons.print_outlined,
              label: 'Receipt',
              onTap: () => _viewLatestReceipt(item),
            ),
        ],
      ),
    ];
  }
}
