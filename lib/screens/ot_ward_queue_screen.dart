import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_ward_models.dart';
import '../services/ot_ward_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_section_header.dart';

/// Closes a dialog that contains text fields safely. `unfocus()` only
/// *schedules* the focus change — it doesn't complete synchronously — so
/// popping the route immediately after it still tears the field down mid
/// focus-change and throws `InheritedElement`'s `_dependents.isEmpty`
/// assertion. Deferring the pop to `addPostFrameCallback` lets that
/// scheduled change fully resolve on its own frame first. See
/// OT_WEB_PARITY_FIX_PRD.md §4.3 (pass 2 — pass 1's synchronous unfocus
/// call was not sufficient).
void _closeDialogSafely(BuildContext dialogContext) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  });
}

/// Tablet Ward Entry Queue (Round 3 Phase 3) — Pattern A (list + detail
/// split), matching `OtCounsellorDashboardScreen`/`OtAppointmentListScreen`
/// exactly. Tapping a row used to push `OtWardScreen` as a full-screen
/// route that covered the whole shell (same "leaves the app" complaint as
/// Counsellor's old flow) — the list now stays visible and the detail opens
/// in the same pane. See OT_WEB_PARITY_FIX_PRD.md §4.
class OtWardQueueScreen extends StatefulWidget {
  const OtWardQueueScreen({super.key});

  @override
  State<OtWardQueueScreen> createState() => _OtWardQueueScreenState();
}

enum _PaneMode { list, detail }

