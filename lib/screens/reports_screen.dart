import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/report_models.dart';
import '../services/permission_service.dart';
import '../services/report_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';

/// Tablet OPD Reports module — Pattern D (persistent filter panel + real
/// DataTable). Mirrors web's redesigned landing page (a "Total Collection"
/// banner + 3 tappable channel tiles, no filter form or list at that level)
/// plus a per-channel drill-down view embedded in the same screen (switched
/// internally, not pushed as a route — consistent with how this shell hosts
/// every other content-switched module).
class ReportsScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const ReportsScreen({super.key, required this.user, required this.hospital});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _View { landing, channel }

class _ReportsScreenState extends State<ReportsScreen> {
  _View _view = _View.landing;

  // Landing state
  ReportChannelCounts? _counts;
  bool _countsLoading = true;
  String? _countsError;
  bool _exportingLanding = false;

  // Channel drill-down state
  String? _channel;
  String? _channelLabel;
  ReportChannelResult? _result;
  bool _loading = false;
  String? _error;
  ReportFilter _filter = const ReportFilter();
  ReportFilter _pendingFilter = const ReportFilter();
  int _page = 1;
  bool _filterOpen = false;
  bool _exportingChannel = false;

  bool get _isOtAppointment => _channel == 'ot_appointment';

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  // ── Landing ──────────────────────────────────────────────────────────

