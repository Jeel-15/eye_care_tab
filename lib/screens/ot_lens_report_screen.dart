import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_report_models.dart';
import '../services/ot_report_service.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/skeleton.dart';
import '../utils/app_date_picker.dart';

/// Web pull 2026-10-13 — `OtReportController::lensReport()`. A dedicated
/// page (summary cards + lens-power breakdown), not the generic
/// headings/rows `OtReportViewerScreen` the rest of the OT Reports
/// catalogue uses. Embedded as an OT Reports hub detail pane (Pattern A,
/// same convention as OtReportViewerScreen) — no own Scaffold/AppBar.
/// Default date range is today-today (web's resolveLensReportDateRange()),
/// not the generic reports' start-of-month.
class OtLensReportScreen extends StatefulWidget {
  final bool canExport;

  const OtLensReportScreen({super.key, required this.canExport});

  @override
  State<OtLensReportScreen> createState() => _OtLensReportScreenState();
}

class _OtLensReportScreenState extends State<OtLensReportScreen> {
  bool _loading = true;
  String? _error;
  OtLensReportData? _data;
  bool _exporting = false;

  late DateTime _from = DateTime.now();
  late DateTime _to = DateTime.now();

  String _fmt(DateTime d) => toIsoDate(d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await OtReportService.instance.fetchLensReport(from: _fmt(_from), to: _fmt(_to));
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: AppColors.purple)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await OtReportService.instance.exportLensReport(from: _fmt(_from), to: _fmt(_to));
      if (mounted) showAppSnackBar(context, 'Excel opened', isSuccess: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.remove_red_eye_rounded, color: AppColors.purple, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Lens Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          if (widget.canExport)
            IconButton(
              tooltip: 'Export Excel',
              onPressed: _exporting ? null : _export,
              icon: Icon(Icons.grid_on_rounded, size: 20, color: AppColors.purple),
            ),
        ]),
        const SizedBox(height: 12),
        _buildDateRangeBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 6, itemHeight: 70, padding: EdgeInsets.zero)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : _buildBody(),
        ),
      ],
    );
  }

  Widget _buildDateRangeBar() {
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primaryA08),
        ),
        child: Row(children: [
          Icon(Icons.date_range_rounded, size: 16, color: AppColors.purple),
          const SizedBox(width: 8),
          Text('${_fmt(_from)}  →  ${_fmt(_to)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.purple)),
        ]),
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          Container(
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  TextStyle _cellStyle(bool lead) => TextStyle(
        fontSize: lead ? 14 : 13.5,
        fontWeight: lead ? FontWeight.w800 : FontWeight.w600,
        color: lead ? AppColors.purple : AppColors.textPrimary,
      );

  Widget _buildBody() {
    final d = _data!;
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(children: [
            _summaryCard('Lenses Used', '${d.summary.totalLensesUsed}', Icons.remove_red_eye_rounded, AppColors.purple),
            const SizedBox(width: 10),
            _summaryCard('Surgeries', '${d.summary.totalSurgeries}', Icons.cut_rounded, AppColors.teal),
            const SizedBox(width: 10),
            _summaryCard('Unique Powers', '${d.summary.uniquePowers}', Icons.blur_circular_rounded, AppColors.blue),
          ]),
          if (d.powerSummary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryA08),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Power Breakdown', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: d.powerSummary.map((row) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: const Color(0xFFF4F8FB), borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text('+${row.power}D × ${row.quantity}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.purple)),
                      )).toList(),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Text('Lens Usage Detail', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.purple)),
          const SizedBox(height: 10),
          if (d.detailRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No data for ${d.from} – ${d.to}', style: const TextStyle(color: AppColors.textSecondary))),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.purple),
                    headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: 22,
                    horizontalMargin: 16,
                    dividerThickness: 0,
                    columns: d.detailHeadings.map((h) => DataColumn(label: Text(h))).toList(),
                    rows: [
                      for (var i = 0; i < d.detailRows.length; i++)
                        DataRow(
                          color: WidgetStateProperty.all(i.isEven ? Colors.white : AppColors.purple.withValues(alpha: 0.05)),
                          cells: [
                            for (var c = 0; c < d.detailRows[i].length; c++)
                              DataCell(Text('${d.detailRows[i][c]}', style: _cellStyle(c == 1))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
