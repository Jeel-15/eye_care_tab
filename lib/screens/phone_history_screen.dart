import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/patient_service.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/ot/ot_booking_view_dialog.dart';
import '../widgets/scaled_data_table.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';
import '../widgets/table_pagination_footer.dart';
import '../widgets/table_row_action.dart';
import '../utils/app_date_picker.dart';
import '../utils/app_route.dart';
import '../utils/date_format.dart';
import 'opd_bill_screen.dart';
import 'patient_checkin_screen.dart';

/// Phone appointment history. Web page `phone-history.blade.php`: search by
/// name or mobile, optional date range, then the phone list.
///
/// Redesigned 2026-10-06 — the previous version (plain `TextField` row,
/// hand-rolled `Material` list rows, a one-off view `Dialog`, literal
/// "Previous"/"Next" buttons) was a one-off layout unlike every other
/// tablet table screen. Rebuilt onto this app's own web-parity table
/// convention (`ScaledDataTable`/`TablePaginationFooter`, same chrome
/// `OtAppointmentListScreen`/`ShareHistoryScreen` use) and the shared
/// `showRecordView` view-dialog host (`widgets/ot/ot_booking_view_dialog
/// .dart`) instead of a hand-rolled one.
class PhoneHistoryScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  const PhoneHistoryScreen({
    super.key,
    required this.user,
    required this.hospital,
  });

  @override
  State<PhoneHistoryScreen> createState() => _PhoneHistoryScreenState();
}

class _PhoneHistoryScreenState extends State<PhoneHistoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  String? _error;
  List<Patient> _rows = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PatientService.instance.fetchPhoneHistory(
        search: _searchCtrl.text,
        fromDate: _from == null ? null : toIsoDate(_from!),
        toDate: _to == null ? null : toIsoDate(_to!),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _rows = result.patients;
        _page = result.meta.currentPage;
        _lastPage = result.meta.lastPage;
        _total = result.meta.total;
        _perPage = result.meta.perPage;
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

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  Future<void> _pickRange() async {
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (_from != null && _to != null)
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Future<void> _checkIn(Patient p) async {
    await showDialog<void>(
      context: context,
      builder: (dCtx) => PatientCheckinScreen(
        user: widget.user,
        hospital: widget.hospital,
        patient: p,
        onCancel: () => Navigator.pop(dCtx),
        onDone: (updated) {
          Navigator.pop(dCtx);
          _load(page: _page);
          Navigator.of(context, rootNavigator: true).push(
            appRoute(
              OpdBillScreen(
                user: widget.user,
                hospital: widget.hospital,
                patient: updated,
              ),
            ),
          );
        },
      ),
    );
  }

  void _view(Patient p) {
    final date = parseApiPlainDate(p.appointmentDate);
    final checked = p.caseId != null;
    showRecordView(
      context,
      name: p.fullName,
      meta: p.patientCode.isEmpty ? null : 'MRD: ${p.patientCode}',
      pills: [
        Pill(
          checked ? 'Checked In' : 'Pending',
          bg: (checked ? AppColors.green : AppColors.orange).withValues(alpha: 0.12),
          fg: checked ? AppColors.green : AppColors.orange,
        ),
      ],
      facts: [
        HeaderFact('Contact', p.contactNo ?? '—'),
        HeaderFact('Appointment', date != null ? toDisplayDate(date) : '—'),
        HeaderFact('Doctor', p.doctor?.name ?? '—'),
      ],
      sections: [
        FactSection('Registration Details', [
          Fact('Age / Gender', '${p.age ?? '—'} / ${p.gender ?? '—'}'),
          Fact('WhatsApp', (p.whatsappNo ?? '').isEmpty ? '—' : p.whatsappNo!),
          Fact('City', p.location?.city ?? '—'),
          Fact('Reception', p.receptionistName ?? '—'),
          Fact('Case', p.caseId == null ? '—' : (p.caseType?.caseType ?? '—')),
        ]),
      ],
    );
  }

  static const _columns = [
    ScaledTableColumn('MRD', 90),
    ScaledTableColumn('PATIENT', 150, grow: true),
    ScaledTableColumn('MOBILE', 110),
    ScaledTableColumn('DOCTOR', 130, grow: true),
    ScaledTableColumn('APPOINTMENT', 100),
    ScaledTableColumn('STATUS', 110),
    ScaledTableColumn('ACTION', 140, hug: true),
  ];

  @override
  Widget build(BuildContext context) {
    final rangeLabel = (_from == null || _to == null)
        ? 'Date range'
        : '${toDisplayDate(_from!)} – ${toDisplayDate(_to!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primaryA10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryA06,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search by name or mobile number...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.primaryA55),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.primaryA55),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.primaryA04,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(rangeLabel),
              ),
              if (_from != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Clear date range',
                  icon: Icon(Icons.close_rounded, size: 18, color: AppColors.primaryA55),
                  onPressed: () {
                    setState(() {
                      _from = null;
                      _to = null;
                    });
                    _load();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
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
            child: _body(),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 60);
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: () => _load(page: _page));
    }
    if (_rows.isEmpty) {
      return const AppEmptyState(message: 'No phone appointments found.');
    }
    return Column(
      children: [
        Expanded(
          child: AppRefreshIndicator(
            onRefresh: () => _load(page: _page),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: ScaledDataTable(
                  columns: _columns,
                  rows: _rows.map(_rowCells).toList(),
                  emptyMessage: 'No phone appointments found.',
                ),
              ),
            ),
          ),
        ),
        TablePaginationFooter(
          total: _total,
          currentPage: _page,
          lastPage: _lastPage,
          start: _total == 0 ? 0 : ((_page - 1) * _perPage) + 1,
          end: (_page * _perPage).clamp(0, _total),
          onPrev: () => _load(page: _page - 1),
          onNext: () => _load(page: _page + 1),
        ),
      ],
    );
  }

  List<Widget> _rowCells(Patient p) {
    final checked = p.caseId != null;
    final date = parseApiPlainDate(p.appointmentDate);
    return [
      Text(
        p.patientCode.isEmpty ? '—' : p.patientCode,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryA55),
      ),
      Text(
        p.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      Text(
        p.contactNo ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      Text(
        p.doctor?.name ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      Text(
        date != null ? toDisplayDate(date) : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: StatusBadge(
          label: checked ? 'Checked In' : 'Pending',
          color: checked ? AppColors.green : AppColors.orange,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableIconAction(
            icon: Icons.visibility_outlined,
            tooltip: 'View',
            onTap: () => _view(p),
          ),
          if (!checked)
            TableLabelAction(
              label: 'Check In',
              icon: Icons.login_rounded,
              tone: TableLabelTone.positive,
              onTap: () => _checkIn(p),
            ),
        ],
      ),
    ];
  }
}