  Future<void> _loadCounts() async {
    setState(() { _countsLoading = true; _countsError = null; });
    try {
      final counts = await ReportService.instance.fetchChannelCounts(const ReportFilter());
      if (mounted) setState(() { _counts = counts; _countsLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _countsError = e.toString().replaceFirst('Exception: ', '');
          _countsLoading = false;
        });
      }
    }
  }

  Future<void> _exportLanding(String format) async {
    setState(() => _exportingLanding = true);
    showAppSnackBar(context, 'Preparing ${format.toUpperCase()} export…', duration: const Duration(seconds: 2));
    try {
      await ReportService.instance.downloadAndOpenExport(format: format, filter: const ReportFilter());
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showAppSnackBar(context, '${format == 'excel' ? 'Excel' : 'PDF'} opened successfully', isSuccess: true, duration: const Duration(seconds: 2));
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingLanding = false);
    }
  }

  void _openChannel(String channel, String label) {
    setState(() {
      _view = _View.channel;
      _channel = channel;
      _channelLabel = label;
      _filter = const ReportFilter();
      _pendingFilter = const ReportFilter();
      _page = 1;
      _result = null;
      _error = null;
      _filterOpen = false;
    });
    _load(page: 1);
  }

  void _backToLanding() {
    setState(() {
      _view = _View.landing;
      _channel = null;
      _channelLabel = null;
      _result = null;
    });
    _loadCounts();
  }

  // ── Channel drill-down ──────────────────────────────────────────────

  Future<void> _load({int? page}) async {
    final channel = _channel;
    if (channel == null) return;
    final p = page ?? _page;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ReportService.instance.fetchChannel(channel, _filter, page: p);
      if (mounted) setState(() { _result = result; _page = p; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filter = _pendingFilter;
      _page = 1;
      _result = null;
    });
    _load(page: 1);
  }

  void _clearFilter() {
    setState(() {
      _pendingFilter = const ReportFilter();
      _filter = const ReportFilter();
      _page = 1;
      _result = null;
    });
    _load(page: 1);
  }

  Future<void> _exportChannel(String format) async {
    final channel = _channel;
    if (channel == null) return;
    setState(() => _exportingChannel = true);
    showAppSnackBar(context, 'Preparing ${format.toUpperCase()} export…', duration: const Duration(seconds: 2));
    try {
      await ReportService.instance.downloadAndOpenExport(format: format, filter: _filter.copyWith(type: channel));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showAppSnackBar(context, '${format == 'excel' ? 'Excel' : 'PDF'} opened successfully', isSuccess: true, duration: const Duration(seconds: 2));
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _exportingChannel = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _pendingFilter.dateRange.isNotEmpty ? _parseDateRange(_pendingFilter.dateRange) : null,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (range != null) {
      final s = _fmtDate(range.start);
      final e = _fmtDate(range.end);
      setState(() => _pendingFilter = _pendingFilter.copyWith(dateRange: s == e ? s : '$s to $e'));
    }
  }

  void _clearDateRange() => setState(() => _pendingFilter = _pendingFilter.copyWith(dateRange: ''));

  DateTimeRange? _parseDateRange(String dr) {
    final parts = dr.split(' to ');
    if (parts.length == 2) {
      final s = DateTime.tryParse(parts[0]);
      final e = DateTime.tryParse(parts[1]);
      if (s != null && e != null) return DateTimeRange(start: s, end: e);
    } else if (parts.length == 1) {
      final d = DateTime.tryParse(parts[0]);
      if (d != null) return DateTimeRange(start: d, end: d);
    }
    return null;
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDateRange(String dr) {
    if (dr.isEmpty) return 'All Dates';
    final parts = dr.split(' to ');
    if (parts.length == 2 && parts[0] == parts[1]) return _prettyDate(parts[0]);
    if (parts.length == 2) return '${_prettyDate(parts[0])} – ${_prettyDate(parts[1])}';
    return _prettyDate(dr);
  }

  String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.instance.can(Perm.reportsView)) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.primaryA25),
          const SizedBox(height: 16),
          Text('No Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryA50)),
          const SizedBox(height: 6),
          Text('You do not have permission to view reports.', style: TextStyle(fontSize: 13, color: AppColors.primaryA35)),
        ]),
      );
    }
    return _view == _View.landing ? _buildLanding() : _buildChannel();
  }

  // ── Landing UI ───────────────────────────────────────────────────────

  Widget _buildLanding() {
    return RefreshIndicator(
      onRefresh: _loadCounts,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(4),
        children: [
          Row(
            children: [
              Text('Patient Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const Spacer(),
              if (PermissionService.instance.can(Perm.reportsExport)) ...[
                IconButton(tooltip: 'Export Excel', onPressed: _exportingLanding ? null : () => _exportLanding('excel'), icon: Icon(Icons.table_chart_outlined, size: 20, color: AppColors.primary)),
                IconButton(tooltip: 'Export PDF', onPressed: _exportingLanding ? null : () => _exportLanding('pdf'), icon: Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.primary)),
              ],
              IconButton(
                tooltip: 'Refresh',
                onPressed: _countsLoading ? null : _loadCounts,
                icon: _countsLoading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryA55))
                    : Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_countsLoading && _counts == null)
            SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_countsError != null && _counts == null)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 14),
                  Text(_countsError!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _loadCounts,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                  ),
                ]),
              ),
            )
          else if (_counts != null) ...[
            _CollectionBanner(total: _counts!.totalCollection),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, c) {
              // 3 simple tiles need far less room than the Pattern-D
              // filter-panel+DataTable layout below — use the lower
              // `compact` threshold here instead of `medium`, otherwise
              // real tablets (content width often ~1000-1100px once the
              // nav rail is subtracted) never get the 3-up row and always
              // fall back to a stacked column.
              final wide = c.maxWidth >= AppBreakpoints.compact;
              final tiles = [
                _ChannelTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF7D3C98),
                  label: 'OT Appointment',
                  count: _counts!.otAppointment,
                  onTap: () => _openChannel('ot_appointment', 'OT Appointment Patients'),
                ),
                _ChannelTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: AppColors.primary,
                  label: 'Walk-in',
                  count: _counts!.walkin,
                  onTap: () => _openChannel('walkin', 'Walk-in Patients'),
                ),
                _ChannelTile(
                  icon: Icons.call_rounded,
                  iconColor: const Color(0xFF117A65),
                  label: 'Phone Appointment',
                  count: _counts!.phone,
                  onTap: () => _openChannel('phone', 'Phone Appointment Patients'),
                ),
              ];
              if (!wide) {
                return Column(children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 12), child: t)]);
              }
              return Row(children: [for (final t in tiles) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: t))]);
            }),
          ],
        ],
      ),
    );
  }

  // ── Channel UI (Pattern D: persistent filter panel + DataTable) ───────

  Widget _buildChannel() {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= AppBreakpoints.medium;
      final filterPanel = _FilterPanel(
        alwaysOpen: wide,
        isOpen: _filterOpen,
        filter: _pendingFilter,
        filterOptions: _result?.filterOptions,
        isOtAppointment: _isOtAppointment,
        onToggle: () => setState(() => _filterOpen = !_filterOpen),
        onApply: _applyFilter,
        onClear: _clearFilter,
        onPickDateRange: _pickDateRange,
        onClearDateRange: _clearDateRange,
        onReceptionistChanged: (id) => setState(() => _pendingFilter = _pendingFilter.copyWith(receptionistId: id)),
        onDoctorChanged: (id) => setState(() => _pendingFilter = _pendingFilter.copyWith(doctorId: id)),
        onLocationChanged: (id) => setState(() => _pendingFilter = _pendingFilter.copyWith(locationId: id)),
        onCaseChanged: (id) => setState(() => _pendingFilter = _pendingFilter.copyWith(caseId: id)),
        displayDateRange: _displayDateRange(_pendingFilter.dateRange),
        errorMessage: _result == null ? _error : null,
        onRetry: () => _load(),
      );
      final content = _buildChannelContent();
      if (!wide) {
        return Column(children: [_channelHeaderBar(), const SizedBox(height: 12), filterPanel, const SizedBox(height: 16), Expanded(child: content)]);
      }
      return Column(children: [
        _channelHeaderBar(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: filterPanel),
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          ),
        ),
      ]);
    });
  }

  Widget _channelHeaderBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back to Patient Reports',
          onPressed: _backToLanding,
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        Text(_channelLabel ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildChannelContent() {
    final result = _result;
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildTableHeader(result),
                const Divider(height: 1),
                Expanded(child: _buildTableBody(result)),
                if (result != null && result.meta.lastPage > 1) ...[
                  const Divider(height: 1),
                  _PaginationBar(
                    meta: result.meta,
                    loading: _loading,
                    onPrev: () => _load(page: _page - 1),
                    onNext: () => _load(page: _page + 1),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTableHeader(ReportChannelResult? result) {
    final p = PermissionService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      child: Row(
        children: [
          Text(
            result == null ? 'Report' : '${result.meta.total} record${result.meta.total == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          if (result != null) ...[
            const SizedBox(width: 10),
            Text('Page ${result.meta.currentPage} / ${result.meta.lastPage}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          if (p.can(Perm.reportsExport)) ...[
            IconButton(tooltip: 'Export Excel', onPressed: _exportingChannel ? null : () => _exportChannel('excel'), icon: Icon(Icons.table_chart_outlined, size: 20, color: AppColors.primary)),
            IconButton(tooltip: 'Export PDF', onPressed: _exportingChannel ? null : () => _exportChannel('pdf'), icon: Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.primary)),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(),
            icon: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryA55))
                : Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody(ReportChannelResult? result) {
    if (_loading && result == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
            ),
          ]),
        ),
      );
    }
    if (result == null || result.patients.isEmpty) {
      return const AppEmptyState(icon: Icons.bar_chart_rounded, message: 'No patients found for this channel — try adjusting your filters');
    }
    // DataTable shrink-wraps to its own content width by default — when
    // there are few rows/short values it leaves a large dead gap on the
    // right instead of filling the pane. ConstrainedBox(minWidth: ...)
    // forces it to at least fill the container, while still growing wider
    // (and scrolling) when there are more columns than fit.
    return Scrollbar(
      child: SingleChildScrollView(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Code')),
                  const DataColumn(label: Text('Name')),
                  const DataColumn(label: Text('Date / Time')),
                  const DataColumn(label: Text('Contact No')),
                  const DataColumn(label: Text('Age')),
                  DataColumn(label: Text(_isOtAppointment ? 'Assistant' : 'Doctor')),
                  const DataColumn(label: Text('Case Type')),
                  const DataColumn(label: Text('Receptionist')),
                  const DataColumn(label: Text('City')),
                  const DataColumn(label: Text('Fee')),
                ],
                rows: result.patients.map((p) {
                  return DataRow(cells: [
                    DataCell(Text(p.patientCode)),
                    DataCell(Text(p.fullName)),
                    DataCell(Text(p.appointmentDate)),
                    DataCell(Text(p.contactNo ?? '-')),
                    DataCell(Text(p.age != null ? '${p.age}' : '-')),
                    DataCell(Text(p.doctorName ?? '-')),
                    DataCell(Text(p.caseTypeLabel)),
                    DataCell(Text(p.receptionistName ?? '-')),
                    DataCell(Text(p.locationCity ?? '-')),
                    // Case fees shown for every row per web's channel.blade.php
                    // (unconditional money() column) — not gated on walk-in type.
                    DataCell(Text('₹${p.caseFee.toStringAsFixed(2)}')),
                  ]);
                }).toList(),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Collection banner ─────────────────────────────────────────────────────

class _CollectionBanner extends StatelessWidget {
  final double total;

  const _CollectionBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1F9D55), Color(0xFF27AE60)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: const Color(0xFF1F9D55).withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Collection (Walk-in)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Channel tile ────────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _ChannelTile({required this.icon, required this.iconColor, required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Container had no width constraint, so when this tile sits in a plain
    // Column (narrow layout, no Expanded/Row around it) it shrink-wrapped to
    // its own content width and centered — a small floating pill instead of
    // a full-width row item. SizedBox(width: double.infinity) forces it to
    // fill whatever the parent gives it either way.
    return SizedBox(
      width: double.infinity,
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: 14),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: iconColor)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ── Filter panel ────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final bool alwaysOpen;
  final bool isOpen;
  final ReportFilter filter;
  final ReportFilterOptions? filterOptions;
  final bool isOtAppointment;
  final VoidCallback onToggle;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final ValueChanged<int?> onReceptionistChanged;
  final ValueChanged<int?> onDoctorChanged;
  final ValueChanged<int?> onLocationChanged;
  final ValueChanged<int?> onCaseChanged;
  final String displayDateRange;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _FilterPanel({
    required this.alwaysOpen,
    required this.isOpen,
    required this.filter,
    required this.filterOptions,
    required this.isOtAppointment,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onReceptionistChanged,
    required this.onDoctorChanged,
    required this.onLocationChanged,
    required this.onCaseChanged,
    required this.displayDateRange,
    required this.errorMessage,
    required this.onRetry,
  });

  int get _activeCount {
    int c = 0;
    if (filter.dateRange.isNotEmpty) c++;
    if (filter.receptionistId != null) c++;
    if (filter.doctorId != null) c++;
    if (filter.locationId != null) c++;
    if (filter.caseId != null) c++;
    return c;
  }

  // Filter options ride on the same fetch as the report data — if that
  // fetch fails, filterOptions stays null forever and this panel used to
  // spin indefinitely with no way out. Show the real error + a retry
  // instead of an infinite loader.
  Widget _buildLoading() => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );

  Widget _buildError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 28, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            errorMessage ?? 'Failed to load filters',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primaryA10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final hasActive = !filter.isEmpty;
    final open = alwaysOpen || isOpen;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: alwaysOpen ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 18, color: hasActive ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasActive ? 'Filters Applied' : 'Report Filters',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: hasActive ? AppColors.primary : AppColors.textPrimary),
                    ),
                  ),
                  if (hasActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primaryA12, borderRadius: BorderRadius.circular(AppRadius.xl)),
                      child: Text('$_activeCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  if (!alwaysOpen) ...[
                    const SizedBox(width: 6),
                    Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
                  ],
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: AppColors.primaryA10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: filterOptions != null
                  ? _buildForm()
                  : (errorMessage != null ? _buildError() : _buildLoading()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    final opts = filterOptions;
    final doctorOrAssistantOptions = isOtAppointment ? (opts?.assistants ?? []) : (opts?.doctors ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FilterLabel('Date Range'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPickDateRange,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: Border.all(color: AppColors.primaryA10), borderRadius: BorderRadius.circular(10), color: AppColors.primaryA06),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(displayDateRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: filter.dateRange.isNotEmpty ? AppColors.primary : AppColors.textSecondary)),
                ),
                if (filter.dateRange.isNotEmpty)
                  GestureDetector(onTap: onClearDateRange, child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _FilterLabel('Receptionist'),
        const SizedBox(height: 6),
        _DropdownField<int>(hint: 'All Receptionists', value: filter.receptionistId, items: (opts?.receptionists ?? []).map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(), onChanged: onReceptionistChanged),
        const SizedBox(height: 14),
        _FilterLabel(isOtAppointment ? 'Assistant' : 'Doctor'),
        const SizedBox(height: 6),
        _DropdownField<int>(hint: isOtAppointment ? 'All Assistants' : 'All Doctors', value: filter.doctorId, items: doctorOrAssistantOptions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(), onChanged: onDoctorChanged),
        const SizedBox(height: 14),
        const _FilterLabel('City / Location'),
        const SizedBox(height: 6),
        _DropdownField<int>(hint: 'All Cities', value: filter.locationId, items: (opts?.locations ?? []).map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(), onChanged: onLocationChanged),
        const SizedBox(height: 14),
        const _FilterLabel('Case Type'),
        const SizedBox(height: 6),
        _DropdownField<int>(hint: 'All Case Types', value: filter.caseId, items: (opts?.caseTypes ?? []).map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(), onChanged: onCaseChanged),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: BorderSide(color: AppColors.primaryA10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3));
}

class _DropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({required this.hint, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: AppColors.primaryA10), borderRadius: BorderRadius.circular(10), color: AppColors.primaryA06),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          items: [
            DropdownMenuItem<T>(value: null, child: Text(hint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Pagination bar ─────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final ReportMeta meta;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PaginationBar({required this.meta, required this.loading, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (meta.hasPrev && !loading) ? onPrev : null,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: loading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : Text('${meta.currentPage} / ${meta.lastPage}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (meta.hasNext && !loading) ? onNext : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }
}
