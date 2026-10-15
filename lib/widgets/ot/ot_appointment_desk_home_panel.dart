import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ot_appointment_models.dart';
import '../../screens/ot_appointment_list_screen.dart';
import '../../services/ot_appointment_service.dart';
import '../../services/permission_service.dart';
import '../../constants/permissions.dart';
import '../../utils/date_format.dart';
import '../../utils/refreshable.dart';
import '../scaled_data_table.dart';
import '../status_badge.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';

/// New `ot_appointment` role's own home desk (web pull 2026-10-07 —
/// `ot-appointment-panel.blade.php`). Same two tabs as the dedicated full
/// screen: "OT Appointments" (today's still-booked/pending) and "Completed"
/// (today's walk-in-converted patients, with their live workflow stage).
class OtAppointmentDeskHomePanel extends StatefulWidget {
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;

  const OtAppointmentDeskHomePanel({super.key, required this.onOpenFullPage, this.requestedTab, this.onDeskTab, this.onCounts});

  @override
  State<OtAppointmentDeskHomePanel> createState() => _OtAppointmentDeskHomePanelState();
}

class _OtAppointmentDeskHomePanelState extends State<OtAppointmentDeskHomePanel> implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'OT Appointments'),
    (key: 'history', label: 'Completed'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtAppointmentItem>> _items = {};
  final Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    if (_tabDefs.any((t) => t.key == widget.requestedTab)) _activeTab = widget.requestedTab!;
    _load();
  }

  @override
  void didUpdateWidget(covariant OtAppointmentDeskHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.requestedTab;
    if (next != null && next != _activeTab && _tabDefs.any((t) => t.key == next)) setState(() => _activeTab = next);
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final today = toIsoDate(DateTime.now());
      final results = await Future.wait([
        OtAppointmentService.instance.list(tab: 'booked', fromDate: today, toDate: today, perPage: 8),
        OtAppointmentService.instance.list(tab: 'completed', fromDate: today, toDate: today, perPage: 8),
      ]);
      if (!mounted) return;
      setState(() {
        _items['queue'] = results[0].items;
        _items['history'] = results[1].items;
        _counts['queue'] = results[0].bookedCount;
        _counts['history'] = results[1].completedCount;
        _loading = false;
      });
      widget.onCounts?.call(Map<String, int>.from(_counts));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  static const _columns = [
    ScaledTableColumn('APPT #', 90),
    ScaledTableColumn('PATIENT', 150, grow: true),
    ScaledTableColumn('MOBILE', 110),
    ScaledTableColumn('DOCTOR', 130, grow: true),
    ScaledTableColumn('STATUS', 150),
    ScaledTableColumn('ACTION', 90, hug: true),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    return DeskHomePanel(
      icon: _activeTab == 'history' ? Icons.check_circle_outline_rounded : Icons.event_note_rounded,
      title: _activeTab == 'history' ? 'Completed' : 'OT Appointments',
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
      rows: items.map(_cells).toList(),
      emptyMessage: _activeTab == 'history' ? 'No appointments completed today.' : 'No OT appointments today.',
    );
  }

  List<Widget> _cells(OtAppointmentItem item) {
    final showEdit = _activeTab == 'queue' && PermissionService.instance.can(Perm.otAppointmentEdit);
    return [
      Text(item.appointmentNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Text(item.fullName.isNotEmpty ? item.fullName : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkNavy)),
      Text(item.mobileNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(item.doctor?.name ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: StatusBadge.otAppointmentStage(item.stageBadgeClass, item.stageLabel)),
          if ((item.stageSub ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(item.stageSub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary))),
        ]),
      ),
      showEdit
          ? TableLabelAction(label: 'Edit', icon: Icons.edit_outlined, onTap: () => openOtAppointmentEditDialog(context, item, onSaved: _load))
          : const Text('-', style: TextStyle(fontSize: 13, color: AppColors.textDisabled)),
    ];
  }
}
