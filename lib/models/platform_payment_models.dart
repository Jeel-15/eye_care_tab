class PlatformPaymentStats {
  final double totalRevenue;
  final double thisMonth;
  final int pendingCount;

  const PlatformPaymentStats({
    required this.totalRevenue,
    required this.thisMonth,
    required this.pendingCount,
  });

  factory PlatformPaymentStats.fromJson(Map<String, dynamic> json) => PlatformPaymentStats(
        totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
        thisMonth:    (json['this_month']    as num?)?.toDouble() ?? 0,
        pendingCount: json['pending_count']  as int?  ?? 0,
      );
}

class PlatformPayment {
  final int id;
  final int tenantId;
  final String? tenantName;
  final String? tenantSlug;
  final double amount;
  final String cycle;
  final String method;
  final String status;
  final String? transactionId;
  final String? notes;
  final String? invoicePath;
  final DateTime? paidAt;

  const PlatformPayment({
    required this.id,
    required this.tenantId,
    this.tenantName,
    this.tenantSlug,
    required this.amount,
    required this.cycle,
    required this.method,
    required this.status,
    this.transactionId,
    this.notes,
    this.invoicePath,
    this.paidAt,
  });

  bool get hasInvoice => invoicePath != null && invoicePath!.isNotEmpty;

  factory PlatformPayment.fromJson(Map<String, dynamic> json) => PlatformPayment(
        id:            json['id']          as int,
        tenantId:      json['tenant_id']   as int,
        tenantName:    json['tenant_name'] as String?,
        tenantSlug:    json['tenant_slug'] as String?,
        amount:        (json['amount']     as num?)?.toDouble() ?? 0,
        cycle:         json['cycle']       as String? ?? '',
        method:        json['method']      as String? ?? '',
        status:        json['status']      as String? ?? '',
        transactionId: json['transaction_id'] as String?,
        notes:         json['notes']          as String?,
        invoicePath:   json['invoice_path']   as String?,
        paidAt:        json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      );
}

class PlatformPaymentListResult {
  final List<PlatformPayment> payments;
  final PlatformPaymentStats stats;
  final int total;
  final int lastPage;

  const PlatformPaymentListResult({
    required this.payments,
    required this.stats,
    required this.total,
    required this.lastPage,
  });
}

class TenantOption {
  final int id;
  final String name;
  final String slug;
  final String status;

  const TenantOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
  });

  factory TenantOption.fromJson(Map<String, dynamic> json) => TenantOption(
        id:     json['id']     as int,
        name:   json['name']   as String,
        slug:   json['slug']   as String,
        status: json['status'] as String,
      );
}
