import 'platform_tenant_models.dart';

class PlatformDashboardData {
  final PlatformStats stats;
  final ChartSeries revenueTrend;
  final ChartSeries registrationsTrend;
  final CycleData subscriptionCycles;
  final List<TenantSummary> recentHospitals;

  const PlatformDashboardData({
    required this.stats,
    required this.revenueTrend,
    required this.registrationsTrend,
    required this.subscriptionCycles,
    required this.recentHospitals,
  });

  factory PlatformDashboardData.fromJson(Map<String, dynamic> json) {
    final rev  = json['revenue_trend']       as Map<String, dynamic>;
    final reg  = json['registrations_trend'] as Map<String, dynamic>;
    final cyc  = json['subscription_cycles'] as Map<String, dynamic>;
    final recs = (json['recent_hospitals'] as List<dynamic>);

    return PlatformDashboardData(
      stats: PlatformStats.fromJson(json['stats'] as Map<String, dynamic>),
      revenueTrend: ChartSeries(
        labels: List<String>.from(rev['months'] as List),
        values: (rev['amounts'] as List).map((e) => (e as num).toDouble()).toList(),
      ),
      registrationsTrend: ChartSeries(
        labels: List<String>.from(reg['months'] as List),
        values: (reg['counts'] as List).map((e) => (e as num).toDouble()).toList(),
      ),
      subscriptionCycles: CycleData(
        monthly:   cyc['monthly']   as int,
        quarterly: cyc['quarterly'] as int,
        yearly:    cyc['yearly']    as int,
      ),
      recentHospitals: recs.map((e) => TenantSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PlatformStats {
  final int totalHospitals;
  final int active, trial, grace, suspended, inactive;
  final double monthlyRevenue;
  final int expiringThisWeek;

  const PlatformStats({
    required this.totalHospitals,
    required this.active,
    required this.trial,
    required this.grace,
    required this.suspended,
    required this.inactive,
    required this.monthlyRevenue,
    required this.expiringThisWeek,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) => PlatformStats(
        totalHospitals:    json['total_hospitals']    as int,
        active:            json['active']             as int,
        trial:             json['trial']              as int,
        grace:             json['grace']              as int,
        suspended:         json['suspended']          as int,
        inactive:          json['inactive']           as int,
        monthlyRevenue:    (json['monthly_revenue']   as num).toDouble(),
        expiringThisWeek:  json['expiring_this_week'] as int,
      );
}

class ChartSeries {
  final List<String> labels;
  final List<double> values;

  const ChartSeries({required this.labels, required this.values});
}

class CycleData {
  final int monthly, quarterly, yearly;

  const CycleData({required this.monthly, required this.quarterly, required this.yearly});

  int get total => monthly + quarterly + yearly;
}
