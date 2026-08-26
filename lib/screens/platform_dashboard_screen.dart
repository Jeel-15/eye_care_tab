import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_dashboard_models.dart';
import '../models/platform_tenant_models.dart';
import '../services/platform_dashboard_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_section_header.dart';
import '../widgets/status_badge.dart';

/// Tablet Platform Dashboard — Pattern B, two-column on wide layouts (stat
/// grid + charts left, subscription cycles + recent hospitals right) instead
/// of mobile's single scrolling column. Embedded in [PlatformShell] (no own
/// Scaffold/AppBar). Business logic and charts (fl_chart) ported unchanged
/// from eye_care_app/lib/screens/platform_dashboard_screen.dart.
///
/// "Recently Registered" rows are not yet tappable — PlatformHospitalDetailScreen
/// lands in the next batch of this phase; wire the tap-through then.
class PlatformDashboardScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformDashboardScreen({super.key, required this.admin});

  @override
  State<PlatformDashboardScreen> createState() => _PlatformDashboardScreenState();
}

class _PlatformDashboardScreenState extends State<PlatformDashboardScreen> {
  bool _loading = true;
  String? _error;
  PlatformDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await PlatformDashboardService.instance.getDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Could not load dashboard. Check your connection.';
      } else {
        _data = data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _buildError();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: _buildContent(_data!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.primaryA20),
          const SizedBox(height: 12),
          Text(_error!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
        ]),
      ),
    );
  }

  Widget _buildContent(PlatformDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGreetingCard(data.stats),
        const SizedBox(height: 20),
        const AppSectionHeader(title: 'Hospital Overview'),
        const SizedBox(height: 10),
        _buildStatGrid(data.stats),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= AppBreakpoints.medium;
          final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppSectionHeader(title: 'Revenue Trend'),
            const SizedBox(height: 8),
            _RevenueChart(trend: data.revenueTrend),
            const SizedBox(height: 20),
            const AppSectionHeader(title: 'New Hospital Registrations'),
            const SizedBox(height: 8),
            _RegistrationsChart(trend: data.registrationsTrend),
          ]);
          final right = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppSectionHeader(title: 'Subscription Cycles'),
            const SizedBox(height: 8),
            _CyclesCard(cycles: data.subscriptionCycles),
            const SizedBox(height: 20),
            const AppSectionHeader(title: 'Recently Registered'),
            const SizedBox(height: 8),
            _buildRecentList(data.recentHospitals),
          ]);
          if (!wide) return Column(children: [left, const SizedBox(height: 20), right]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: left), const SizedBox(width: 20), Expanded(flex: 2, child: right)]);
        }),
      ],
    );
  }

  Widget _buildGreetingCard(PlatformStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.primaryA30, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back, ${widget.admin.name.split(' ').first}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${stats.totalHospitals} hospitals on the platform', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(children: [
            _heroStat('₹${_formatAmount(stats.monthlyRevenue)}', 'This Month', Colors.white),
            _heroDivider(),
            _heroStat('${stats.expiringThisWeek}', 'Expiring Soon', Colors.white),
            _heroDivider(),
            _heroStat('${stats.active}', 'Active Now', Colors.white),
          ]),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color.withValues(alpha: 0.7))),
    ]);
  }

  Widget _heroDivider() => Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 20), color: Colors.white.withValues(alpha: 0.25));

  Widget _buildStatGrid(PlatformStats s) {
    final cards = [
      _StatItem('Total', '${s.totalHospitals}', Icons.local_hospital_rounded, AppColors.primary),
      _StatItem('Active', '${s.active}', Icons.check_circle_outline_rounded, AppColors.green),
      _StatItem('Trial', '${s.trial}', Icons.timer_outlined, AppColors.secondary),
      _StatItem('Grace', '${s.grace}', Icons.hourglass_bottom_rounded, AppColors.orange),
      _StatItem('Suspended', '${s.suspended}', Icons.block_rounded, AppColors.red),
      _StatItem('Inactive', '${s.inactive}', Icons.pause_circle_outline_rounded, AppColors.textDisabled),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisExtent: 68, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final c = cards[i];
        return Container(
          decoration: AppDecorations.accentCard(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: c.color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(children: [
                        Container(width: 30, height: 30, decoration: AppDecorations.iconBox(color: c.color), child: Icon(c.icon, color: c.color, size: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(c.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            Text(c.label, style: AppTextStyles.cardSubtitle),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentList(List<TenantSummary> hospitals) {
    if (hospitals.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No hospitals yet.', style: AppTextStyles.bodySmall)));
    }
    return Column(
      children: hospitals.asMap().entries.map((entry) {
        final t = entry.value;
        return AnimatedListItem(
          index: entry.key,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: AppDecorations.card(),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: AppDecorations.iconBox(color: AppColors.primary, radius: AppRadius.sm),
                child: Center(child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.name, style: AppTextStyles.cardTitle, overflow: TextOverflow.ellipsis),
                  Text('${t.slug}${t.city != null ? ' · ${t.city}' : ''}', style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              StatusBadge.hospitalStatus(t.status),
            ]),
          ),
        );
      }).toList(),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// ── Revenue Bar Chart ─────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  final ChartSeries trend;
  const _RevenueChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final maxY = trend.values.isEmpty ? 1.0 : (trend.values.reduce((a, b) => a > b ? a : b) * 1.3).ceilToDouble();
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      decoration: AppDecorations.card(),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem('₹${_shortAmt(rod.toY)}', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.labels.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(trend.labels[idx].split(' ').first, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)));
              },
            )),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.primaryA08, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: trend.values.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value, color: AppColors.primary, width: 18, borderRadius: BorderRadius.circular(AppRadius.xs))])).toList(),
        ),
      ),
    );
  }
}

// ── Registrations Line Chart ──────────────────────────────────────────────

class _RegistrationsChart extends StatelessWidget {
  final ChartSeries trend;
  const _RegistrationsChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final maxY = trend.values.isEmpty ? 1.0 : (trend.values.reduce((a, b) => a > b ? a : b) * 1.4).ceilToDouble();
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      decoration: AppDecorations.card(),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: trend.values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.green,
              barWidth: 2.5,
              belowBarData: BarAreaData(show: true, color: AppColors.green.withValues(alpha: 0.10)),
              dotData: FlDotData(show: true, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: AppColors.green, strokeWidth: 0, strokeColor: Colors.transparent)),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.labels.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(trend.labels[idx].split(' ').first, style: TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)));
              },
            )),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.primaryA08, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${s.y.toInt()} hospitals', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Subscription Cycles Card ────────────────────────────────────────────

class _CyclesCard extends StatelessWidget {
  final CycleData cycles;
  const _CyclesCard({required this.cycles});

  @override
  Widget build(BuildContext context) {
    final total = cycles.total == 0 ? 1 : cycles.total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CycleRow('Monthly', cycles.monthly, total, AppColors.primary),
        const SizedBox(height: 10),
        _CycleRow('Quarterly', cycles.quarterly, total, AppColors.orange),
        const SizedBox(height: 10),
        _CycleRow('Yearly', cycles.yearly, total, AppColors.green),
      ]),
    );
  }
}

class _CycleRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _CycleRow(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 72, child: Text(label, style: AppTextStyles.cardSubtitle.copyWith(fontWeight: FontWeight.w600))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(AppRadius.full), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: color.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation<Color>(color)))),
      const SizedBox(width: 8),
      SizedBox(width: 32, child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.right)),
    ]);
  }
}

String _shortAmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
