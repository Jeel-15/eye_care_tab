/// Web pull parity (2026-09-29) — `hospital.subscription.index`'s "Plan
/// History" table + the tenant header info, VIEW-only (no checkout/renewal
/// flow — see WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #1 and
/// `SubscriptionApiController`'s docblock for why).
class SubscriptionHistoryRow {
  final String type;
  final DateTime? start;
  final DateTime? end;
  final int? daysUsed;
  final int? daysRemaining;
  final String status; // Active | Expired | Extended
  final int? paymentId;
  final String? notes;

  const SubscriptionHistoryRow({
    required this.type,
    this.start,
    this.end,
    this.daysUsed,
    this.daysRemaining,
    required this.status,
    this.paymentId,
    this.notes,
  });

  bool get hasInvoice => paymentId != null;

  factory SubscriptionHistoryRow.fromJson(Map<String, dynamic> j) => SubscriptionHistoryRow(
        type: j['type'] as String? ?? '',
        start: j['start'] != null ? DateTime.tryParse(j['start'] as String) : null,
        end: j['end'] != null ? DateTime.tryParse(j['end'] as String) : null,
        daysUsed: j['days_used'] as int?,
        daysRemaining: j['days_remaining'] as int?,
        status: j['status'] as String? ?? '',
        paymentId: j['payment_id'] as int?,
        notes: j['notes'] as String?,
      );
}

class SubscriptionBillingData {
  final String tenantName;
  final String countryName;
  final String currencyCode;
  final String currencySymbol;
  final int? subscriptionDaysLeft;
  final List<SubscriptionHistoryRow> historyRows;

  const SubscriptionBillingData({
    required this.tenantName,
    required this.countryName,
    required this.currencyCode,
    required this.currencySymbol,
    this.subscriptionDaysLeft,
    required this.historyRows,
  });

  factory SubscriptionBillingData.fromJson(Map<String, dynamic> j) => SubscriptionBillingData(
        tenantName: j['tenant_name'] as String? ?? '',
        countryName: j['country_name'] as String? ?? '',
        currencyCode: j['currency_code'] as String? ?? '',
        currencySymbol: j['currency_symbol'] as String? ?? '',
        subscriptionDaysLeft: j['subscription_days_left'] as int?,
        historyRows: (j['history_rows'] as List<dynamic>? ?? [])
            .map((e) => SubscriptionHistoryRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
