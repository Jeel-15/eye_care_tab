import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../models/ot_accountant_models.dart';
import '../../models/ot_booking_models.dart';
import '../../models/ot_ward_models.dart';
import '../../screens/ot_ward_queue_screen.dart';
import '../../services/ot_ward_service.dart';
import '../../utils/refreshable.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';
import 'ot_ward_detail_dialog.dart';

/// Web's exact per-status tone for this panel
/// (`ward-panel.blade.php`'s `acc-tone-*` classes) — mapped onto this app's
/// own [AppColors] tokens: amber→orange, blue→blue, purple→purple,
/// navy→primary, green→green, grey→textSecondary.
(Color, String) _wardStatusStyle(String otStatus) => switch (otStatus) {
      OtStatus.paymentVerified => (AppColors.orange, 'Awaiting Ward Entry'),
      OtStatus.inWard => (AppColors.blue, 'In Ward'),
      OtStatus.dilated => (AppColors.purple, 'Dilated'),
      OtStatus.ready => (AppColors.primary, 'Ready for OT'),
      OtStatus.operated => (AppColors.green, 'Operated'),
      OtStatus.discharged => (AppColors.textSecondary, 'Discharged'),
      _ => (AppColors.textSecondary, OtStatus.label(otStatus)),
    };

/// Dashboard-home compact desk panel for the Ward Management role — mirrors
/// web's `ward-panel.blade.php` shown directly under the existing "Pending
/// Patient" stat card. Reuses `OtWardService.fetchBookings()` (the same call
/// `OtWardQueueScreen`'s own Ward Entry Queue table uses) plus that screen's
/// own `openOtWardEntryPane()` entry point and `showOtWardBookingDetail`, so every
/// button here runs the exact same code path as the dedicated Ward Entry
/// Queue screen.
class WardDeskHomePanel extends StatefulWidget {
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;

  const WardDeskHomePanel({super.key, required this.onOpenFullPage, this.requestedTab, this.onDeskTab, this.onCounts});

  @override
  State<WardDeskHomePanel> createState() => _WardDeskHomePanelState();
}

