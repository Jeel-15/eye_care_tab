import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_ward_models.dart';
import '../services/doctor_ot_list_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/app_route.dart';
import '../utils/date_format.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/form_kit.dart';
import '../widgets/ot_date_range_chip.dart';
import '../widgets/ot_panel_header.dart';
import '../widgets/permission_guard.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_row_action.dart';

/// Doctor's own OT patient drill-down — net new (web pull 2026-08-07,
/// "Phase 2"): two actions once a patient's ward consult is pending —
/// Assign OT Assistant (agrees OT, marks Ready) or Refuse Surgery (sends to
/// Accounts for a full refund). Neither app had this screen before. Plain
/// embedded list (no Pattern A pane) — both actions happen via dialogs, no
/// drill-down detail is needed. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §5.
class DoctorOtListScreen extends StatefulWidget {
  // Set when opened from a doctor's OP chip. Web sends that doctor's id on
  // every OP click, including the logged-in doctor's.
  final int? doctorId;
  final String? doctorName;

  /// Web's OP link uses `queue=consult` — the open ward consults, not the
  /// date-filtered OT list.
  final bool consultOnly;

  /// Pushed on top of the dashboard, so the panel header can go back.
  final bool showBack;

  const DoctorOtListScreen({
    super.key,
    this.doctorId,
    this.doctorName,
    this.consultOnly = false,
    this.showBack = false,
  });

  @override
  State<DoctorOtListScreen> createState() => _DoctorOtListScreenState();
}

