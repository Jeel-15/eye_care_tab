import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ot_booking_models.dart';
import '../../screens/ot_counsellor_dashboard_screen.dart';
import '../../services/ot_counsellor_service.dart';
import '../../utils/currency_format.dart';
import '../../utils/refreshable.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';

/// Counselling-role home desk. Same three lists as web's
/// `counselling-panel.blade.php`: awaiting, counselled, and payment status.
class CounsellingDeskHomePanel extends StatefulWidget {
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;

  const CounsellingDeskHomePanel({super.key, required this.onOpenFullPage, this.requestedTab, this.onDeskTab, this.onCounts});

  @override
  State<CounsellingDeskHomePanel> createState() => _CounsellingDeskHomePanelState();
}

class _CounsellingDeskHomePanelState extends State<CounsellingDeskHomePanel> implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'Awaiting Counselling'),
    (key: 'history', label: 'Counselled Patients'),
    (key: 'payments', label: 'Payment Status'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtBookingSummary>> _items = {};
  final Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    if (widget.requestedTab != null) _activeTab = widget.requestedTab!;
    _load();
  }

  @override
  void didUpdateWidget(covariant CounsellingDeskHomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.requestedTab;
    if (next != null && next != _activeTab) setState(() => _activeTab = next);
  }

  @override
  Future<void> refreshSilently() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        OtCounsellorService.instance.fetchBookings(filter: 'queue', perPage: 8),
        OtCounsellorService.instance.fetchBookings(filter: 'history', perPage: 8),
        OtCounsellorService.instance.fetchBookings(filter: 'payments', perPage: 8),
      ]);
      if (!mounted) return;
      setState(() {
        _items['queue'] = results[0].items;
        _items['history'] = results[1].items;
        _items['payments'] = results[2].filter == 'payments' ? results[2].items : const [];
        _counts['queue'] = results[0].meta.total;
        _counts['history'] = results[1].meta.total;
        _counts['payments'] = results[2].filter == 'payments' ? results[2].meta.total : 0;
        _loading = false;
      });
      widget.onCounts?.call(Map<String, int>.from(_counts));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  static const _caseColumns = [
    ScaledTableColumn('PATIENT NAME', 170, grow: true),
    ScaledTableColumn('PHONE', 110),
    ScaledTableColumn('EYE', 80),
    ScaledTableColumn('SURGERY TYPE', 140, grow: true),
    ScaledTableColumn('STATUS', 160),
    ScaledTableColumn('ACTION', 180, hug: true),
  ];

  static const _paymentColumns = [
    ScaledTableColumn('PATIENT NAME', 180, grow: true),
    ScaledTableColumn('PHONE', 120),
    ScaledTableColumn('PACKAGE AMOUNT', 140),
    ScaledTableColumn('STATUS', 120),
  ];

  ({String label, Color color}) _status(OtBookingSummary item) {
    if (_activeTab == 'payments') {
      return (label: 'Paid', color: item.otStatus == OtStatus.paid ? AppColors.orange : AppColors.green);
    }
    if (_activeTab == 'queue' && item.otStatus == OtStatus.surgeryRecommended) {
      return (label: 'Surgery Recommended', color: AppColors.orange);
    }
    if (_activeTab == 'queue') return (label: 'Booked', color: AppColors.blue);
    return (label: OtStatus.label(item.otStatus), color: AppColors.green);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    final payments = _activeTab == 'payments';
    return DeskHomePanel(
      icon: payments ? Icons.shield_outlined : Icons.hourglass_bottom_rounded,
      title: switch (_activeTab) {
        'history' => 'Counselled Patients',
        'payments' => 'Payment Status',
        _ => 'Awaiting Counselling',
      },
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
      columns: payments ? _paymentColumns : _caseColumns,
      rows: items.map(payments ? _paymentCells : _caseCells).toList(),
      emptyMessage: switch (_activeTab) {
        'history' => 'No counselled patients yet.',
        'payments' => 'No bookings paid yet.',
        _ => 'No bookings awaiting counselling.',
      },
    );
  }

  List<Widget> _caseCells(OtBookingSummary item) {
    final status = _status(item);
    return [
      deskPatientNameCell(name: item.patient?.fullName ?? 'Patient', subLine: item.patient?.patientCode, avatarColors: const [AppColors.orange, AppColors.orange]),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(item.eye ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text(item.otType ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: deskStatusPill(status.label, status.color)),
      ActionCluster(children: [
        deskTableActionBtn(icon: Icons.visibility_outlined, label: 'View', onTap: () => showOtCounsellorBookingView(context, item)),
        if (_activeTab == 'queue')
          deskTableActionBtn(icon: Icons.forum_rounded, label: 'Counsel', color: AppColors.primary, onTap: () => openOtCounsellingForm(context, item, onBillingSent: _load)),
      ]),
    ];
  }

  List<Widget> _paymentCells(OtBookingSummary item) {
    final status = _status(item);
    return [
      deskPatientNameCell(name: item.patient?.fullName ?? 'Patient', subLine: item.patient?.patientCode, avatarColors: const [AppColors.orange, AppColors.orange]),
      Text(item.patient?.contactNo ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      Text('${currentCurrencySymbol()}${(item.packageAmount ?? 0).toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      Align(alignment: Alignment.centerLeft, child: deskStatusPill(status.label, status.color)),
    ];
  }
}
