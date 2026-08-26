class PlatformSubscriptionStats {
  final int total;
  final int active;
  final int expired;

  const PlatformSubscriptionStats({
    required this.total,
    required this.active,
    required this.expired,
  });

  factory PlatformSubscriptionStats.fromJson(Map<String, dynamic> json) => PlatformSubscriptionStats(
        total:   json['total']   as int? ?? 0,
        active:  json['active']  as int? ?? 0,
        expired: json['expired'] as int? ?? 0,
      );
}

class PlatformSubscription {
  final int id;
  final int tenantId;
  final String? tenantName;
  final String? tenantSlug;
  final String cycle;
  final String status;
  final double price;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const PlatformSubscription({
    required this.id,
    required this.tenantId,
    this.tenantName,
    this.tenantSlug,
    required this.cycle,
    required this.status,
    required this.price,
    this.startsAt,
    this.endsAt,
  });

  factory PlatformSubscription.fromJson(Map<String, dynamic> json) => PlatformSubscription(
        id:          json['id']          as int,
        tenantId:    json['tenant_id']   as int,
        tenantName:  json['tenant_name'] as String?,
        tenantSlug:  json['tenant_slug'] as String?,
        cycle:       json['cycle']       as String? ?? '',
        status:      json['status']      as String? ?? '',
        price:       (json['price']      as num?)?.toDouble() ?? 0,
        startsAt:    json['starts_at'] != null ? DateTime.tryParse(json['starts_at'] as String) : null,
        endsAt:      json['ends_at']   != null ? DateTime.tryParse(json['ends_at']   as String) : null,
      );
}

class PlatformSubscriptionListResult {
  final List<PlatformSubscription> subscriptions;
  final PlatformSubscriptionStats stats;
  final int total;
  final int lastPage;

  const PlatformSubscriptionListResult({
    required this.subscriptions,
    required this.stats,
    required this.total,
    required this.lastPage,
  });
}
