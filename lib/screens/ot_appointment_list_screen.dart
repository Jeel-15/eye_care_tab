import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/date_format.dart';
import '../models/ot_appointment_models.dart';
import '../models/ot_booking_models.dart';
import '../services/masters_service.dart';
import '../services/ot_appointment_service.dart';
import '../services/ot_slot_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_pagination_bar.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/split_pane_scaffold.dart';
import '../widgets/status_badge.dart';

// Matches web's `optional($appointment->appointment_date)->format('d M Y')`
// exactly — web's index table has no time column at all, only this date.
String _fmtAppointmentDate(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return toDisplayDate(d);
}

/// Tablet OT Appointments — Round 3 Phase 2. Pattern A (list + detail split),
/// matching `PatientsScreen`/`PatientFormScreen` exactly — the floating
/// `AlertDialog` this screen used to open for New/Edit Appointment was
/// cramped and inconsistent with how every other "add an entity" flow in
/// this app works. See OT_WEB_PARITY_FIX_PRD.md §1.6.
class OtAppointmentListScreen extends StatefulWidget {
  const OtAppointmentListScreen({super.key});

  @override
  State<OtAppointmentListScreen> createState() => _OtAppointmentListScreenState();
}

enum _PaneMode { list, add, edit }

class _OtAppointmentListScreenState extends State<OtAppointmentListScreen> {
  static const _statuses = ['all', 'booked', 'confirmed', 'cancelled', 'completed'];

  final _searchCtrl = TextEditingController();
  List<OtAppointmentItem> _items = [];
  OtPaginationMeta? _meta;
  bool _loading = true;
  String? _error;
  String _status = 'all';
  DateTime? _dateFilter;
  int _page = 1;

