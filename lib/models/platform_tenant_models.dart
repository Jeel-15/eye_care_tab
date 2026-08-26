class TenantSummary {
  final int id;
  final String name;
  final String slug;
  final String? hospitalCode;
  final String? adminName;
  final String? adminEmail;
  final String? adminPhone;
  final String? city;
  final String? state;
  final String status;
  final DateTime? trialEndsAt;
  final bool isSetupDone;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  const TenantSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.hospitalCode,
    this.adminName,
    this.adminEmail,
    this.adminPhone,
    this.city,
    this.state,
    required this.status,
    this.trialEndsAt,
    this.isSetupDone = false,
    this.createdAt,
    this.deletedAt,
  });

  factory TenantSummary.fromJson(Map<String, dynamic> json) => TenantSummary(
        id:           json['id'] as int,
        name:         json['name'] as String,
        slug:         json['slug'] as String,
        hospitalCode: json['hospital_code'] as String?,
        adminName:    json['admin_name'] as String?,
        adminEmail:   json['admin_email'] as String?,
        adminPhone:   json['admin_phone'] as String?,
        city:         json['city'] as String?,
        state:        json['state'] as String?,
        status:       json['status'] as String,
        trialEndsAt:  json['trial_ends_at'] != null ? DateTime.tryParse(json['trial_ends_at'] as String) : null,
        isSetupDone:  json['is_setup_done'] as bool? ?? false,
        createdAt:    json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        deletedAt:    json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
      );

  bool get isArchived => deletedAt != null;
}

class TenantDetail extends TenantSummary {
  final String? country;
  final String? timezone;
  final DateTime? setupCompletedAt;
  final List<SubscriptionItem> subscriptions;
  final List<PaymentItem> payments;

  const TenantDetail({
    required super.id,
    required super.name,
    required super.slug,
    super.hospitalCode,
    super.adminName,
    super.adminEmail,
    super.adminPhone,
    super.city,
    super.state,
    required super.status,
    super.trialEndsAt,
    super.isSetupDone,
    super.createdAt,
    super.deletedAt,
    this.country,
    this.timezone,
    this.setupCompletedAt,
    required this.subscriptions,
    required this.payments,
  });

  factory TenantDetail.fromJson(Map<String, dynamic> json) => TenantDetail(
        id:           json['id'] as int,
        name:         json['name'] as String,
        slug:         json['slug'] as String,
        hospitalCode: json['hospital_code'] as String?,
        adminName:    json['admin_name'] as String?,
        adminEmail:   json['admin_email'] as String?,
        adminPhone:   json['admin_phone'] as String?,
        city:         json['city'] as String?,
        state:        json['state'] as String?,
        status:       json['status'] as String,
        trialEndsAt:  json['trial_ends_at'] != null ? DateTime.tryParse(json['trial_ends_at'] as String) : null,
        isSetupDone:  json['is_setup_done'] as bool? ?? false,
        createdAt:    json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        deletedAt:    json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
        country:      json['country'] as String?,
        timezone:     json['timezone'] as String?,
        setupCompletedAt: json['setup_completed_at'] != null ? DateTime.tryParse(json['setup_completed_at'] as String) : null,
        subscriptions: (json['subscriptions'] as List<dynamic>)
            .map((e) => SubscriptionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (json['payments'] as List<dynamic>)
            .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SubscriptionItem {
  final int id;
  final String cycle;
  final double price;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const SubscriptionItem({
    required this.id,
    required this.cycle,
    required this.price,
    required this.status,
    this.startsAt,
    this.endsAt,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) => SubscriptionItem(
        id:       json['id'] as int,
        cycle:    json['cycle'] as String,
        price:    (json['price'] as num).toDouble(),
        status:   json['status'] as String,
        startsAt: json['starts_at'] != null ? DateTime.tryParse(json['starts_at'] as String) : null,
        endsAt:   json['ends_at']   != null ? DateTime.tryParse(json['ends_at']   as String) : null,
      );
}

class PaymentItem {
  final int id;
  final double amount;
  final String cycle;
  final String method;
  final String status;
  final String? transactionId;
  final DateTime? paidAt;

  const PaymentItem({
    required this.id,
    required this.amount,
    required this.cycle,
    required this.method,
    required this.status,
    this.transactionId,
    this.paidAt,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) => PaymentItem(
        id:            json['id'] as int,
        amount:        (json['amount'] as num).toDouble(),
        cycle:         json['cycle']  as String,
        method:        json['method'] as String,
        status:        json['status'] as String,
        transactionId: json['transaction_id'] as String?,
        paidAt:        json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      );
}

class TenantListResult {
  final List<TenantSummary> hospitals;
  final int total;
  final int lastPage;

  const TenantListResult({required this.hospitals, required this.total, required this.lastPage});
}