class _WardDeskHomePanelState extends State<WardDeskHomePanel> implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'Ward Entry Queue'),
    (key: 'history', label: 'Ward History'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtBookingSummary>> _items = {};
  final Map<String, int> _counts = {};
  Timer? _dilateTicker;

  @override
  void initState() {
    super.initState();
    if (widget.requestedTab != null) _activeTab = widget.requestedTab!;
    _load();
    // Live mm:ss Dilate countdown — matches web's own 1s setInterval on this
    // same panel (ward-panel.blade.php), and the dedicated Ward Entry Queue
    // screen's own ticker. Cheap: just a rebuild, no refetch.
    _dilateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant WardDeskHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.requestedTab;
    if (next != null && next != _activeTab) setState(() => _activeTab = next);
  }

  @override
  void dispose() {
    _dilateTicker?.cancel();
    super.dispose();
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        OtWardService.instance.fetchBookings(filter: 'queue', perPage: 8),
        OtWardService.instance.fetchBookings(filter: 'history', perPage: 8),
      ]);
      if (!mounted) return;
      setState(() {
        _items['queue'] = results[0].items;
        _items['history'] = results[1].items;
        _counts['queue'] = results[0].meta.total;
        _counts['history'] = results[1].meta.total;
        _loading = false;
      });
      widget.onCounts?.call(Map<String, int>.from(_counts));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  // Web parity (web pull 2026-09-30) — shared with the full Ward Entry
  // Queue screen (see `showOtWardBookingDetail`) so both surfaces always
  // show the same rich detail instead of drifting apart.
  void _showBookingView(OtBookingSummary item) => showOtWardBookingDetail(context, item);

  Future<void> _openVitals(OtBookingSummary item) async {
    await openOtWardEntryPane(context, bookingId: item.id, patientName: item.patient?.fullName ?? 'Patient', initialOtStatus: item.otStatus);
    _load();
  }

  static const _columns = [
    ScaledTableColumn('PATIENT NAME', 170, grow: true),
    ScaledTableColumn('PHONE', 110),
    ScaledTableColumn('STATUS', 140),
    ScaledTableColumn('DILATE', 110),
    ScaledTableColumn('PAYMENT', 120),
    ScaledTableColumn('ACTION', 190, hug: true),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    return DeskHomePanel(
      icon: Icons.bed_rounded,
      title: _activeTab == 'history' ? 'Ward History' : 'Ward Entry Queue',
      totalCount: _counts[_activeTab] ?? 0,
      onOpenFullPage: widget.onOpenFullPage,
      tabs: _tabDefs.map((t) => DeskHomePanelTab(key: t.key, label: t.label, count: _counts[t.key] ?? 0)).toList(),
      activeTab: _activeTab,
      onTabChanged: (t) {
        setState(() => _activeTab = t);
        widget.onDeskTab?.call(t);
      },
      loading: _loading,
      error: _error,
      onRetry: _load,
      columns: _columns,
      rows: items.map(_rowCells).toList(),
      emptyMessage: _activeTab == 'history' ? 'No ward history yet today.' : 'No records available for ward workflow.',
    );
  }

  List<Widget> _rowCells(OtBookingSummary item) {
    final ps = item.paymentStatus;
    final (statusColor, statusLabel) = _wardStatusStyle(item.otStatus);
    final paymentLabel = switch (ps) { 'paid' => 'Paid', 'partially_paid' => 'Partially Paid', _ => 'Pending' };
    final paymentColor = paymentStatusColor(ps ?? 'pending');
    return [
      deskPatientNameCell(name: item.patient?.fullName ?? 'Patient', subLine: item.patient?.patientCode),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      deskStatusPill(statusLabel.toUpperCase(), statusColor),
      _dilateCell(item),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        deskStatusPill(paymentLabel.toUpperCase(), paymentColor),
        if (ps == 'partially_paid' && item.remainingBalance != null)
          Padding(padding: const EdgeInsets.only(top: 2), child: Text('Balance: ${item.remainingBalance!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
      ]),
      ActionCluster(children: [
        deskTableActionBtn(icon: Icons.visibility_outlined, label: 'View', onTap: () => _showBookingView(item)),
        if (_activeTab != 'history')
          deskTableActionBtn(icon: Icons.monitor_heart_outlined, label: 'Vitals & Eye Drops', color: AppColors.primary, onTap: () => _openVitals(item)),
      ]),
    ];
  }

  Widget _dilateCell(OtBookingSummary item) {
    final unlockAt = _wardPanelDilateUnlockAt(item);
    if (unlockAt == null) {
      return const Text('—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
    }
    final ready = !unlockAt.isAfter(DateTime.now());
    final color = ready ? AppColors.green : AppColors.orange;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Text(_wardPanelDilateCountdownLabel(unlockAt), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// Web parity (`ward.blade.php`'s Dilate column, also shown on this same
// panel on web — `ward-panel.blade.php`) — the latest logged dose with
// dilate='Yes' and a dilation_time set, resolved to the actual wall-clock
// moment it unlocks. Duplicated from ot_ward_queue_screen.dart's
// file-private helpers of the same name/logic (only the 2nd caller so far —
// worth factoring out to a shared file if a 3rd appears).
DateTime? _wardPanelDilateUnlockAt(OtBookingSummary item) {
  OtEyeDropEntry? latest;
  DateTime? latestAt;
  for (final d in item.dilationEntries) {
    if (d.dilate != 'Yes' || d.dilationTime == null) continue;
    final at = DateTime.tryParse(d.administeredAt ?? '');
    if (at == null) continue;
    if (latestAt == null || at.isAfter(latestAt)) {
      latest = d;
      latestAt = at;
    }
  }
  if (latest == null || latestAt == null) return null;
  return latestAt.add(Duration(minutes: latest.dilationTime!));
}

String _wardPanelDilateCountdownLabel(DateTime unlockAt) {
  final diff = unlockAt.difference(DateTime.now());
  if (diff.isNegative) return 'Ready';
  final m = diff.inMinutes;
  final s = diff.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
