import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/medicine_models.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_assistant_models.dart';
import '../models/ot_booking_models.dart';
import '../services/ot_assistant_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_section_header.dart';

/// Tablet Assistant Dashboard — Pattern A (list + detail split), matching
/// `OtWardQueueScreen`/`OtCounsellorDashboardScreen` exactly. Used to be
/// "Pattern C, full pushed route" (Operate pushed a separate full-screen
/// route covering the whole shell) — rebuilt so the list stays visible and
/// Surgery Record opens embedded in the same pane. See
/// OT_WEB_PARITY_FIX_PRD.md §5. No lens-recording entry point — web's
/// lens-record route has no UI link of its own either (removed 2026-08-07,
/// previously a dialog on top of this pane — see
/// OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md).
class OtAssistantDashboardScreen extends StatefulWidget {
  final UserInfo user;

  const OtAssistantDashboardScreen({super.key, required this.user});

  @override
  State<OtAssistantDashboardScreen> createState() => _OtAssistantDashboardScreenState();
}

enum _PaneMode { list, detail }

class _OtAssistantDashboardScreenState extends State<OtAssistantDashboardScreen> {
  List<OtBookingSummary> _items = [];
  OtPaginationMeta? _meta;
  bool _loading = true;
  String? _error;
  int _page = 1;

  _PaneMode _paneMode = _PaneMode.list;
  OtBookingSummary? _selected;