class _OtWardQueueScreenState extends State<OtWardQueueScreen> {
  List<OtBookingSummary> _items = [];
  OtPaginationMeta? _meta;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int? _sendingId;

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
      final result = await OtWardService.instance.fetchBookings(page: _page);
      if (mounted) setState(() { _items = result.items; _meta = result.meta; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _open(OtBookingSummary item) => setState(() { _paneMode = _PaneMode.detail; _selected = item; });

  void _closePane() => setState(() { _paneMode = _PaneMode.list; _selected = null; });

  Future<void> _sendToOtAssistant(OtBookingSummary item) async {
    setState(() => _sendingId = item.id);
    try {
      await OtWardService.instance.markReady(item.id);
      if (mounted) showAppSnackBar(context, 'Patient is ready and handed off to OT Assistant', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
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
            Icon(Icons.bed_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Ward Entry Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
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
    if (_items.isEmpty) return AppEmptyState(message: 'No records available for ward workflow.', icon: Icons.bed_rounded, onRefresh: _load);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i];
        final selected = _paneMode == _PaneMode.detail && _selected?.id == item.id;
        final canSend = item.otStatus == OtStatus.paymentVerified || item.otStatus == OtStatus.inWard;
        final sending = _sendingId == item.id;
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
                      Text('${item.patient?.contactNo ?? '—'}${item.surgeryDate != null ? ' · ${item.surgeryDate}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.surfaceFill, borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(OtStatus.label(item.otStatus).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
                ]),
                if (item.paymentStatus != null) ...[
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: paymentStatusColor(item.paymentStatus!).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(paymentStatusLabel(item.paymentStatus!), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: paymentStatusColor(item.paymentStatus!)))),
                ],
                if (canSend) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: AppColors.primaryA08),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: sending ? null : () => _sendToOtAssistant(item),
                      icon: sending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 15),
                      label: const Text('Send to OT Assistant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.detail && _selected != null) {
      return _panelBox(child: _WardDetailPane(key: ValueKey('ward-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', initialOtStatus: _selected!.otStatus, onClose: _closePane));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bed_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Tap a booking to record', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('vitals and eye-drop doses.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
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

// ── Ward detail pane (embedded in the detail pane, not a full screen) ──────
// Vitals/Eye Drops/Status are stacked vertically (not the old 3-way side-by-
// side Row) so they read naturally in the narrower detail-pane width —
// same vertical-sections convention as the Counselling pane.

class _WardDetailPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final String? initialOtStatus;
  final VoidCallback onClose;

  const _WardDetailPane({super.key, required this.bookingId, required this.patientName, this.initialOtStatus, required this.onClose});

  @override
  State<_WardDetailPane> createState() => _WardDetailPaneState();
}

class _WardDetailPaneState extends State<_WardDetailPane> {
  OtVerificationHeader? _header;
  OtVitalsItem? _vitals;
  List<OtEyeDropEntry> _eyeDrops = [];
  List<HospitalUserModel> _assistants = [];
  bool _loading = true;
  String? _loadError;

  String? _currentOtStatus;
  bool _sendingReady = false;

  bool get _canWriteVitals => PermissionService.instance.can(Perm.otPreopEntry);
  bool get _canWriteDrops => PermissionService.instance.can(Perm.otDilationTrack);

  @override
  void initState() {
    super.initState();
    _currentOtStatus = widget.initialOtStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final results = await Future.wait([
        OtWardService.instance.fetchVerificationHeader(widget.bookingId),
        OtWardService.instance.fetchVitals(widget.bookingId),
        OtWardService.instance.fetchEyeDrops(widget.bookingId),
        UserService.instance.fetchUsers(),
      ]);
      if (mounted) {
        final users = (results[3] as UserListResponse).users;
        setState(() {
          _header = results[0] as OtVerificationHeader;
          _vitals = results[1] as OtVitalsItem?;
          _eyeDrops = results[2] as List<OtEyeDropEntry>;
          final byRole = users.where((u) => u.role?.slug == 'ot_assistant').toList();
          _assistants = byRole.isNotEmpty ? byRole : users.where((u) => u.role?.slug != 'doctor').toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _openVitalsDialog() async {
    final v = _vitals;
    final bpCtrl = TextEditingController(text: v?.bp ?? '');
    final pulseCtrl = TextEditingController(text: v?.pulse?.toString() ?? '');
    final rbsCtrl = TextEditingController(text: v?.rbs?.toString() ?? '');
    final tempCtrl = TextEditingController(text: v?.temperature?.toString() ?? '');
    final spo2Ctrl = TextEditingController(text: v?.spo2?.toString() ?? '');
    final hba1cCtrl = TextEditingController(text: v?.hba1c?.toString() ?? '');
    bool saving = false;
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];

    await showDialog<void>(context: context, barrierDismissible: false, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        ss(() => saving = true);
        try {
          final newStatus = await OtWardService.instance.storeVitals(widget.bookingId, {
            'bp': bpCtrl.text.trim().isEmpty ? null : bpCtrl.text.trim(),
            'pulse': int.tryParse(pulseCtrl.text.trim()),
            'rbs': double.tryParse(rbsCtrl.text.trim()),
            'temperature': double.tryParse(tempCtrl.text.trim()),
            'spo2': double.tryParse(spo2Ctrl.text.trim()),
            'hba1c': double.tryParse(hba1cCtrl.text.trim()),
            'pre_op_status': v?.preOpStatus ?? 'preparing',
          });
          if (mounted) setState(() => _currentOtStatus = newStatus);
          if (mounted) _closeDialogSafely(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Record Vitals'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextFormField(controller: bpCtrl, decoration: const InputDecoration(labelText: 'BP (e.g. 120/80)', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: pulseCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Pulse', suffixText: 'bpm', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: rbsCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: const InputDecoration(labelText: 'RBS', suffixText: 'mg/dL', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: tempCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: const InputDecoration(labelText: 'Temperature', suffixText: '°F', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: spo2Ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: const InputDecoration(labelText: 'SpO2', suffixText: '%', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: hba1cCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: numFmt, decoration: const InputDecoration(labelText: 'HbA1c', suffixText: '%', border: OutlineInputBorder()))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => _closeDialogSafely(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    for (final c in [bpCtrl, pulseCtrl, rbsCtrl, tempCtrl, spo2Ctrl, hba1cCtrl]) {
      c.dispose();
    }
  }

  Future<void> _openStatusDialog() async {
    String status = _vitals?.preOpStatus ?? 'preparing';
    // Matches web exactly: the OT Assistant select is pre-filled from
    // whoever is currently assigned, not left blank on every open — only
    // pre-select if that person is actually present in the dropdown's own
    // list (e.g. now deactivated / role changed), so this can't throw
    // DropdownButtonFormField's "exactly one matching item" assertion.
    // Doctor is no longer a client-side field at all — auto-assigned
    // server-side from the patient's OPD doctor (web pull 2026-08-07). See
    // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §8.
    int? assistantId = _assistants.any((a) => a.id == _header?.otAssistant?.id) ? _header?.otAssistant?.id : null;
    bool saving = false;
    String? error;

    await showDialog<void>(context: context, barrierDismissible: false, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      final isReady = status == 'ready_for_surgery';
      Future<void> save() async {
        ss(() {
          error = null;
          if (isReady && assistantId == null) error = 'OT Assistant is required when status is Ready for OT';
        });
        if (error != null) return;
        ss(() => saving = true);
        try {
          final newStatus = await OtWardService.instance.storeVitals(widget.bookingId, {
            'pre_op_status': status,
            'assign_staff': true,
            if (assistantId != null) 'ot_assistant_id': assistantId,
          });
          if (mounted) setState(() => _currentOtStatus = newStatus);
          if (mounted) _closeDialogSafely(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Patient Status'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: kOtPreOpStatuses.map((s) => ChoiceChip(label: Text(otPreOpStatusLabel(s)), selected: status == s, onSelected: (_) => ss(() { status = s; error = null; }))).toList())),
            const SizedBox(height: 14),
            if (!isReady)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Doctor (OPD, auto-assigned): ${_header?.otDoctor?.name ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ),
            DropdownButtonFormField<int>(
              initialValue: assistantId,
              isExpanded: true,
              decoration: InputDecoration(labelText: isReady ? 'OT Assistant *' : 'OT Assistant', border: const OutlineInputBorder()),
              items: _assistants.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => ss(() => assistantId = v),
            ),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12))),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => _closeDialogSafely(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Status')),
        ],
      );
    }));
  }

  Future<void> _openEyeDropDialog() async {
    // Medicine picker source (Medicine Master, OT scope) and the booking's
    // own eye-derived allowed set — both replace free-text/unrestricted
    // entry (web pull 2026-08-07). See
    // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §8.
    final otMedicines = _header?.otMedicines ?? const <OtNamedRef>[];
    final allowedEyes = switch (_header?.eye) { 'RE' => const ['RE'], 'LE' => const ['LE'], _ => const ['RE', 'LE'] };
    String? medicineName;
    final nextDose = (_eyeDrops.isEmpty ? 0 : _eyeDrops.map((e) => e.doseNumber).reduce((a, b) => a > b ? a : b)) + 1;
    final doseCtrl = TextEditingController(text: '$nextDose');
    final remarksCtrl = TextEditingController();
    String eye = allowedEyes.first;
    bool saving = false;
    String? medicineErr, doseErr;

    await showDialog<void>(context: context, barrierDismissible: false, builder: (dCtx) => StatefulBuilder(builder: (_, ss) {
      Future<void> save() async {
        final dose = int.tryParse(doseCtrl.text.trim());
        ss(() {
          medicineErr = medicineName == null ? 'Required' : null;
          doseErr = (dose == null || dose < 1 || dose > 20) ? 'Must be 1-20' : null;
        });
        if (medicineErr != null || doseErr != null) return;
        ss(() => saving = true);
        try {
          await OtWardService.instance.addEyeDrop(widget.bookingId, medicineName: medicineName!, eye: eye, doseNumber: dose!, remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim());
          if (mounted) _closeDialogSafely(dCtx);
          await _load();
        } catch (e) {
          ss(() => saving = false);
          if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
        }
      }
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Log Eye-Drop Dose'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: medicineName,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Medicine Name', errorText: medicineErr, border: const OutlineInputBorder()),
              items: otMedicines.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => ss(() { medicineName = v; medicineErr = null; }),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Wrap(spacing: 8, children: allowedEyes.map((e) => ChoiceChip(label: Text(e), selected: eye == e, onSelected: (_) => ss(() => eye = e))).toList()),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: doseCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Dose #', errorText: doseErr, border: const OutlineInputBorder()))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => _closeDialogSafely(dCtx), child: const Text('Cancel')),
          ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
        ],
      );
    }));
    doseCtrl.dispose();
    remarksCtrl.dispose();
  }

  Future<void> _sendToOtAssistant() async {
    setState(() => _sendingReady = true);
    try {
      final status = await OtWardService.instance.markReady(widget.bookingId);
      if (mounted) {
        setState(() { _currentOtStatus = status; _sendingReady = false; });
        showAppSnackBar(context, 'Patient is ready and handed off to OT Assistant', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingReady = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onClose, tooltip: 'Close'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(Icons.bed_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ward Entry', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(_header != null ? '${_header!.patientName} · UHID ${_header!.uhid}${_header!.surgeryType != null ? ' · ${_header!.surgeryType}' : ''}' : widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildReadyBanner(),
                      _buildVitalsPanel(),
                      const SizedBox(height: 16),
                      _buildEyeDropsPanel(),
                      const SizedBox(height: 16),
                      _buildStatusPanel(),
                    ]),
                  ),
      ),
    ]);
  }

  Widget _buildReadyBanner() {
    final status = _currentOtStatus;
    if (status == null) return const SizedBox.shrink();
    final eligibleStatuses = {'payment_verified', 'in_ward'};
    final preOpReady = _vitals?.preOpStatus == 'ready_for_surgery';
    final showButton = eligibleStatuses.contains(status) && preOpReady;
    Color bg;
    Color fg;
    String label;
    if (status == 'ready') {
      bg = AppColors.green.withValues(alpha: 0.12);
      fg = AppColors.green;
      label = 'READY — sent to OT Assistant';
    } else if (eligibleStatuses.contains(status)) {
      bg = const Color(0xFFF1F5F9);
      fg = AppColors.textSecondary;
      label = preOpReady ? 'Ready to send to OT Assistant?' : 'Save Ready + OT Assistant first';
    } else {
      bg = AppColors.orangeA12;
      fg = AppColors.orange;
      label = 'Current status: ${status.toUpperCase()}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        Icon(status == 'ready' ? Icons.check_circle_outline : Icons.info_outline, size: 18, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
        if (showButton)
          ElevatedButton.icon(
            onPressed: _sendingReady ? null : _sendToOtAssistant,
            icon: _sendingReady ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 15),
            label: const Text('READY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
      ]),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(
          title: 'Patient Status',
          icon: Icons.assignment_turned_in_outlined,
          trailing: _canWriteVitals ? TextButton.icon(onPressed: _openStatusDialog, icon: const Icon(Icons.edit_outlined, size: 14), label: const Text('Save Status', style: TextStyle(fontSize: 12))) : null,
        ),
        Text('Pre-op status: ${otPreOpStatusLabel(_vitals?.preOpStatus ?? 'preparing')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Doctor: ${_header?.otDoctor?.name ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text('OT Assistant: ${_header?.otAssistant?.name ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildVitalsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(
          title: 'Vitals',
          icon: Icons.monitor_heart_outlined,
          trailing: _canWriteVitals
              ? TextButton.icon(onPressed: _openVitalsDialog, icon: const Icon(Icons.edit_outlined, size: 14), label: Text(_vitals == null ? 'Record' : 'Update', style: const TextStyle(fontSize: 12)))
              : null,
        ),
        if (_vitals == null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No vitals recorded yet.', style: TextStyle(color: AppColors.textSecondary)))
        else ...[
          Row(children: [
            Expanded(child: Text('Status: ${otPreOpStatusLabel(_vitals!.preOpStatus)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            if (_vitals!.enteredBy != null) Text('by ${_vitals!.enteredBy!.name}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const Divider(height: 20),
          Wrap(spacing: 20, runSpacing: 10, children: [
            _vitalStat('BP', _vitals!.bp ?? '—'),
            _vitalStat('Pulse', _vitals!.pulse?.toString() ?? '—'),
            _vitalStat('RBS', _vitals!.rbs?.toString() ?? '—'),
            _vitalStat('Temp', _vitals!.temperature?.toString() ?? '—'),
            _vitalStat('SpO2', _vitals!.spo2?.toString() ?? '—'),
            _vitalStat('HbA1c', _vitals!.hba1c?.toString() ?? '—'),
          ]),
        ],
      ]),
    );
  }

  Widget _vitalStat(String label, String value) => SizedBox(
        width: 90,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _buildEyeDropsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(
          title: 'Eye Drops',
          icon: Icons.water_drop_outlined,
          trailing: _canWriteDrops ? TextButton.icon(onPressed: _openEyeDropDialog, icon: const Icon(Icons.add_rounded, size: 14), label: const Text('Log Dose', style: TextStyle(fontSize: 12))) : null,
        ),
        if (_eyeDrops.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No doses logged yet.', style: TextStyle(color: AppColors.textSecondary)))
        else
          ..._eyeDrops.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.tealA12, borderRadius: BorderRadius.circular(AppRadius.sm)), child: Text('#${d.doseNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.tealDark))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.medicineName} · ${d.eye}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        if (d.remarks != null && d.remarks!.isNotEmpty) Text(d.remarks!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ),
                    if (d.administeredAt != null) Text(d.administeredAt!, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ]),
                ),
              )),
      ]),
    );
  }
}
