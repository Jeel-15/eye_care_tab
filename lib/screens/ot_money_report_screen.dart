import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_accountant_models.dart';
import '../services/ot_accountant_service.dart';
import '../utils/app_route.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';

/// Web's accountant header pill opens this: collected vs refunded for a date
/// range, with the payment rows and the refund rows.
class OtMoneyReportScreen extends StatefulWidget {
  const OtMoneyReportScreen({super.key});

  @override
  State<OtMoneyReportScreen> createState() => _OtMoneyReportScreenState();
}

class _OtMoneyReportScreenState extends State<OtMoneyReportScreen> {
  OtMoneyReport? _report;
  bool _loading = true;
  String? _error;
  bool _customRange = false;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  // Which section's Export button is currently downloading — 'payments',
  // 'refunds', or null. Only one section's icon shows a spinner at a time,
  // matching web's two independent Export buttons.
  String? _exportingSection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _export(String section) async {
    setState(() => _exportingSection = section);
    try {
      await OtAccountantService.instance.downloadMoneyExport(
        section: section,
        startDate: _customRange ? toIsoDate(_start) : null,
        endDate: _customRange ? toIsoDate(_end) : null,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exportingSection = null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await OtAccountantService.instance.fetchMoneyReport(
        startDate: _customRange ? toIsoDate(_start) : null,
        endDate: _customRange ? toIsoDate(_end) : null,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        final start = DateTime.tryParse(report.startDate);
        final end = DateTime.tryParse(report.endDate);
        if (start != null) _start = start;
        if (end != null) _end = end;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  String get _rangeLabel {
    final same =
        _start.year == _end.year &&
        _start.month == _end.month &&
        _start.day == _end.day;
    return same
        ? toDisplayDate(_start)
        : '${toDisplayDate(_start)} – ${toDisplayDate(_end)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OtPanelHeader(
            icon: Icons.trending_up_rounded,
            title: 'OT Money Report',
            subtitle: 'Collections and refunds · $_rangeLabel',
            actions: [
              OtDateRangeChip(
                from: _start,
                to: _end,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 1, 12, 31),
                onChanged: (range) {
                  setState(() {
                    _customRange = true;
                    _start = range.start;
                    _end = range.end;
                  });
                  _load();
                },
              ),
              TextButton(
                onPressed: _customRange
                    ? () {
                        setState(() => _customRange = false);
                        _load();
                      }
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const AppSkeletonList(count: 6, itemHeight: 56)
                : _error != null
                ? AppErrorState(message: _error!, onRetry: _load)
                : _buildBody(_report!),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(OtMoneyReport report) {
    final symbol = currentCurrencySymbol();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _stat(
                  'Collected',
                  '$symbol${report.collected.toStringAsFixed(2)}',
                  const Color(0xFF0D6949),
                  const Color(0x140D6949),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  'Returned',
                  '$symbol${report.refunded.toStringAsFixed(2)}',
                  const Color(0xFFB45309),
                  const Color(0x1FD68910),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  'Net',
                  '$symbol${report.net.toStringAsFixed(2)}',
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppRefreshIndicator(
            onRefresh: _load,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final payments = _table(
                  'Payments in range',
                  'payments',
                  report.payments,
                  'No payments',
                );
                final refunds = _table(
                  'Refunds in range',
                  'refunds',
                  report.refunds,
                  'No refunds',
                );
                if (constraints.maxWidth < 860) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [payments, const SizedBox(height: 16), refunds],
                  );
                }
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: payments),
                      const SizedBox(width: 16),
                      Expanded(child: refunds),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(
    String title,
    String sectionKey,
    List<OtMoneyLine> rows,
    String empty,
  ) {
    final symbol = currentCurrencySymbol();
    final exporting = _exportingSection == sectionKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            exporting
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    onPressed: rows.isEmpty ? null : () => _export(sectionKey),
                    tooltip: 'Export',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 8),
        ScaledDataTable(
          columns: const [
            ScaledTableColumn('DATE', 150),
            ScaledTableColumn('PATIENT', 140, grow: true),
            ScaledTableColumn('AMOUNT', 110),
            ScaledTableColumn('MODE', 80),
          ],
          rows: [
            for (final row in rows)
              [
                Text(
                  formatDateTimeString(row.at),
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  row.patient,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$symbol${row.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  row.mode.isEmpty ? '—' : row.mode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
          ],
          emptyMessage: empty,
        ),
      ],
    );
  }
}

void openOtMoneyReport(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    appRoute(
      Scaffold(
        backgroundColor: AppColors.background,
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: OtMoneyReportScreen(),
          ),
        ),
      ),
    ),
  );
}