/// Mirrors `OtBooking::isDoctorConsultationPending()` closely enough for a
/// client-side show/hide decision — the server re-checks this exactly on
/// both action endpoints regardless, so a stale/optimistic client check
/// here can't cause a wrong write, only a wrongly-shown button.
bool _isConsultPending(OtBookingSummary b) {
  const eligibleOtStatuses = {
    OtStatus.paymentVerified,
    OtStatus.inWard,
    OtStatus.dilated,
  };
  const eligiblePreOp = {'preparing', 'hold', 'complicated', 'not_fit'};
  return eligibleOtStatuses.contains(b.otStatus) &&
      eligiblePreOp.contains(b.preOpStatus ?? 'preparing');
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await DoctorOtListService.instance.fetchBookings(
        startDate: widget.consultOnly ? null : _fmt(_startDate),
        endDate: widget.consultOnly ? null : _fmt(_endDate),
        doctorId: widget.doctorId,
        consultOnly: widget.consultOnly,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _items = result.items;
          _meta = result.meta;
          _otAssistants = result.otAssistants;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
      builder: (dCtx) => StatefulBuilder(
        builder: (_, ss) => AppDialog(
          size: AppDialogSize.small,
          header: AppDialogHeader(
            icon: Icons.assignment_ind_rounded,
            title: 'Assign OT Assistant',
            subtitle: item.patient?.fullName,
            onClose: () => Navigator.pop(dCtx, false),
          ),
          body: DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            decoration: appFieldDecoration('OT Assistant *'),
            items: _otAssistants
                .map(
                  (a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => ss(() => selected = v),
          ),
          actions: [
            AppSecondaryButton(onPressed: () => Navigator.pop(dCtx, false)),
            AppPrimaryButton(
              label: 'Assign & Mark Ready',
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dCtx, true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null || !mounted) return;
    try {
      await DoctorOtListService.instance.assignAssistant(
        item.id,
        otAssistantId: selected!,
      );
      if (mounted)
        showAppSnackBar(
          context,
          'OT Assistant assigned. Patient is Ready for OT.',
          isSuccess: true,
        );
      _load();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  Future<void> _refuseSurgery(OtBookingSummary item) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Patient refuses OT?',
      message:
          'This will mark the booking as surgery_refused and send it to Accounts for a full refund.',
      confirmLabel: 'Confirm Refuse',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!confirmed || !mounted) return;
    try {
      await DoctorOtListService.instance.refuseSurgery(item.id);
      if (mounted)
        showAppSnackBar(
          context,
          'Patient refused OT. Sent to Accounts for refund.',
          isSuccess: true,
        );
      _load();
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.consultOnly ? 'Assigned OT Patients' : 'OT Patients';
    final who = widget.doctorName;
    return Container(
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
            icon: Icons.local_hospital_rounded,
            title: title,
            subtitle: who == null || who.isEmpty ? null : 'Dr. $who',
            actions: [
              if (!widget.consultOnly)
                OtDateRangeChip(
                  from: _startDate,
                  to: _endDate,
                  onChanged: (range) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              if (widget.showBack) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: _loading
                ? const AppSkeletonList(count: 6, itemHeight: 56)
                : _error != null
                ? AppErrorState(message: _error!, onRetry: _load)
                : _buildBody(),
          ),
          if (_meta != null && !_loading && _error == null)
            TablePaginationFooter(
              total: _meta!.total,
              currentPage: _meta!.currentPage,
              lastPage: _meta!.lastPage,
              start: _meta!.total == 0
                  ? 0
                  : ((_meta!.currentPage - 1) * _meta!.perPage) + 1,
              end: (_meta!.currentPage * _meta!.perPage).clamp(0, _meta!.total),
              onPrev: () {
                setState(() => _page = _meta!.currentPage - 1);
                _load();
              },
              onNext: () {
                setState(() => _page = _meta!.currentPage + 1);
                _load();
              },
            ),
        ],
      ),
    );
  }

  static const _columns = [
    ScaledTableColumn('PATIENT', 180, grow: true),
    ScaledTableColumn('CONTACT', 130),
    ScaledTableColumn('AGE', 80),
    ScaledTableColumn('OT DATE', 120),
    ScaledTableColumn('SURGERY', 150, grow: true),
    ScaledTableColumn('EYE', 70),
    ScaledTableColumn('STATUS', 150),
    ScaledTableColumn('ACTION', 220, hug: true),
  ];

  Widget _buildBody() {
    if (_items.isEmpty) {
      return AppEmptyState(
        message: widget.consultOnly
            ? 'No ward-assigned patients for this doctor.'
            : 'No OT patients in this date range.',
        icon: Icons.local_hospital_outlined,
        onRefresh: _load,
      );
    }

    return AppRefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ScaledDataTable(
          columns: _columns,
          rows: [for (final item in _items) _row(item)],
          emptyMessage: 'No patients.',
        ),
      ),
    );
  }

  List<Widget> _row(OtBookingSummary item) {
    final pending = _isConsultPending(item);
    final age = item.patient?.age;
    final gender = item.patient?.gender;
    final ageLabel = [
      if (age != null) '$age',
      if (gender != null && gender.isNotEmpty) gender[0].toUpperCase(),
    ].join(' / ');
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.patient?.fullName ?? 'Patient',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if ((item.patient?.patientCode ?? '').isNotEmpty)
            Text(
              item.patient!.patientCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      Text(
        item.patient?.contactNo ?? '—',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        ageLabel.isEmpty ? '—' : ageLabel,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        formatPlainDate(item.surgeryDate) ?? '—',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        item.otType ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      Text(
        item.eye ?? '—',
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
            OtStatus.label(item.otStatus),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            otPreOpStatusLabel(item.preOpStatus ?? 'preparing'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      pending
          ? ActionCluster(
              children: [
                TableLabelAction(
                  label: 'Assign',
                  onTap: () => _assignAssistant(item),
                ),
                TableLabelAction(
                  label: 'Refuse',
                  tone: TableLabelTone.danger,
                  onTap: () => _refuseSurgery(item),
                ),
              ],
            )
          : const Text(
              '—',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
    ];
  }
}

/// Web opens the same OP page for the logged-in doctor and every other doctor.
void openDoctorOpList(
  BuildContext context, {
  required int doctorId,
  String? doctorName,
}) {
  Navigator.of(context, rootNavigator: true).push(
    appRoute(
      PermissionGuard(
        allowed: (p) => p.canAny(const [
          Perm.opdExamSecondary,
          Perm.otPatientList,
          Perm.otSurgeryRecommend,
        ]),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DoctorOtListScreen(
                doctorId: doctorId,
                doctorName: doctorName,
                consultOnly: true,
                showBack: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
