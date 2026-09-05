import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/ot_booking_models.dart';
import '../utils/date_format.dart';
import '../models/ot_ward_models.dart';
import '../services/doctor_ot_list_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/skeleton.dart';

/// Doctor's own OT patient drill-down — net new (web pull 2026-08-07,
/// "Phase 2"): two actions once a patient's ward consult is pending —
/// Assign OT Assistant (agrees OT, marks Ready) or Refuse Surgery (sends to
/// Accounts for a full refund). Neither app had this screen before. Plain
/// embedded list (no Pattern A pane) — both actions happen via dialogs, no
/// drill-down detail is needed. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §5.
class DoctorOtListScreen extends StatefulWidget {
  // Set when opened from another doctor's OT card on the dashboard (TASK
  // 5.2) — a read-only peek at that doctor's OT bookings, pushed as a
  // one-off route instead of going through the rail (which only carries
  // "my OT" with no per-doctor state). Assign/refuse actions still
  // re-check ownership server-side regardless.
  final int? doctorId;

  const DoctorOtListScreen({super.key, this.doctorId});

  @override
  State<DoctorOtListScreen> createState() => _DoctorOtListScreenState();
}

/// Mirrors `OtBooking::isDoctorConsultationPending()` closely enough for a
/// client-side show/hide decision — the server re-checks this exactly on
/// both action endpoints regardless, so a stale/optimistic client check
/// here can't cause a wrong write, only a wrongly-shown button.
bool _isConsultPending(OtBookingSummary b) {
  const eligibleOtStatuses = {OtStatus.paymentVerified, OtStatus.inWard, OtStatus.dilated};
  const eligiblePreOp = {'preparing', 'hold', 'complicated', 'not_fit'};
  return eligibleOtStatuses.contains(b.otStatus) && eligiblePreOp.contains(b.preOpStatus ?? 'preparing');
}

class _DoctorOtListScreenState extends State<DoctorOtListScreen> {
  List<OtBookingSummary> _items = [];
  OtPaginationMeta? _meta;
  List<OtNamedRef> _otAssistants = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  String _fmt(DateTime d) => toIsoDate(d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await DoctorOtListService.instance.fetchBookings(startDate: _fmt(_startDate), endDate: _fmt(_endDate), doctorId: widget.doctorId, page: _page);
      if (mounted) {
        setState(() {
          _items = result.items;
          _meta = result.meta;
          _otAssistants = result.otAssistants;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; _page = 1; });
      _load();
    }
  }

  Future<void> _assignAssistant(OtBookingSummary item) async {
    if (_otAssistants.isEmpty) {
      showAppSnackBar(context, 'No active OT Assistants found.', isError: true);
      return;
    }
    int? selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(builder: (_, ss) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text('Assign OT Assistant'),
            content: SizedBox(
              width: 360,
              child: DropdownButtonFormField<int>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'OT Assistant *', border: OutlineInputBorder()),
                items: _otAssistants.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => ss(() => selected = v),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selected == null ? null : () => Navigator.pop(dCtx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Assign & Mark Ready'),
              ),
            ],
          )),
    );
    if (confirmed != true || selected == null || !mounted) return;
    try {
      await DoctorOtListService.instance.assignAssistant(item.id, otAssistantId: selected!);
      if (mounted) showAppSnackBar(context, 'OT Assistant assigned. Patient is Ready for OT.', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _refuseSurgery(OtBookingSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Patient refuses OT?'),
        content: const Text('This will mark the booking as surgery_refused and send it to Accounts for a full refund.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), child: const Text('Confirm Refuse')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await DoctorOtListService.instance.refuseSurgery(item.id);
      if (mounted) showAppSnackBar(context, 'Patient refused OT. Sent to Accounts for refund.', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.doctorId != null ? 'Doctor\'s OT Patients' : 'My OT Patients', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        OutlinedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range_rounded, size: 16), label: Text('${_fmt(_startDate)} → ${_fmt(_endDate)}', style: const TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 6, itemHeight: 80)
            : _error != null
                ? AppErrorState(message: _error!, onRetry: _load)
                : _buildBody(),
      ),
      if (_meta != null) Padding(padding: const EdgeInsets.only(top: 8), child: AppPaginationBar(currentPage: _meta!.currentPage, totalPages: _meta!.lastPage, onPageChange: (p) { setState(() => _page = p); _load(); })),
    ]);
  }

  Widget _buildBody() {
    if (_items.isEmpty) return AppEmptyState(message: 'No OT patients in this date range.', icon: Icons.local_hospital_outlined, onRefresh: _load);

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i];
        final pending = _isConsultPending(item);
        return AnimatedListItem(
          index: i,
          child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryA08)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.patient?.fullName ?? 'Patient', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${item.patient?.patientCode ?? ''}${item.surgeryDate != null ? ' · ${item.surgeryDate}' : ' · Date not set'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ]),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(999)), child: Text(OtStatus.label(item.otStatus).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
              const SizedBox(width: 10),
              if (pending) ...[
                OutlinedButton(
                  onPressed: () => _assignAssistant(item),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
                  child: const Text('Assign Assistant', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _refuseSurgery(item),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                  child: const Text('Refuse OT', style: TextStyle(fontSize: 12)),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text(
              item.otStatus == OtStatus.surgeryRefused
                  ? 'Awaiting refund (Accounts)'
                  : item.otStatus == OtStatus.ready
                      ? 'Ready for OT'
                      : 'Ward: ${otPreOpStatusLabel(item.preOpStatus ?? 'preparing')}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ]),
          ),
        );
      },
    );
  }
}
