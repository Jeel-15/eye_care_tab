class PlatformNotificationItem {
  final int id;
  final int? tenantId;
  final String? tenantName;
  final String? tenantSlug;
  final String subject;
  final String? recipientEmail;
  final String status; // sent | failed | pending
  final String? errorMessage;
  final DateTime? sentAt;

  const PlatformNotificationItem({
    required this.id,
    this.tenantId,
    this.tenantName,
    this.tenantSlug,
    required this.subject,
    this.recipientEmail,
    required this.status,
    this.errorMessage,
    this.sentAt,
  });

  factory PlatformNotificationItem.fromJson(Map<String, dynamic> json) => PlatformNotificationItem(
        id:             json['id']               as int,
        tenantId:       json['tenant_id']        as int?,
        tenantName:     json['tenant_name']      as String?,
        tenantSlug:     json['tenant_slug']      as String?,
        subject:        json['subject']          as String? ?? '',
        recipientEmail: json['recipient_email']  as String?,
        status:         json['status']           as String? ?? '',
        errorMessage:   json['error_message']    as String?,
        sentAt:         json['sent_at'] != null ? DateTime.tryParse(json['sent_at'] as String) : null,
      );
}

class NotificationTenantOption {
  final int id;
  final String name;
  final String slug;
  final String adminEmail;
  final String status;

  const NotificationTenantOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.adminEmail,
    required this.status,
  });

  factory NotificationTenantOption.fromJson(Map<String, dynamic> json) => NotificationTenantOption(
        id:          json['id']           as int,
        name:        json['name']         as String,
        slug:        json['slug']         as String,
        adminEmail:  json['admin_email']  as String? ?? '',
        status:      json['status']       as String? ?? '',
      );
}

class PlatformNotificationData {
  final List<PlatformNotificationItem> history;
  final List<NotificationTenantOption> tenants;

  const PlatformNotificationData({required this.history, required this.tenants});
}
