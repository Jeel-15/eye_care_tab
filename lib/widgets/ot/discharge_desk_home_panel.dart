import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radius.dart';
import '../../constants/permissions.dart';
import '../../models/ot_booking_models.dart';
import '../../models/ot_discharge_models.dart';
import '../../screens/ot_discharge_dashboard_screen.dart';
import '../../services/ot_discharge_service.dart';
import '../../services/permission_service.dart';
import '../../utils/refreshable.dart';
import '../app_animations.dart';
import '../scaled_data_table.dart';
import '../table_row_action.dart';
import 'desk_home_panel.dart';
import 'ot_discharge_detail_dialog.dart';

/// Dashboard-home compact desk panel for the Discharge Counter role —
/// mirrors web's `discharge-panel.blade.php` shown directly under the
/// existing "Pending Patient" stat card. Reuses
/// `OtDischargeService.fetchBookings()/generateInvoice()/printDocument()`
/// (the same calls `OtDischargeDashboardScreen`'s own Billing Desk table
/// uses) plus that screen's own `showOtGenerateInvoiceDialog()`/
/// `askOtDischargeCertificateRestDays()`/`otDischargeDocPrintedAt()`/
/// `otDischargeStatusCell()` entry points and `showOtDischargeBookingDetail`,
/// so every button and status badge here runs the exact same code as the
/// dedicated Billing Desk screen.
class DischargeDeskHomePanel extends StatefulWidget {
  final VoidCallback onOpenFullPage;
  final String? requestedTab;
  final ValueChanged<String>? onDeskTab;
  final ValueChanged<Map<String, int>>? onCounts;

  const DischargeDeskHomePanel({super.key, required this.onOpenFullPage, this.requestedTab, this.onDeskTab, this.onCounts});

  @override
  State<DischargeDeskHomePanel> createState() => _DischargeDeskHomePanelState();
}

class _DischargeDeskHomePanelState extends State<DischargeDeskHomePanel> implements Refreshable {
  static const _tabDefs = [
    (key: 'queue', label: 'Discharge & Invoice Queue'),
    (key: 'history', label: 'Discharged Patients'),
  ];

  bool _loading = true;
  String? _error;
  String _activeTab = 'queue';
  final Map<String, List<OtBookingSummary>> _items = {};
  final Map<String, int> _counts = {};

  int? _busyId;
  OtDischargeDocType? _busyType;

  bool get _canGenerateInvoice => PermissionService.instance.can(Perm.otBillingManage);
  bool get _canBillPrint => PermissionService.instance.can(Perm.otBillPrint);
  bool get _canDischargePrint => PermissionService.instance.can(Perm.otDischargeGenerate);
  bool get _canCertificatePrint => PermissionService.instance.can(Perm.otCertificatePrint);

  @override
  void initState() {
    super.initState();
    if (widget.requestedTab != null) _activeTab = widget.requestedTab!;
    _load();
  }

  @override
  void didUpdateWidget(covariant DischargeDeskHomePanel oldWidget) {
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
        OtDischargeService.instance.fetchBookings(filter: 'queue', perPage: 8),
        OtDischargeService.instance.fetchBookings(filter: 'history', perPage: 8),
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

  // Web parity (web pull 2026-09-30) — shared with the full Billing Desk
  // screen (see `showOtDischargeBookingDetail`) so both surfaces always
  // show the same rich detail instead of drifting apart.
  void _showBookingView(OtBookingSummary item) => showOtDischargeBookingDetail(context, item);

  Future<void> _generateInvoice(OtBookingSummary item) async {
    final followUpDate = await showOtGenerateInvoiceDialog(context);
    if (followUpDate == null) return;
    setState(() => _busyId = item.id);
    try {
      final r = await OtDischargeService.instance.generateInvoice(item.id, followUpDate: followUpDate);
      if (!mounted) return;
      showAppSnackBar(context, 'Invoice ${r.invoiceNumber} generated. Print all 3 documents to complete discharge.', isSuccess: true);
      await _load();
      if (mounted) await _print(item.id, OtDischargeDocType.invoice);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _print(int bookingId, OtDischargeDocType type) async {
    int? restDays;
    if (type == OtDischargeDocType.certificate) {
      restDays = await askOtDischargeCertificateRestDays(context);
      if (restDays == null) return;
    }
    setState(() { _busyId = bookingId; _busyType = type; });
    try {
      await OtDischargeService.instance.printDocument(bookingId, type, restDays: restDays);
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() { _busyId = null; _busyType = null; });
    }
  }

  static const _columns = [
    ScaledTableColumn('PATIENT', 170, grow: true),
    ScaledTableColumn('STATUS', 120),
    ScaledTableColumn('INVOICE', 100),
    ScaledTableColumn('ACTIONS', 260, hug: true),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items[_activeTab] ?? const [];
    return DeskHomePanel(
      icon: Icons.receipt_long_rounded,
      title: _activeTab == 'history' ? 'Discharged Patients' : 'Discharge & Invoice Queue',
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
      emptyMessage: _activeTab == 'history' ? 'No patients discharged today.' : 'No records available for billing.',
    );
  }

  List<Widget> _rowCells(OtBookingSummary item) {
    final hasInvoice = item.hasInvoice ?? false;
    return [
      deskPatientNameCell(name: item.patient?.fullName ?? 'Patient', subLine: item.patient?.patientCode),
      otDischargeStatusCell(item, hasInvoice),
      deskStatusPill(hasInvoice ? 'Generated' : 'Pending', hasInvoice ? AppColors.green : AppColors.orange),
      _actionsCell(item, hasInvoice),
    ];
  }

  Widget _actionsCell(OtBookingSummary item, bool hasInvoice) {
    final isHistory = _activeTab == 'history';
    final viewBtn = deskTableActionBtn(icon: Icons.visibility_outlined, label: 'View', onTap: () => _showBookingView(item));
    // Web parity (web pull 2026-09-30): View is unconditional on every row —
    // this previously only ever appeared on the History tab.
    if (!hasInvoice) {
      if (isHistory || !_canGenerateInvoice) {
        return Align(alignment: Alignment.centerLeft, child: viewBtn);
      }
      final busy = _busyId == item.id;
      return Align(
        alignment: Alignment.centerLeft,
        child: ActionCluster(children: [
          viewBtn,
          TableLabelAction(
            label: 'Generate Invoice',
            icon: Icons.receipt_rounded,
            tone: TableLabelTone.teal,
            busy: busy,
            onTap: busy ? null : () => _generateInvoice(item),
          ),
        ]),
      );
    }
    return ActionCluster(children: [
      viewBtn,
      if (_canBillPrint) _docBtn(item, OtDischargeDocType.summaryBill, 'Bill Summary'),
      if (_canDischargePrint) _docBtn(item, OtDischargeDocType.discharge, 'Discharge'),
      if (_canCertificatePrint) _docBtn(item, OtDischargeDocType.certificate, 'Certificate'),
    ]);
  }

  Widget _docBtn(OtBookingSummary item, OtDischargeDocType type, String label) {
    final busy = _busyId == item.id && _busyType == type;
    final done = otDischargeDocPrintedAt(item, type) != null;
    return TableLabelAction(
      label: label,
      icon: done ? Icons.check_circle_rounded : Icons.picture_as_pdf_outlined,
      tone: done ? TableLabelTone.positive : TableLabelTone.secondary,
      busy: busy,
      onTap: busy ? null : () => _print(item.id, type),
    );
  }
}
