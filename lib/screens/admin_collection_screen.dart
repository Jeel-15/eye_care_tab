import 'package:flutter/material.dart';
import '../widgets/app_refresh_indicator.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/dashboard_models.dart';
import '../services/dashboard_service.dart';
import '../utils/app_route.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';
import '../utils/app_date_picker.dart';

/// Web/API parity: Hospital Admin's dashboard "Total Collection" card drill-
/// down — `AdminCollectionController::index` / `GET /dashboard/collection`.
/// One row per receptionist (patients seen + fees collected) for the
/// selected date range, defaulting to today.
///
/// Redesigned 2026-09-30 — the previous version (one huge gradient hero
/// card + a `Wrap` of big white cards) was a one-off layout unlike anything
/// else in this app and wasted most of the screen on padding. Rebuilt onto
/// this app's own normal "single full-page table" convention
/// (`OtPanelHeader` + `ScaledDataTable`, the same shape every other list
/// screen in this app already uses — OT Appointments, Patients, etc.) with
/// a slim single-row stat strip instead of 3 separate big cards.
class AdminCollectionScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const AdminCollectionScreen({
    super.key,
    required this.user,
    required this.hospital,
  });

  @override
  State<AdminCollectionScreen> createState() => _AdminCollectionScreenState();
}

class _AdminCollectionScreenState extends State<AdminCollectionScreen> {
  CollectionSummary? _data;
  bool _loading = true;
  String? _error;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();

