import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/permissions.dart';
import '../../models/auth_models.dart';
import '../../models/ot_accountant_models.dart';
import '../../models/ot_booking_models.dart';
import '../../screens/ot_assistant_dashboard_screen.dart';
import '../../services/ot_assistant_service.dart';
import '../../services/permission_service.dart';
import '../../utils/currency_format.dart';
import '../../utils/date_format.dart';
import '../../utils/refreshable.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';
import 'ot_assistant_detail_dialog.dart';

/// Web's exact per-status tone for this panel (`ot-assistant-panel.blade
/// .php`'s `acc-tone-*` classes) — mapped onto this app's own [AppColors]
/// tokens: navy→primary, green→green, grey→textSecondary.
(Color, String) _assistantStatusStyle(String otStatus) => switch (otStatus) {
      OtStatus.ready => (AppColors.primary, 'Ready for OT'),
      OtStatus.operated => (AppColors.green, 'Operated'),
      OtStatus.discharged => (AppColors.textSecondary, 'Discharged'),
      _ => (AppColors.textSecondary, OtStatus.label(otStatus)),
    };

/// Dashboard-home compact desk panel for the OT Assistant role — mirrors
/// web's `ot-assistant-panel.blade.php` shown directly under the existing
/// "Pending Patient" stat card. Reuses `OtAssistantService.fetchBookings()`
/// (the same call `OtAssistantDashboardScreen`'s own Surgery Queue table
/// uses) plus that screen's own `openOtSurgeryRecordingPane()` entry point
/// and `showOtAssistantBookingDetail`, so every button here runs the exact same code
/// path as the dedicated Surgery Queue screen. The Surgeon column (and
/// "see all" scoping) mirrors that same screen's own `_seeAll` check
/// (`isSuper || role.slug == 'hospital_admin'`) — this app's dashboard/OT
/// Assistant desk is always the logged-in user's own view otherwise, so
/// there is no separate "assigned to me only" fetch to add here.
class AssistantDeskHomePanel extends StatefulWidget {
  final UserInfo user;
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;
  final int? assistantId;
  final String? viewingName;
  final VoidCallback? onBackToMine;

  const AssistantDeskHomePanel({
    super.key,
    required this.user,
    required this.onOpenFullPage,
    this.requestedTab,
    this.onDeskTab,
    this.onCounts,
    this.assistantId,
    this.viewingName,
    this.onBackToMine,
  });

  @override
  State<AssistantDeskHomePanel> createState() => _AssistantDeskHomePanelState();
}

class _AssistantDeskHomePanelState extends State<AssistantDeskHomePanel> implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'Ready for Surgery'),
    (key: 'history', label: 'Surgery History'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtBookingSummary>> _items = {};
  final Map<String, int> _counts = {};

  bool get _canSurgery => PermissionService.instance.can(Perm.otSurgeryRecord);
  bool get _seeAll => (widget.user.role?.isSuper ?? false) || widget.user.role?.slug == 'hospital_admin';

  @override
  void initState() {
    super.initState();
    if (widget.requestedTab != null) _activeTab = widget.requestedTab!;
    _load();
  }

  @override
  void didUpdateWidget(covariant AssistantDeskHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.requestedTab;
    if (next != null && next != _activeTab) setState(() => _activeTab = next);
    if (widget.assistantId != oldWidget.assistantId) _load();
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final assistantId = widget.assistantId;
      final results = await Future.wait([
        OtAssistantService.instance.fetchBookings(filter: 'queue', assistantId: assistantId, perPage: 8),
        OtAssistantService.instance.fetchBookings(filter: 'history', assistantId: assistantId, perPage: 8),
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

  // Web parity (web pull 2026-09-30) — shared with the full Surgery Queue
  // screen (see `showOtAssistantBookingDetail`) so both surfaces always
  // show the same rich detail instead of drifting apart.
  void _viewDetails(OtBookingSummary item) => showOtAssistantBookingDetail(context, item);

  Future<void> _operate(OtBookingSummary item) async {
    await openOtSurgeryRecordingPane(context, bookingId: item.id, patientName: item.patient?.fullName ?? 'Patient', onSaved: _load);
  }

  List<ScaledTableColumn> get _columns => [
        const ScaledTableColumn('PATIENT NAME', 160, grow: true),
        if (_seeAll) const ScaledTableColumn('SURGEON', 120, grow: true),
        if (_activeTab == 'history') const ScaledTableColumn('OT DATE', 100),
        const ScaledTableColumn('SURGERY TYPE', 130, grow: true),
        const ScaledTableColumn('PACKAGE', 110),
        const ScaledTableColumn('PAYMENT', 110),
        const ScaledTableColumn('STATUS', 110),
        const ScaledTableColumn('ACTION', 150, hug: true),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    final viewing = widget.viewingName;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (viewing != null && viewing.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text("Viewing $viewing's patients — you can operate them", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            TextButton(onPressed: widget.onBackToMine, child: const Text('Back to My Patients')),
          ]),
        ),
      DeskHomePanel(
      icon: Icons.handyman_rounded,
      title: _activeTab == 'history' ? 'Surgery History' : 'Ready for Surgery',
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
      emptyMessage: _activeTab == 'history' ? 'No surgery history yet.' : 'No bookings ready for surgery.',
    ),
    ]);
  }

  List<Widget> _rowCells(OtBookingSummary item) {
    final ps = item.paymentStatus;
    final paymentLabel = switch (ps) { 'paid' => 'Paid', 'partially_paid' => 'Partially Paid', _ => 'Pending' };
    final paymentColor = paymentStatusColor(ps ?? 'pending');
    final (statusColor, statusLabel) = _assistantStatusStyle(item.otStatus);
    return [
      // Web parity note: this panel's second line is the patient's contact
      // number, not the patient code — differs from the other 3 desk panels.
      deskPatientNameCell(name: item.patient?.fullName ?? 'Patient', subLine: item.patient?.contactNo, avatarColors: const [AppColors.purple, AppColors.blue]),
      if (_seeAll) Text(item.otDoctor != null ? 'Dr. ${item.otDoctor!.name}' : '-', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      if (_activeTab == 'history') Text(formatPlainDate(item.surgeryDate) ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(item.otType ?? '—', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text('${currentCurrencySymbol()}${(item.packageAmount ?? 0).toStringAsFixed(0)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      deskStatusPill(paymentLabel.toUpperCase(), paymentColor),
      deskStatusPill(statusLabel.toUpperCase(), statusColor),
      ActionCluster(children: [
        deskTableActionBtn(icon: Icons.visibility_outlined, label: 'View', onTap: () => _viewDetails(item)),
        if (_activeTab != 'history' && _canSurgery)
          deskTableActionBtn(icon: Icons.local_hospital_outlined, label: 'Operate', color: AppColors.primary, onTap: () => _operate(item)),
      ]),
    ];
  }
}
