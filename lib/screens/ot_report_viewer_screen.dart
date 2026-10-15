import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_report_models.dart';
import '../services/auth_service.dart';
import '../utils/app_route.dart';
import '../utils/date_format.dart';
import '../services/ot_report_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/skeleton.dart';
import 'prescription_print_screen.dart';
import '../utils/app_date_picker.dart';

/// Tablet OT report viewer — embedded as an OT Reports hub detail pane
/// (Pattern A, matching Masters). No own Scaffold/AppBar/back button — the
/// hub's list pane supplies navigation (embedded on wide screens, a "Back to
/// OT Reports" button on narrow screens). Ported from
/// eye_care_app/lib/screens/ot_report_viewer_screen.dart.
class OtReportViewerScreen extends StatefulWidget {
  final String type;
  final String label;
  final IconData icon;
  final Color accentColor;
  final bool canExport;

  const OtReportViewerScreen({
    super.key,
    required this.type,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.canExport,
  });

  @override
  State<OtReportViewerScreen> createState() => _OtReportViewerScreenState();
}

class _OtReportViewerScreenState extends State<OtReportViewerScreen> {
  bool _loading = true;
  String? _error;
  OtReportResult? _result;
  bool _exporting = false;
  int? _printingPatientId;

  bool get _isHospitalReport => widget.type == 'hospital-report';

  // Web's server default (resolveDateRange()) is start-of-month → today —
  // mirrored here so the initial view matches, and so the picker has a
  // sensible starting point. See OT_WEB_PARITY_FIX_PRD.md §9.4.
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
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
      final r = await OtReportService.instance.fetchReport(
        widget.type,
        from: _fmt(_from),
        to: _fmt(_to),
      );
      if (mounted)
        setState(() {
          _result = r;
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

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: widget.accentColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      await OtReportService.instance.exportReport(
        widget.type,
        format: format,
        from: _fmt(_from),
        to: _fmt(_to),
      );
      if (mounted)
        showAppSnackBar(
          context,
          '${format.toUpperCase()} opened',
          isSuccess: true,
        );
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: widget.accentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (widget.canExport) ...[
              IconButton(
                tooltip: 'Export Excel',
                onPressed: _exporting ? null : () => _export('excel'),
                icon: Icon(
                  Icons.grid_on_rounded,
                  size: 20,
                  color: widget.accentColor,
                ),
              ),
              IconButton(
                tooltip: 'Export PDF',
                onPressed: _exporting ? null : () => _export('pdf'),
                icon: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 20,
                  color: widget.accentColor,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildDateRangeBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const AppSkeletonList(
                  count: 6,
                  itemHeight: 70,
                  padding: EdgeInsets.zero,
                )
              : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : _buildTable(),
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
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 16, color: widget.accentColor),
            const SizedBox(width: 8),
            Text(
              '${_fmt(_from)}  →  ${_fmt(_to)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _cellStyle(bool lead) => TextStyle(
    fontSize: lead ? 14 : 13.5,
    fontWeight: lead ? FontWeight.w800 : FontWeight.w600,
    color: lead ? widget.accentColor : AppColors.textPrimary,
  );

  /// Web (`show.blade.php:64-85`): for `hospital-report`, the last raw row
  /// cell is the patient ID (not a real "Patient ID" column to display) —
  /// it's popped off and used to drive a printer-icon button in place of
  /// the last heading, which is relabeled "Prescription". `hasExam` mirrors
  /// web's check on the Primary/Secondary Exam Time cells (indices 6/7).
  Future<void> _printPrescription(int patientId) async {
    final hospital = AuthService.instance.cachedHospital;
    if (hospital == null) {
      showAppSnackBar(
        context,
        'Hospital info not available. Please re-login.',
        isError: true,
      );
      return;
    }
    setState(() => _printingPatientId = patientId);
    try {
      final (patient, exam) = await OtReportService.instance
          .fetchPrescriptionExam(patientId);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).push(
          appRoute(
            PrescriptionPrintScreen(
              exam: exam,
              patient: patient,
              hospital: hospital,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _printingPatientId = null);
    }
  }

  Widget _buildTable() {
    final r = _result!;
    if (r.rows.isEmpty) {
      return Center(
        child: Text(
          'No data for ${r.from} – ${r.to}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final headings = List<String>.from(r.headings);
    if (_isHospitalReport && headings.isNotEmpty) {
      headings[headings.length - 1] = 'Prescription';
    }

    List<DataCell> buildCells(List<dynamic> row) {
      if (!_isHospitalReport) {
        return [
          for (var i = 0; i < row.length; i++)
            DataCell(Text('${row[i]}', style: _cellStyle(i == 0))),
        ];
      }
      final cells = List<dynamic>.from(row);
      final patientId = cells.isNotEmpty ? cells.removeLast() : null;
      final hasExam =
          (cells.length > 6 && '${cells[6]}' != '-') ||
          (cells.length > 7 && '${cells[7]}' != '-');
      final pid = patientId is int ? patientId : int.tryParse('$patientId');

      return [
        ...cells.asMap().entries.map(
          (e) => DataCell(Text('${e.value}', style: _cellStyle(e.key == 0))),
        ),
        DataCell(
          (hasExam && pid != null)
              ? (_printingPatientId == pid
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: widget.accentColor,
                        ),
                        tooltip: 'View',
                        onPressed: () => _printPrescription(pid),
                      ))
              : const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '${r.rows.length} rows',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.accentColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // DataTable shrink-wraps to its own content width by default, so a
        // report with few/short columns left a large dead empty gap on the
        // right instead of filling the pane. ConstrainedBox(minWidth: ...)
        // forces it to at least fill the container, while still allowing it
        // to grow wider (and scroll) when there are more columns than fit.
        //
        // The horizontal scroller alone had no vertical bound of its own —
        // DataTable always renders every row at its natural height, so once
        // a report had more rows than the pane's height, they just painted
        // past the card's bottom edge with no way to scroll down to them
        // (only the horizontal scrollbar worked). Wrapping in an outer
        // vertical SingleChildScrollView gives that overflow a real scroll
        // instead of letting it escape the card.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AppRefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          widget.accentColor,
                        ),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        dataTextStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        headingRowHeight: 44,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 56,
                        columnSpacing: 22,
                        horizontalMargin: 16,
                        dividerThickness: 0,
                        columns: headings
                            .map((h) => DataColumn(label: Text(h)))
                            .toList(),
                        rows: [
                          for (var i = 0; i < r.rows.length; i++)
                            DataRow(
                              color: WidgetStateProperty.all(
                                i.isEven
                                    ? Colors.white
                                    : widget.accentColor.withValues(
                                        alpha: 0.05,
                                      ),
                              ),
                              cells: buildCells(r.rows[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