  bool get _canSurgery => PermissionService.instance.can(Perm.otSurgeryRecord);
  // Matches web's `isSuperUser() || role.slug === 'hospital_admin'` exactly
  // (OtAssistantController::dashboard()) — admins see the Surgeon column
  // and every ready booking, not just their own.
  bool get _seeAll => (widget.user.role?.isSuper ?? false) || widget.user.role?.slug == 'hospital_admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await OtAssistantService.instance.fetchBookings(page: _page);
      if (mounted) setState(() { _items = result.items; _meta = result.meta; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _open(OtBookingSummary item) => setState(() { _paneMode = _PaneMode.detail; _selected = item; });

  void _closePane() => setState(() { _paneMode = _PaneMode.list; _selected = null; });

  void _onSurgerySaved() {
    _closePane();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();

      if (!splitView) {
        return _paneMode != _PaneMode.list
            ? Column(children: [
                TextButton.icon(onPressed: _closePane, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 420, child: listPane),
          const SizedBox(width: 20),
          Expanded(child: detailPane),
        ],
      );
    });
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Surgery Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            if (_meta != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(999)), child: Text('${_meta!.total} total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : _buildBody(),
        ),
        if (_meta != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _meta!.currentPage, totalPages: _meta!.lastPage, onPageChange: (p) { setState(() => _page = p); _load(); })),
      ]),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) return AppEmptyState(message: 'No bookings ready for surgery.', icon: Icons.handyman_rounded, onRefresh: _load);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i];
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.patient?.fullName ?? 'Patient', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${item.patient?.patientCode ?? ''}${item.eye != null ? ' · ${item.eye}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(999)), child: Text(OtStatus.label(item.otStatus).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (item.otType != null) _infoChip(Icons.heart_broken_outlined, item.otType!),
                  if (item.packageAmount != null) _infoChip(Icons.currency_rupee_rounded, item.packageAmount!.toStringAsFixed(0)),
                  if (_seeAll && item.otDoctor != null) _infoChip(Icons.person_outline_rounded, 'Dr. ${item.otDoctor!.name}'),
                  if (item.paymentStatus != null)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: paymentStatusColor(item.paymentStatus!).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Text(paymentStatusLabel(item.paymentStatus!), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: paymentStatusColor(item.paymentStatus!)))),
                ]),
                if (_canSurgery) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: AppColors.primaryA08),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _open(item),
                      icon: const Icon(Icons.local_hospital_outlined, size: 15),
                      label: const Text('Operate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9), foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      );

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.detail && _selected != null) {
      return _panelBox(child: _AssistantDetailPane(key: ValueKey('assistant-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', onClose: _closePane, onSaved: _onSurgerySaved));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.handyman_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Tap a booking to record', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('the surgery.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
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

// ── Surgery Record detail pane (embedded, not a full screen) ───────────────

/// One `_medicineRows` line — medicine is a dropdown pick (not free text, see
/// OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md G5) so it always resolves against
/// `Medicine::exists` server-side; dose stays free text like web.
class _MedRow {
  String? medicine;
  final TextEditingController doseCtrl = TextEditingController();
  _MedRow({this.medicine});
  void dispose() => doseCtrl.dispose();
}

class _AssistantDetailPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onClose;
  final VoidCallback onSaved;

  const _AssistantDetailPane({super.key, required this.bookingId, required this.patientName, required this.onClose, required this.onSaved});

  @override
  State<_AssistantDetailPane> createState() => _AssistantDetailPaneState();
}

class _AssistantDetailPaneState extends State<_AssistantDetailPane> {
  bool _loading = true;
  String? _loadError;
  OtSurgeryFormData? _formData;
  bool _saving = false;

  final _otRoomCtrl = TextEditingController();
  final _complicationNotesCtrl = TextEditingController();
  final _bloodLossCtrl = TextEditingController();
  final _lensCompanyCtrl = TextEditingController();
  final _lensModelCtrl = TextEditingController();
  final _estimatedPowerCtrl = TextEditingController();
  final _lensCostCtrl = TextEditingController();

  String? _surgeryName;
  DateTime _surgeryDate = DateTime.now();
  // Eye Operated is locked to the booking's own eye (Recommend Surgery
  // selection) — matches web's `$lockedEye`, not a user-editable picker.
  String _lockedEye = 'RE';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _complicationStatus = 'none';
  String? _lensCategory;
  String? _lensType;
  int? _medicineGroupId;
  final List<_MedRow> _medicineRows = [_MedRow()];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _otRoomCtrl.dispose();
    _complicationNotesCtrl.dispose();
    _bloodLossCtrl.dispose();
    _lensCompanyCtrl.dispose();
    _lensModelCtrl.dispose();
    _estimatedPowerCtrl.dispose();
    _lensCostCtrl.dispose();
    for (final r in _medicineRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final formData = await OtAssistantService.instance.fetchSurgeryFormData(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _formData = formData;

        final bookingEye = formData.booking.eye;
        _lockedEye = (bookingEye == 'RE' || bookingEye == 'LE' || bookingEye == 'Both') ? bookingEye! : 'RE';

        final apptSurgeryDate = formData.booking.surgeryDate;
        _surgeryDate = apptSurgeryDate != null ? (DateTime.tryParse(apptSurgeryDate) ?? DateTime.now()) : DateTime.now();

        final otType = formData.booking.otType;
        if (otType != null && formData.surgeryTypes.any((t) => t.surgeryName == otType)) {
          _surgeryName = otType;
        }

        final c = formData.counselling;
        _lensCategory = c?.lensCategory;
        _lensCompanyCtrl.text = c?.lensCompany ?? '';
        _lensModelCtrl.text = c?.lensModel ?? '';
        _lensType = c?.lensType;
        _estimatedPowerCtrl.text = c?.estimatedPower?.toString() ?? '';
        _lensCostCtrl.text = c?.lensCost != null ? c!.lensCost!.toStringAsFixed(2) : '';

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pickSurgeryDate() async {
    final date = await showDatePicker(context: context, initialDate: _surgeryDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date != null) setState(() => _surgeryDate = date);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = (isStart ? _startDateTime : _endDateTime) ?? DateTime.now();
    final date = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() { if (isStart) _startDateTime = combined; else _endDateTime = combined; });
  }

  void _addMedicineRow() => setState(() => _medicineRows.add(_MedRow()));

  /// Removing the last remaining row clears it instead of deleting it —
  /// matches web's JS behaviour exactly (a row is always present).
  void _removeMedicineRow(int i) {
    if (_medicineRows.length == 1) {
      setState(() {
        _medicineRows[i].medicine = null;
        _medicineRows[i].doseCtrl.clear();
      });
      return;
    }
    setState(() {
      _medicineRows[i].dispose();
      _medicineRows.removeAt(i);
    });
  }

  /// Wipes and rebuilds the medicine row list from the selected group's
  /// items — matches web's quick-fill behaviour, incl. composing dose from
  /// `frequency + duration` (not dosage text).
  void _applyMedicineGroup(MedGroup group) {
    setState(() {
      for (final r in _medicineRows) {
        r.dispose();
      }
      _medicineRows.clear();
      _medicineGroupId = group.id;
      for (final item in group.items) {
        if (item.medicineName == null || item.medicineName!.isEmpty) continue;
        _medicineRows.add(_MedRow(medicine: item.medicineName)..doseCtrl.text = item.quickFillDose);
      }
      if (_medicineRows.isEmpty) _medicineRows.add(_MedRow());
    });
  }

  String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtDateTime(DateTime d) => '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
  String _fmtDisplayDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtDisplayDateTime(DateTime? d) => d == null ? 'Select' : '${_fmtDisplayDate(d)} ${TimeOfDay.fromDateTime(d).format(context)}';

  Future<void> _save() async {
    if (_surgeryName == null || _surgeryName!.isEmpty) {
      showAppSnackBar(context, 'Surgery name is required', isError: true);
      return;
    }
    if (_complicationStatus != 'none' && _complicationNotesCtrl.text.trim().isEmpty) {
      showAppSnackBar(context, 'Complication notes are required when a complication is recorded', isError: true);
      return;
    }
    if (_startDateTime != null && _endDateTime != null && !_endDateTime!.isAfter(_startDateTime!)) {
      showAppSnackBar(context, 'End time must be after start time', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await OtAssistantService.instance.storeSurgery(
        widget.bookingId,
        surgeryDate: _fmtDate(_surgeryDate),
        surgeryName: _surgeryName!,
        otRoom: _otRoomCtrl.text.trim().isEmpty ? null : _otRoomCtrl.text.trim(),
        eyeOperated: _lockedEye,
        startTime: _startDateTime == null ? null : _fmtDateTime(_startDateTime!),
        endTime: _endDateTime == null ? null : _fmtDateTime(_endDateTime!),
        complicationStatus: _complicationStatus,
        complicationNotes: _complicationNotesCtrl.text.trim().isEmpty ? null : _complicationNotesCtrl.text.trim(),
        bloodLoss: _bloodLossCtrl.text.trim().isEmpty ? null : _bloodLossCtrl.text.trim(),
        medicineGroupId: _medicineGroupId,
        otMedicines: _medicineRows
            .where((r) => (r.medicine ?? '').isNotEmpty)
            .map((r) => OtSurgeryMedicineLine(medicine: r.medicine!, dose: r.doseCtrl.text.trim().isEmpty ? null : r.doseCtrl.text.trim()))
            .toList(),
        lensCategory: _lensCategory,
        lensCompany: _lensCompanyCtrl.text.trim().isEmpty ? null : _lensCompanyCtrl.text.trim(),
        lensModel: _lensModelCtrl.text.trim().isEmpty ? null : _lensModelCtrl.text.trim(),
        lensType: _lensType,
        estimatedPower: double.tryParse(_estimatedPowerCtrl.text.trim()),
        lensCost: double.tryParse(_lensCostCtrl.text.trim()),
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Surgery recorded successfully.', isSuccess: true);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onClose, tooltip: 'Close'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(Icons.local_hospital_outlined, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Surgery Recording Form', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(_formData != null ? '${widget.patientName}${_formData!.booking.eye != null ? ' · ${_formData!.booking.eye}' : ''}' : widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : _buildForm(),
      ),
    ]);
  }

  Widget _buildForm() {
    final formData = _formData!;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppSectionHeader(title: 'A. Patient & Booking Details', icon: Icons.badge_outlined),
            Wrap(spacing: 32, runSpacing: 6, children: [
              _readOnlyRow('Patient Name', formData.booking.patient?.fullName ?? '—'),
              _readOnlyRow('Phone', formData.booking.patient?.contactNo ?? '—'),
              _readOnlyRow('Package', '₹${(formData.counselling?.packageAmount ?? formData.booking.packageAmount ?? 0).toStringAsFixed(2)}'),
              _readOnlyRow('Mediclaim', (formData.counselling?.mediclaim ?? formData.booking.hasMediclaim ?? false) ? 'YES' : 'NO'),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: InkWell(
                onTap: _pickSurgeryDate,
                child: InputDecorator(decoration: _deco('OT Date *'), child: Text(_fmtDisplayDate(_surgeryDate))),
              ),
            ),
            const SizedBox(height: 16),

            const AppSectionHeader(title: 'B. Surgery Details', icon: Icons.local_hospital_outlined),
            Row(children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _surgeryName,
                  isExpanded: true,
                  decoration: _deco('Surgery Name *', hint: 'Select surgery...'),
                  items: formData.surgeryTypes.map((t) => DropdownMenuItem(value: t.surgeryName, child: Text(t.surgeryName, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _surgeryName = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: InputDecorator(decoration: _deco('Eye Operated'), child: Text(_lockedEye, style: const TextStyle(fontWeight: FontWeight.w700)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _otRoomCtrl, decoration: _deco('OT Room', hint: 'e.g. OT-1'))),
              const SizedBox(width: 10),
              Expanded(child: InkWell(onTap: () => _pickDateTime(isStart: true), child: InputDecorator(decoration: _deco('Start Time'), child: Text(_fmtDisplayDateTime(_startDateTime))))),
              const SizedBox(width: 10),
              Expanded(child: InkWell(onTap: () => _pickDateTime(isStart: false), child: InputDecorator(decoration: _deco('End Time'), child: Text(_fmtDisplayDateTime(_endDateTime))))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: ['none', 'minor', 'major'].map((c) => ChoiceChip(label: Text(c[0].toUpperCase() + c.substring(1)), selected: _complicationStatus == c, onSelected: (_) => setState(() => _complicationStatus = c))).toList()),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _complicationNotesCtrl, maxLines: 2, decoration: _deco('Complication Notes', hint: 'Only required if complication status is minor/major'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _bloodLossCtrl, decoration: _deco('Blood Loss', hint: 'e.g. Minimal, 50ml'))),
            ]),
            const SizedBox(height: 16),

            const AppSectionHeader(title: 'C. Lens Selection', icon: Icons.remove_red_eye_outlined),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Auto-filled from Counsellor form — confirm or adjust if needed before saving surgery.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _lensCategory,
                  isExpanded: true,
                  decoration: _deco('Lens Category', hint: 'Select...'),
                  items: const [DropdownMenuItem(value: 'standard', child: Text('Standard')), DropdownMenuItem(value: 'premium', child: Text('Premium'))],
                  onChanged: (v) => setState(() => _lensCategory = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _lensCompanyCtrl, decoration: _deco('Lens Company'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _lensModelCtrl, decoration: _deco('Lens Model'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _lensType,
                  isExpanded: true,
                  decoration: _deco('Lens Type', hint: 'Select...'),
                  items: formData.lensTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _lensType = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _estimatedPowerCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: _deco('Estimated Power'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _lensCostCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _deco('Lens Cost (₹)', hint: 'Enter lens cost'))),
            ]),
            const SizedBox(height: 16),

            AppSectionHeader(title: 'D. In-Ward Medicines', icon: Icons.medication_outlined, trailing: TextButton.icon(onPressed: _addMedicineRow, icon: const Icon(Icons.add_rounded, size: 14), label: const Text('Add Medicine', style: TextStyle(fontSize: 12)))),
            if (formData.medicineGroups.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _medicineGroupId,
                isExpanded: true,
                decoration: _deco('Quick-fill from OT Medicine Group', hint: 'Select group (optional)...'),
                items: formData.medicineGroups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _applyMedicineGroup(formData.medicineGroups.firstWhere((g) => g.id == v));
                },
              ),
            const SizedBox(height: 10),
            for (var i = 0; i < _medicineRows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _medicineRows[i].medicine,
                      isExpanded: true,
                      decoration: _deco('Medicine', hint: 'Select medicine...'),
                      items: formData.medicines.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _medicineRows[i].medicine = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _medicineRows[i].doseCtrl, decoration: _deco('Dose / Frequency'))),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.red), onPressed: () => _removeMedicineRow(i)),
                ]),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Surgery', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    ]);
  }

  Widget _readOnlyRow(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      );
}