  String get _symbol => widget.hospital.currencySymbol;

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
      final data = await DashboardService.instance.fetchCollectionSummary(
        startDate: toIsoDate(_start),
        endDate: toIsoDate(_end),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked == null) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
    _load();
  }

  String get _rangeLabel {
    final s = toIsoDate(_start);
    final e = toIsoDate(_end);
    return s == e ? (s == toIsoDate(DateTime.now()) ? 'Today' : s) : '$s → $e';
  }

  static const _columns = [
    ScaledTableColumn('RECEPTIONIST', 200),
    ScaledTableColumn('PATIENTS', 90, headerAlign: TextAlign.right),
    ScaledTableColumn('COLLECTION', 120, headerAlign: TextAlign.right),
    ScaledTableColumn('', 90, headerAlign: TextAlign.right),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Total Collection',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _pickDateRange,
                    tooltip: 'Change date range',
                    icon: Icon(
                      Icons.date_range_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppSkeletonList(count: 6, itemHeight: 44)
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
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
                              icon: Icons.account_balance_wallet_rounded,
                              title: 'Reception-wise OPD Collection',
                              subtitle: _rangeLabel,
                            ),
                            _statStrip(),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            Expanded(
                              child: AppRefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: _load,
                                child: ListView(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  children: [
                                    ScaledDataTable(
                                      columns: _columns,
                                      rows: (_data?.rows ?? const [])
                                          .map(_rowCells)
                                          .toList(),
                                      emptyMessage:
                                          'No collection recorded for this range.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statStrip() {
    final b = _data?.breakdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: _stat(
              'Grand Total',
              formatMoney(_data?.grandTotal ?? 0, _symbol),
              AppColors.primary,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _stat(
              'OPD',
              formatMoney(b?.opd ?? 0, _symbol),
              AppColors.blue,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _stat(
              'OT Net',
              formatMoney(b?.otNet ?? 0, _symbol),
              AppColors.purple,
              hint:
                  '${formatMoney(b?.otCollected ?? 0, _symbol)} paid − ${formatMoney(b?.otRefunded ?? 0, _symbol)} refund',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
    width: 1,
    height: 34,
    color: AppColors.primaryA08,
    margin: const EdgeInsets.symmetric(horizontal: 14),
  );

  Widget _stat(String label, String value, Color color, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  List<Widget> _rowCells(CollectionRow r) {
    return [
      Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            child: Text(
              r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              r.name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      Text(
        '${r.count}',
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        formatMoney(r.total, _symbol),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.green,
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            appRoute(
              AdminCollectionDetailScreen(
                user: widget.user,
                hospital: widget.hospital,
                receptionId: r.id,
                receptionName: r.name,
                start: _start,
                end: _end,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Per-receptionist "Registered Patients" table —
/// `AdminCollectionController::show` / `GET /dashboard/collection/{id}`.
/// Redesigned 2026-09-30 alongside [AdminCollectionScreen] — same
/// `OtPanelHeader` + `ScaledDataTable` convention, replacing the previous
/// one-off New/Old/Other bucket cards (which had no web equivalent at all).
class AdminCollectionDetailScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final int receptionId;
  final String receptionName;
  final DateTime start;
  final DateTime end;

  const AdminCollectionDetailScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.receptionId,
    required this.receptionName,
    required this.start,
    required this.end,
  });

  @override
  State<AdminCollectionDetailScreen> createState() =>
      _AdminCollectionDetailScreenState();
}

class _AdminCollectionDetailScreenState
    extends State<AdminCollectionDetailScreen> {
  CollectionDetail? _data;
  bool _loading = true;
  String? _error;
  bool _exporting = false;
  // Web pull 2026-09-30 — the detail page has its own Date Range picker +
  // "Today" reset (`admin_collection_show.blade.php`'s `.acs-hero-tools`),
  // independent of whatever range the index screen was on. Was previously a
  // one-time `widget.start`/`widget.end` with no way to change it here.
  late DateTime _start = widget.start;
  late DateTime _end = widget.end;

  String get _symbol => widget.hospital.currencySymbol;

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
      final data = await DashboardService.instance.fetchCollectionDetail(
        widget.receptionId,
        startDate: toIsoDate(_start),
        endDate: toIsoDate(_end),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked == null) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
    _load();
  }

  void _resetToday() {
    setState(() {
      _start = DateTime.now();
      _end = DateTime.now();
    });
    _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await DashboardService.instance.downloadCollectionExport(
        widget.receptionId,
        startDate: toIsoDate(_start),
        endDate: toIsoDate(_end),
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

  bool get _isSingleDay => toIsoDate(_start) == toIsoDate(_end);

  String get _rangeLabel {
    final s = toIsoDate(_start);
    final e = toIsoDate(_end);
    return s == e ? (s == toIsoDate(DateTime.now()) ? 'Today' : s) : '$s → $e';
  }

  static const _columns = [
    ScaledTableColumn('#', 28, headerAlign: TextAlign.center),
    ScaledTableColumn('PATIENT', 160),
    ScaledTableColumn('AGE/GENDER', 90),
    ScaledTableColumn('CASE TYPE', 110),
    ScaledTableColumn('DOCTOR', 110),
    ScaledTableColumn('STATUS', 130),
    ScaledTableColumn('FEE', 90, headerAlign: TextAlign.right),
  ];

  Color _toneColor(String tone) => switch (tone) {
    'warning' => AppColors.orange,
    'info' => AppColors.blue,
    'purple' => AppColors.purple,
    'teal' => AppColors.teal,
    'success' => AppColors.green,
    'danger' => AppColors.red,
    'primary' => AppColors.primary,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.receptionName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppSkeletonList(count: 6, itemHeight: 44)
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
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
                              icon: Icons.badge_rounded,
                              title: 'Registered Patients',
                              subtitle:
                                  '${widget.receptionName}  ·  $_rangeLabel',
                              actions: [
                                IconButton(
                                  onPressed: _pickDateRange,
                                  tooltip: 'Change date range',
                                  icon: const Icon(
                                    Icons.date_range_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _resetToday,
                                  tooltip: 'Back to today',
                                  icon: const Icon(
                                    Icons.today_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                _exporting
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: (_data?.count ?? 0) == 0
                                            ? null
                                            : _export,
                                        tooltip: 'Export',
                                        icon: Icon(
                                          Icons.file_download_outlined,
                                          color: (_data?.count ?? 0) == 0
                                              ? Colors.white38
                                              : Colors.white,
                                          size: 20,
                                        ),
                                      ),
                              ],
                            ),
                            // Web pull 2026-09-30 — the previous small header pill
                            // buried the actual collected amount; web's own hero
                            // (`.acs-hero-value`, 2.3rem) makes it the single most
                            // prominent thing on the page. This strip is that same
                            // emphasis, sized for this app's panel chrome.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                              color: AppColors.background,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TOTAL COLLECTED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMoney(_data?.total ?? 0, _symbol),
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_data?.count ?? 0} ${(_data?.count ?? 0) == 1 ? 'patient' : 'patients'}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            Expanded(
                              child: AppRefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: _load,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  children: [
                                    ScaledDataTable(
                                      columns: _columns,
                                      rows: List.generate(
                                        (_data?.patients ?? const []).length,
                                        (i) => _rowCells(_data!.patients[i], i),
                                      ),
                                      emptyMessage:
                                          'No patients registered by ${widget.receptionName} for $_rangeLabel.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rowCells(CollectionDetailPatient p, int i) {
    final tone = _toneColor(p.stageTone);
    return [
      Text(
        '${i + 1}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.name.isNotEmpty ? p.name : '—',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            [
              p.patientCode,
              if (!_isSingleDay && p.appointmentDate != null)
                formatPlainDate(p.appointmentDate),
            ].whereType<String>().join(' · '),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      Text(
        '${p.age ?? '—'}${p.gender != null ? ' / ${p.gender![0].toUpperCase()}' : ''}',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.caseType ?? '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        p.doctor != null ? 'Dr. ${p.doctor}' : '—',
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              p.stageLabel,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
          if (p.stageSub != null && p.stageSub!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                p.stageSub!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
      Text(
        formatMoney(p.caseFee, _symbol),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    ];
  }
}
