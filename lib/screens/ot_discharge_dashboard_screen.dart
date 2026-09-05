import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_booking_models.dart';
import '../services/ot_discharge_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/split_pane_scaffold.dart';
import '../widgets/status_badge.dart';
import 'ot_discharge_detail_screen.dart';

/// Tablet Discharge & Invoices — Pattern A (list + detail split), matching
/// `OtWardQueueScreen`/`OtCounsellorDashboardScreen`/`OtAssistantDashboardScreen`
/// exactly. Used to be "Pattern C, full pushed route" (tapping a row pushed a
/// separate full-screen route covering the whole shell, chosen for the wide
/// 4-column print grid) — rebuilt so the list stays visible and the
/// invoice/print grid opens embedded in the same pane, per user request
/// (2026-08-07) for consistency across the OT module.
class OtDischargeDashboardScreen extends StatefulWidget {
  const OtDischargeDashboardScreen({super.key});

  @override
  State<OtDischargeDashboardScreen> createState() => _OtDischargeDashboardScreenState();
}

enum _PaneMode { list, detail }

class _OtDischargeDashboardScreenState extends State<OtDischargeDashboardScreen> {
  List<OtBookingSummary> _items = [];
  OtPaginationMeta? _meta;
  bool _loading = true;
  String? _error;
  int _page = 1;

  _PaneMode _paneMode = _PaneMode.list;
  OtBookingSummary? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await OtDischargeService.instance.fetchBookings(page: _page);
      if (mounted) setState(() { _items = result.items; _meta = result.meta; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _open(OtBookingSummary item) => setState(() { _paneMode = _PaneMode.detail; _selected = item; });

  void _closePane() => setState(() { _paneMode = _PaneMode.list; _selected = null; });

  void _onInvoiceChanged() => _load();

  @override
  Widget build(BuildContext context) {
    return SplitPaneScaffold(
      showDetail: _paneMode != _PaneMode.list,
      onBack: _closePane,
      listPane: _buildListPane(),
      detailPane: _buildDetailPane(),
      listPaneWidth: 420,
    );
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Billing Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            if (_meta != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(999)), child: Text('${_meta!.total} total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Generate invoices and print discharge documents.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
        ),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 6, itemHeight: 80)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : _buildBody(),
        ),
        if (_meta != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _meta!.currentPage, totalPages: _meta!.lastPage, onPageChange: (p) { setState(() => _page = p); _load(); })),
      ]),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) return AppEmptyState(message: 'No records available for billing.', icon: Icons.receipt_long_rounded, onRefresh: _load);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => AnimatedListItem(index: i, child: _bookingCard(_items[i])),
      ),
    );
  }

  Widget _bookingCard(OtBookingSummary item) {
    final selected = _paneMode == _PaneMode.detail && _selected?.id == item.id;
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primaryA08)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.patient?.fullName ?? 'Patient', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  if (item.patient?.patientCode != null && item.patient!.patientCode.isNotEmpty) ...[
                    Text(item.patient!.patientCode, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const Text(' · ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                  Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(_fmtDate(item.surgeryDate), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              StatusBadge(label: item.otStatus.toUpperCase(), color: item.otStatus == OtStatus.discharged ? AppColors.green : AppColors.orange),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: (item.hasInvoice ?? false) ? AppColors.green.withValues(alpha: 0.12) : AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text((item.hasInvoice ?? false) ? 'Generated' : 'Pending', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: (item.hasInvoice ?? false) ? AppColors.green : AppColors.orange)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.detail && _selected != null) {
      return _panelBox(child: DischargeDetailPane(key: ValueKey('discharge-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', onClose: _closePane, onInvoiceChanged: _onInvoiceChanged));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Tap a booking to generate its', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('invoice and print documents.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
        ]),
      ),
    );
  }

  Widget _panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: child,
    );
  }
}