  _PaneMode _paneMode = _PaneMode.list;
  OtAppointmentItem? _editingItem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _dateStr => _dateFilter == null ? null : toIsoDate(_dateFilter!);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await OtAppointmentService.instance.list(status: _status, date: _dateStr, search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), page: _page);
      if (mounted) setState(() { _items = result.items; _meta = result.meta; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDatePicker(context: context, initialDate: _dateFilter ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) { setState(() { _dateFilter = picked; _page = 1; }); _load(); }
  }

  Future<void> _confirm(OtAppointmentItem item) async {
    try {
      await OtAppointmentService.instance.confirm(item.id);
      if (mounted) showAppSnackBar(context, 'Appointment confirmed', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _cancel(OtAppointmentItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cancel appointment?'), content: Text('Cancel ${item.fullName}\'s appointment (${item.appointmentNumber})?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel Appointment', style: TextStyle(color: AppColors.red)))]));
    if (ok != true) return;
    try {
      await OtAppointmentService.instance.cancel(item.id);
      if (mounted) showAppSnackBar(context, 'Appointment cancelled', isSuccess: true);
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _openAdd() => setState(() { _paneMode = _PaneMode.add; _editingItem = null; });

  void _openEdit(OtAppointmentItem item) => setState(() { _paneMode = _PaneMode.edit; _editingItem = item; });

  void _onFormSaved() {
    setState(() => _paneMode = _PaneMode.list);
    _load();
  }

  void _cancelForm() => setState(() => _paneMode = _PaneMode.list);

  @override
  Widget build(BuildContext context) {
    return SplitPaneScaffold(
      showDetail: _paneMode != _PaneMode.list,
      onBack: _cancelForm,
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('OT Appointments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh'),
            IconButton(onPressed: _openAdd, icon: Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 26), tooltip: 'New Appointment'),
          ]),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildFilters()),
        const SizedBox(height: 8),
        Expanded(child: _buildBody()),
        if (_meta != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: AppPaginationBar(currentPage: _meta!.currentPage, totalPages: _meta!.lastPage, onPageChange: (p) { setState(() => _page = p); _load(); })),
      ]),
    );
  }

  Widget _buildFilters() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppSearchBar(controller: _searchCtrl, hint: 'Search by name, mobile, or APT number...', onChanged: (_) { setState(() => _page = 1); _load(); }, onClear: _load),
      const SizedBox(height: 8),
      SizedBox(
        height: 32,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final s in _statuses) ...[
            ChoiceChip(
              label: Text(s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1)),
              selected: _status == s,
              onSelected: (_) { setState(() { _status = s; _page = 1; }); _load(); },
              selectedColor: AppColors.primaryA15,
              labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _status == s ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
          ],
          ActionChip(
            avatar: Icon(Icons.event_rounded, size: 15, color: _dateFilter != null ? AppColors.primary : AppColors.textSecondary),
            label: Text(_dateFilter == null ? 'Any date' : _dateStr!, style: const TextStyle(fontSize: 11.5)),
            onPressed: _pickDateFilter,
          ),
          if (_dateFilter != null)
            IconButton(icon: const Icon(Icons.close_rounded, size: 15), onPressed: () { setState(() { _dateFilter = null; _page = 1; }); _load(); }),
        ]),
      ),
    ]);
  }

  Widget _buildBody() {
    if (_loading) return const AppSkeletonList(count: 6, itemHeight: 90);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    if (_items.isEmpty) return AppEmptyState(message: 'No appointments found.', icon: Icons.event_note_rounded, onRefresh: _load);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final item = _items[i];
        return AnimatedListItem(
          index: i,
          child: _AppointmentListTile(
            item: item,
            selected: _paneMode == _PaneMode.edit && _editingItem?.id == item.id,
            onTap: () => _openEdit(item),
            onConfirm: item.status == 'booked' ? () => _confirm(item) : null,
            onCancel: (item.status == 'booked' || item.status == 'confirmed') ? () => _cancel(item) : null,
          ),
        );
      },
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.add) {
      return _panelBox(child: _AppointmentFormPane(item: null, onSaved: _onFormSaved, onCancel: _cancelForm));
    }
    if (_paneMode == _PaneMode.edit && _editingItem != null) {
      return _panelBox(child: _AppointmentFormPane(item: _editingItem, onSaved: _onFormSaved, onCancel: _cancelForm));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Select "New Appointment" to book one,', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('or tap an appointment to edit it.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
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

// ── List tile ──────────────────────────────────────────────────────────

class _AppointmentListTile extends StatelessWidget {
  final OtAppointmentItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const _AppointmentListTile({required this.item, required this.selected, required this.onTap, this.onConfirm, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primaryA08)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.darkNavy)),
                  const SizedBox(height: 2),
                  Text('${item.appointmentNumber} · ${item.mobileNo}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ),
              StatusBadge.otAppointmentStatus(item.status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event_rounded, size: 12, color: AppColors.primary.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(_fmtAppointmentDate(item.appointmentDate), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              if (item.doctor != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.medical_services_outlined, size: 12, color: AppColors.primary.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Expanded(child: Text(item.doctor!.name, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
              ],
            ]),
            if (onConfirm != null || onCancel != null) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.primaryA08),
              const SizedBox(height: 8),
              Row(children: [
                if (onConfirm != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppColors.green),
                      label: const Text('Confirm', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9), side: BorderSide(color: AppColors.green.withValues(alpha: 0.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                    ),
                  ),
                  if (onCancel != null) const SizedBox(width: 8),
                ],
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 15, color: AppColors.red),
                      label: const Text('Cancel', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9), side: BorderSide(color: AppColors.red.withValues(alpha: 0.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Add / Edit form pane (Pattern C — matches PatientFormScreen's 2-column
// field grid, embedded in the detail pane, not a dialog) ───────────────────

class _AppointmentFormPane extends StatefulWidget {
  final OtAppointmentItem? item;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _AppointmentFormPane({required this.item, required this.onSaved, required this.onCancel});

  @override
  State<_AppointmentFormPane> createState() => _AppointmentFormPaneState();
}

class _AppointmentFormPaneState extends State<_AppointmentFormPane> {
  static const _types = ['phone', 'walk_in', 'online', 'referral'];
  static const _typeLabels = {'phone': 'Phone', 'walk_in': 'Walk-in', 'online': 'Online', 'referral': 'Referral'};
  static const _genders = ['male', 'female', 'other'];

  late final TextEditingController _nameCtrl, _middleCtrl, _surnameCtrl, _mobileCtrl, _whatsappCtrl, _ageCtrl, _occupationCtrl, _notesCtrl;
  String _type = 'walk_in';
  String _gender = 'male';
  DateTime? _date;
  OtSlotItem? _selectedSlot;
  int? _doctorId;
  int? _referrerId;
  int? _locationId;

  OtAppointmentFormData? _formData;
  bool _loadingForm = true;
  String? _formError;
  bool _saving = false;
  String? _nameErr, _surnameErr, _mobileErr, _ageErr, _dateErr, _doctorErr, _locationErr;

  List<OtSlotAppointmentConflict> _slotConflicts = [];
  bool _loadingSlot = false;

  // Matched against loaded slots once form data arrives (§1 field-order:
  // Appointment Time is a select of OtSlot rows on web, not a free time
  // picker — see OT_WEB_PARITY_FIX_PRD.md §1).
  String? _pendingSlotTime;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _nameCtrl = TextEditingController(text: it?.patientName ?? '');
    _middleCtrl = TextEditingController(text: it?.middleName ?? '');
    _surnameCtrl = TextEditingController(text: it?.surname ?? '');
    _mobileCtrl = TextEditingController(text: it?.mobileNo ?? '');
    _whatsappCtrl = TextEditingController(text: it?.whatsappNo ?? '');
    _ageCtrl = TextEditingController(text: it != null ? '${it.age}' : '');
    _occupationCtrl = TextEditingController(text: it?.occupation ?? '');
    _notesCtrl = TextEditingController(text: it?.notes ?? '');
    _type = it?.appointmentType ?? 'walk_in';
    _gender = it?.gender ?? 'male';
    _doctorId = it?.doctor?.id;
    _referrerId = it?.referrerId;
    _locationId = it?.location?.id;
    if (it != null && it.appointmentDate.isNotEmpty) _date = DateTime.tryParse(it.appointmentDate);
    _pendingSlotTime = it?.appointmentTime;
    _loadFormData();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _middleCtrl, _surnameCtrl, _mobileCtrl, _whatsappCtrl, _ageCtrl, _occupationCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final data = await OtAppointmentService.instance.fetchFormData();
      if (mounted) {
        setState(() {
          _formData = data;
          _loadingForm = false;
          if (_pendingSlotTime != null) {
            final match = data.slots.where((s) => _slotTimeStr(s) == _pendingSlotTime).toList();
            if (match.isNotEmpty) _selectedSlot = match.first;
          }
        });
        if (_date != null && _selectedSlot != null) _refreshSlotConflicts();
      }
    } catch (e) {
      if (mounted) setState(() { _formError = e.toString().replaceFirst('Exception: ', ''); _loadingForm = false; });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: widget.item == null ? now : now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) {
      setState(() { _date = picked; _dateErr = null; });
      _refreshSlotConflicts();
    }
  }

  /// Raw `HH:mm` (matches web's `Carbon::parse($slot->start_time)->format('H:i')`
  /// stored value) derived from the slot's start time — `null`/short values
  /// return null so a slot with no configured start time is never selectable
  /// as a time filter.
  String? _slotTimeStr(OtSlotItem s) => (s.startTime != null && s.startTime!.length >= 5) ? s.startTime!.substring(0, 5) : null;

  /// 12-hour display clock ("09:00 AM") matching web's `format('h:i A')`.
  String _fmtClock(String? raw) {
    if (raw == null || raw.length < 5) return '';
    final h = int.tryParse(raw.substring(0, 2)) ?? 0;
    final m = raw.substring(3, 5);
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $period';
  }

  String _slotLabel(OtSlotItem s) => s.startTime != null && s.endTime != null ? '${s.slotName} (${_fmtClock(s.startTime)} - ${_fmtClock(s.endTime)})' : s.slotName;

  /// On Date + Time change, shows a chip list of patients already booked in
  /// that exact slot — mirrors web's AJAX slot-occupancy panel (hidden if
  /// none). See OT_WEB_PARITY_FIX_PRD.md §1.1.
  Future<void> _refreshSlotConflicts() async {
    final timeStr = _selectedSlot != null ? _slotTimeStr(_selectedSlot!) : null;
    if (_date == null || timeStr == null) {
      setState(() => _slotConflicts = []);
      return;
    }
    final dateStr = toIsoDate(_date!);
    setState(() => _loadingSlot = true);
    try {
      final conflicts = await OtAppointmentService.instance.slotAppointments(date: dateStr, time: timeStr, excludeId: widget.item?.id);
      if (mounted) setState(() { _slotConflicts = conflicts; _loadingSlot = false; });
    } catch (_) {
      if (mounted) setState(() { _slotConflicts = []; _loadingSlot = false; });
    }
  }

  Future<void> _addCity() async {
    final cityCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.blueLight], begin: Alignment.centerLeft, end: Alignment.centerRight), borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
          child: Row(children: [
            const Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Add City', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(ctx, false)),
          ]),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: distCtrl, decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || cityCtrl.text.trim().isEmpty) return;
    try {
      final loc = await MastersService.instance.addLocation(city: cityCtrl.text.trim(), district: distCtrl.text.trim(), state: stateCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _formData = OtAppointmentFormData(
          doctors: _formData!.doctors,
          locations: [..._formData!.locations, OtAppointmentLocation(id: loc.id, name: loc.city, district: loc.district, state: loc.state)],
          referrers: _formData!.referrers,
          slots: _formData!.slots,
          nextAppointmentNumber: _formData!.nextAppointmentNumber,
        );
        _locationId = loc.id;
        _locationErr = null;
      });
      showAppSnackBar(context, 'City "${loc.city}" added.', isSuccess: true);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _save() async {
    final age = int.tryParse(_ageCtrl.text.trim());
    setState(() {
      _nameErr = _nameCtrl.text.trim().isEmpty ? 'Required' : null;
      _surnameErr = _surnameCtrl.text.trim().isEmpty ? 'Required' : null;
      _mobileErr = _mobileCtrl.text.trim().isEmpty ? 'Required' : null;
      _ageErr = age == null ? 'Invalid' : null;
      _dateErr = _date == null ? 'Required' : null;
      _doctorErr = _doctorId == null ? 'Select a doctor' : null;
      _locationErr = _locationId == null ? 'Select a location' : null;
    });
    if ([_nameErr, _surnameErr, _mobileErr, _ageErr, _dateErr, _doctorErr, _locationErr].any((e) => e != null)) return;

    setState(() => _saving = true);
    try {
      final body = {
        'appointment_type': _type,
        'appointment_date': toIsoDate(_date!),
        if (_selectedSlot != null) 'appointment_time': _slotTimeStr(_selectedSlot!),
        'doctor_id': _doctorId,
        'patient_name': _nameCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'mobile_no': _mobileCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim(),
        'age': age,
        'gender': _gender,
        'occupation': _occupationCtrl.text.trim(),
        if (_referrerId != null) 'referrer_id': _referrerId,
        'location_id': _locationId,
        'notes': _notesCtrl.text.trim(),
      };
      if (widget.item == null) {
        await OtAppointmentService.instance.create(body);
      } else {
        await OtAppointmentService.instance.update(widget.item!.id, body);
      }
      if (mounted) showAppSnackBar(context, 'Saved.', isSuccess: true);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  // ── Layout helpers (matches PatientFormScreen's Pattern C field grid) ────

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 520) return Column(children: [a, b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _field(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
        const SizedBox(height: 5),
        child,
      ]),
    );
  }

  InputDecoration _deco(String label, {String? error, String? suffix}) => InputDecoration(
        hintText: label,
        errorText: error,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Cancel'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(isEdit ? Icons.edit_rounded : Icons.event_note_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEdit ? 'Edit Appointment' : 'New Appointment', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(isEdit ? 'Update appointment details' : 'Pre-registration — patient hasn\'t arrived yet', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loadingForm
            ? const AppSkeletonList(count: 5, itemHeight: 60)
            : _formError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
                        const SizedBox(height: 12),
                        Text(_formError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(onPressed: () { setState(() => _loadingForm = true); _loadFormData(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary)),
                      ]),
                    ),
                  )
                : SingleChildScrollView(child: _buildForm()),
      ),
    ]);
  }

  Widget _buildForm() {
    final formData = _formData!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field('Appointment Type *', Wrap(spacing: 8, children: _types.map((t) => ChoiceChip(label: Text(_typeLabels[t]!), selected: _type == t, onSelected: (_) => setState(() => _type = t))).toList())),
      _row2(
        _field('Date *', InkWell(onTap: _pickDate, child: InputDecorator(decoration: _deco('Select', error: _dateErr), child: Text(_date == null ? 'Select' : toIsoDate(_date!))))),
        _field(
          'Time',
          DropdownButtonFormField<OtSlotItem>(
            initialValue: _selectedSlot,
            isExpanded: true,
            decoration: _deco('Select slot...'),
            items: formData.slots.map((s) => DropdownMenuItem(value: s, child: Text(_slotLabel(s), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) {
              setState(() => _selectedSlot = v);
              _refreshSlotConflicts();
            },
          ),
        ),
      ),
      if (_loadingSlot || _slotConflicts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14, top: -6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _loadingSlot
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Wrap(spacing: 6, runSpacing: 6, children: [
                    const Padding(padding: EdgeInsets.only(right: 2), child: Text('Already booked:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                    ..._slotConflicts.map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.orangeA12, borderRadius: BorderRadius.circular(AppRadius.full)),
                          child: Text(c.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.orange)),
                        )),
                  ]),
          ),
        ),
      _field(
        'Doctor *',
        DropdownButtonFormField<int>(
          initialValue: _doctorId,
          isExpanded: true,
          decoration: _deco('Select doctor...', error: _doctorErr),
          items: formData.doctors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() { _doctorId = v; _doctorErr = null; }),
        ),
      ),
      _row2(
        _field('First Name *', TextFormField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, decoration: _deco('First Name', error: _nameErr))),
        _field('Surname *', TextFormField(controller: _surnameCtrl, textCapitalization: TextCapitalization.words, decoration: _deco('Surname', error: _surnameErr))),
      ),
      _row2(
        _field('Middle Name', TextFormField(controller: _middleCtrl, textCapitalization: TextCapitalization.words, decoration: _deco('Middle Name'))),
        _field('Occupation', TextFormField(controller: _occupationCtrl, decoration: _deco('Occupation'))),
      ),
      _row2(
        _field('Mobile No *', TextFormField(controller: _mobileCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Mobile No', error: _mobileErr))),
        _field('WhatsApp No', TextFormField(controller: _whatsappCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Same if blank'))),
      ),
      _row2(
        _field('Age *', TextFormField(controller: _ageCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Age', error: _ageErr))),
        _field(
          'Gender *',
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: _deco('Gender'),
            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g[0].toUpperCase() + g.substring(1)))).toList(),
            onChanged: (v) => setState(() => _gender = v ?? _gender),
          ),
        ),
      ),
      _field(
        'City *',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addCity,
              icon: Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
              label: Text('Add City', style: TextStyle(fontSize: 12, color: AppColors.primary)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), minimumSize: Size.zero),
            ),
          ),
          DropdownButtonFormField<int>(
            initialValue: _locationId,
            isExpanded: true,
            decoration: _deco('Select city...', error: _locationErr),
            items: formData.locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() { _locationId = v; _locationErr = null; }),
          ),
        ]),
      ),
      if (_locationId != null)
        Builder(builder: (_) {
          final loc = formData.locations.where((l) => l.id == _locationId).toList();
          if (loc.isEmpty) return const SizedBox.shrink();
          return _row2(
            _field('District', TextFormField(enabled: false, controller: TextEditingController(text: loc.first.district ?? '—'), decoration: _deco('District'))),
            _field('State', TextFormField(enabled: false, controller: TextEditingController(text: loc.first.state ?? '—'), decoration: _deco('State'))),
          );
        }),
      _field(
        'Referred By',
        DropdownButtonFormField<int?>(
          initialValue: _referrerId,
          isExpanded: true,
          decoration: _deco('Select referrer...'),
          items: [const DropdownMenuItem(value: null, child: Text('None')), ...formData.referrers.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis)))],
          onChanged: (v) => setState(() => _referrerId = v),
        ),
      ),
      _field('Notes', TextFormField(controller: _notesCtrl, maxLines: 3, decoration: _deco('Notes'))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)), side: BorderSide(color: AppColors.primaryA22)),
          child: const Text('Cancel'),
        ),
      ]),
      const SizedBox(height: 8),
    ]);
  }
}
