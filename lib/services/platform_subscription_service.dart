import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_subscription_models.dart';
import 'platform_auth_service.dart';

class PlatformSubscriptionService with PlatformAuthenticatedService {
  PlatformSubscriptionService._();
  static final PlatformSubscriptionService instance = PlatformSubscriptionService._();

  final String _base = '${AppConfig.platformApiUrl}/subscriptions';

  Future<PlatformSubscriptionListResult?> getSubscriptions({
    String? status,
    int page = 1,
  }) async {
    try {
      final params = <String, String>{'page': '$page'};
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri = Uri.parse(_base).replace(queryParameters: params);
      final response = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final meta = data['meta'] as Map<String, dynamic>;
          return PlatformSubscriptionListResult(
            subscriptions: (data['subscriptions'] as List)
                .map((e) => PlatformSubscription.fromJson(e as Map<String, dynamic>))
                .toList(),
            stats:    PlatformSubscriptionStats.fromJson(data['stats'] as Map<String, dynamic>),
            total:    meta['total']     as int,
            lastPage: meta['last_page'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlatformSubscription] list ERROR: $e');
    }
    return null;
  }
}
