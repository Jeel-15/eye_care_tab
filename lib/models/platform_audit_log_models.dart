import '../constants/app_colors.dart';
import 'package:flutter/material.dart';

class PlatformAuditLog {
  final int id;
  final String action;
  final String? description;
  final int? tenantId;
  final String? tenantName;
  final String? tenantSlug;
  final int? adminId;
  final String? adminName;
  final String? ipAddress;
  final dynamic oldValues;
  final dynamic newValues;
  final DateTime? createdAt;

  const PlatformAuditLog({
    required this.id,
    required this.action,
    this.description,
    this.tenantId,
    this.tenantName,
    this.tenantSlug,
    this.adminId,
    this.adminName,
    this.ipAddress,
    this.oldValues,
    this.newValues,
    this.createdAt,
  });

  factory PlatformAuditLog.fromJson(Map<String, dynamic> json) => PlatformAuditLog(
        id:          json['id']          as int,
        action:      json['action']      as String? ?? '',
        description: json['description'] as String?,
        tenantId:    json['tenant_id']   as int?,
        tenantName:  json['tenant_name'] as String?,
        tenantSlug:  json['tenant_slug'] as String?,
        adminId:     json['admin_id']    as int?,
        adminName:   json['admin_name']  as String?,
        ipAddress:   json['ip_address']  as String?,
        oldValues:   json['old_values'],
        newValues:   json['new_values'],
        createdAt:   json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  Color get actionColor {
    if (action.contains('created'))    return AppColors.green;
    if (action.contains('activated'))  return AppColors.green;
    if (action.contains('reactivated')) return AppColors.secondary;
    if (action.contains('suspended'))  return AppColors.red;
    if (action.contains('archived'))   return AppColors.orange;
    if (action.contains('payment'))    return AppColors.teal;
    if (action.contains('updated'))    return AppColors.secondary;
    if (action.contains('notification')) return AppColors.primary;
    return AppColors.textDisabled;
  }
}

class TenantFilterOption {
  final int id;
  final String name;
  final String slug;

  const TenantFilterOption({required this.id, required this.name, required this.slug});

  factory TenantFilterOption.fromJson(Map<String, dynamic> json) => TenantFilterOption(
        id:   json['id']   as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}

class PlatformAuditLogListResult {
  final List<PlatformAuditLog> logs;
  final List<TenantFilterOption> tenants;
  final int total;
  final int lastPage;

  const PlatformAuditLogListResult({
    required this.logs,
    required this.tenants,
    required this.total,
    required this.lastPage,
  });
}
