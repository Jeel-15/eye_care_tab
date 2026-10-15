import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/subscription_billing_models.dart';
import '../services/subscription_billing_service.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/form_kit.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/table_row_action.dart';

/// Web pull parity (2026-09-29) — `hospital.subscription.index`'s "Plan
/// History" table + tenant header, VIEW-only (see
/// WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #1 — the actual renew/checkout
/// flow is web-only, not ported here). Reachable from the dashboard's
/// "Renew →" banner, which was previously a dead, non-tappable label.
Future<void> showSubscriptionBillingPane(BuildContext context) {
  return showPaneDialog<void>(context, wide: true, builder: (dCtx) => const _SubscriptionBillingPane());
}

class _SubscriptionBillingPane extends StatefulWidget {
  const _SubscriptionBillingPane();

  @override
  State<_SubscriptionBillingPane> createState() => _SubscriptionBillingPaneState();
}

class _SubscriptionBillingPaneState extends State<_SubscriptionBillingPane> {
  SubscriptionBillingData? _data;
  bool _loading = true;
  String? _error;
  int? _downloadingPaymentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await SubscriptionBillingService.instance.fetch();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _downloadInvoice(int paymentId) async {
    setState(() => _downloadingPaymentId = paymentId);
    try {
      await SubscriptionBillingService.instance.downloadInvoice(paymentId);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _downloadingPaymentId = null);
    }
  }

  static const _columns = [
    ScaledTableColumn('TYPE', 140),
    ScaledTableColumn('START', 90),
    ScaledTableColumn('END', 90),
    ScaledTableColumn('DAYS USED', 90, headerAlign: TextAlign.center),
    ScaledTableColumn('DAYS LEFT', 90, headerAlign: TextAlign.center),
    ScaledTableColumn('STATUS', 90),
    ScaledTableColumn('INVOICE', 80, headerAlign: TextAlign.center),
  ];

  @override
  Widget build(BuildContext context) {
    final days = _data?.subscriptionDaysLeft;
    return AppDialog(
      size: AppDialogSize.large,
      header: AppDialogHeader(
        icon: Icons.credit_card_rounded,
        title: 'Subscription & Billing',
        subtitle: _data != null ? '${_data!.tenantName}  ·  ${_data!.countryName}  ·  ${_data!.currencyCode} (${_data!.currencySymbol})' : null,
        trailing: days != null
            ? Pill(
                days <= 0 ? 'Plan expired' : '$days day${days == 1 ? '' : 's'} remaining',
                bg: (days <= 0 ? AppColors.red : AppColors.blue).withValues(alpha: 0.12),
                fg: days <= 0 ? AppColors.red : AppColors.blue,
              )
            : null,
        onClose: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)))
              : _buildHistoryTable(),
      actions: [AppSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context))],
    );
  }

  Widget _buildHistoryTable() {
    final rows = _data?.historyRows ?? const <SubscriptionHistoryRow>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Plan History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
      const SizedBox(height: 10),
      ScaledDataTable(columns: _columns, rows: List.generate(rows.length, (i) => _rowCells(rows[i])), emptyMessage: 'No plan history yet.'),
    ]);
  }

  Color _statusColor(String status) => switch (status) {
        'Active' => AppColors.green,
        'Extended' => AppColors.blue,
        _ => AppColors.red,
      };

  List<Widget> _rowCells(SubscriptionHistoryRow r) {
    final color = _statusColor(r.status);
    final busy = _downloadingPaymentId == r.paymentId;
    return [
      Text(r.type, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(r.start != null ? toDisplayDate(r.start!) : '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(r.end != null ? toDisplayDate(r.end!) : '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text('${r.daysUsed ?? '—'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text('${r.daysRemaining ?? '—'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Text(r.status, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
      Align(
        alignment: Alignment.center,
        child: r.hasInvoice
            ? (busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : TableIconAction(icon: Icons.picture_as_pdf_outlined, tooltip: 'Download Invoice', kind: TableActionKind.print, onTap: () => _downloadInvoice(r.paymentId!)))
            : const Text('—', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
      ),
    ];
  }
}
