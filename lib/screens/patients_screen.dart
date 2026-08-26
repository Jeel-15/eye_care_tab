import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/exam_masters_service.dart';
import '../services/patient_service.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_animations.dart';
import '../widgets/exam/dilation_lock.dart';
import '../widgets/skeleton.dart';
import 'opd_bill_screen.dart';
import 'patient_checkin_screen.dart';
import 'patient_form_screen.dart';
import 'patient_history_screen.dart';
import 'primary_exam_screen.dart';
import 'secondary_exam_screen.dart';

/// Tablet Patients module — Pattern A (list + detail split). Left pane:
/// search, stat cards, paginated list. Right pane: selected patient detail,
/// or the add/edit form (Pattern C) when in edit mode. Business logic
/// (fetch/cache/search/paginate) ported from
/// eye_care_app/lib/screens/patients_screen.dart.
///
/// Check-in, Print and Exam actions are stubbed pending later phases (see
/// EYE_CARE_TAB_PRD.md §8) — Patient History is stubbed pending its own
/// follow-up within Phase 3.
class PatientsScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const PatientsScreen({super.key, required this.user, required this.hospital});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

enum _PaneMode { view, addWalkIn, addPhone, edit, history }

class _PatientsScreenState extends State<PatientsScreen> {
  bool _showAll = false;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  List<Patient> _patients = [];
  PatientStats? _stats;
  PatientMeta? _meta;
  bool _isLoading = false;
  bool _refreshing = false;
  String? _error;
  int _currentPage = 1;

  int? _selectedId;
  _PaneMode _paneMode = _PaneMode.view;

  @override
  void initState() {
    super.initState();
    _goToPage(1);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) ExamMastersService.instance.prewarm();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    if (_isLoading) return;
    if (page == 1 && _patients.isEmpty && _search.isEmpty) {
      final cached = await PatientService.instance.getCachedPatients(showAll: _showAll);
      if (cached != null && mounted) {
        setState(() {
          _patients = cached.patients;
          _stats = cached.stats;
          _meta = cached.meta;
        });
      }
    }
    final hasData = _patients.isNotEmpty;
    setState(() {
      _isLoading = !hasData;
      _refreshing = hasData;
      _error = null;
      _currentPage = page;
    });
    try {
      final result = await PatientService.instance.fetchPatients(showAll: _showAll, search: _search, page: page);
      if (!mounted) return;
      setState(() {
        _patients = result.patients;
        _stats = result.stats;
        _meta = result.meta;
      });
    } catch (e) {
      if (mounted && _patients.isEmpty) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _toggleShowAll(bool showAll) {
    if (_showAll == showAll) return;
    setState(() {
      _showAll = showAll;
      _patients = [];
      _meta = null;
      _stats = null;
    });
    _goToPage(1);
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search != val) {
        setState(() => _search = val);
        _goToPage(1);
      }
    });
  }

  void _selectPatient(Patient p) {
    setState(() {
      _selectedId = p.id;
      _paneMode = _PaneMode.view;
    });
  }

  void _openAdd(_PaneMode mode) => setState(() => _paneMode = mode);

  void _openEdit(Patient p) => setState(() {
        _selectedId = p.id;
        _paneMode = _PaneMode.edit;
      });

  void _onFormSaved(Patient saved) {
    setState(() {
      _paneMode = _PaneMode.view;
      _selectedId = saved.id;
    });
    _goToPage(_currentPage);
    showAppSnackBar(context, 'Saved.', isSuccess: true);
  }

  void _cancelForm() => setState(() => _paneMode = _PaneMode.view);

  void _openHistory(Patient p) => setState(() {
        _selectedId = p.id;
        _paneMode = _PaneMode.history;
      });

  Future<void> _openCheckin(Patient p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PatientCheckinScreen(
        user: widget.user,
        hospital: widget.hospital,
        patient: p,
        onCancel: () => Navigator.pop(context),
        onDone: (updated) {
          Navigator.pop(context);
          _goToPage(_currentPage);
          Navigator.of(context, rootNavigator: true).push(appRoute(OpdBillScreen(user: widget.user, hospital: widget.hospital, patient: updated)));
        },
      ),
    );
  }

  void _openPrintBill(Patient p) {
    Navigator.of(context, rootNavigator: true).push(appRoute(OpdBillScreen(user: widget.user, hospital: widget.hospital, patient: p)));
  }

  Future<void> _deletePatient(Patient p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient?'),
        content: Text('Delete ${p.fullName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: AppColors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await PatientService.instance.deletePatient(p.id);
      if (mounted) {
        showAppSnackBar(context, 'Patient deleted.', isSuccess: true);
        if (_selectedId == p.id) setState(() => _selectedId = null);
        _goToPage(_currentPage);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  void _notReady(String label) => showAppSnackBar(context, '$label — not built yet', duration: const Duration(seconds: 2));

  Future<void> _openPrimaryExam(Patient p) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(PrimaryExamScreen(user: widget.user, hospital: widget.hospital, patient: p)),
    );
    if (result == true && mounted) _goToPage(_currentPage);
  }

  Future<void> _openSecondaryExam(Patient p) async {
    final ok = await canStartSecondaryExam(context, p.unlockTimeMs);
    if (!ok || !mounted) return;
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      appRoute(SecondaryExamScreen(user: widget.user, hospital: widget.hospital, patient: p)),
    );
    if (result == true && mounted) _goToPage(_currentPage);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final splitView = constraints.maxWidth >= AppBreakpoints.medium;
      final listPane = _buildListPane();
      final detailPane = _buildDetailPane();

      if (!splitView) {
        return _selectedId != null || _paneMode != _PaneMode.view
            ? Column(children: [
                TextButton.icon(onPressed: () => setState(() { _selectedId = null; _paneMode = _PaneMode.view; }), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('Back to list')),
                Expanded(child: detailPane),
              ])
            : listPane;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 400, child: listPane),
          const SizedBox(width: 20),
          Expanded(child: detailPane),
        ],
      );
    });
  }

  // ── List pane ────────────────────────────────────────────────────────

  Widget _buildListPane() {
    final p = PermissionService.instance;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text('Patients', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Spacer(),
              if (p.can(Perm.opdPatientRegister))
                IconButton(icon: Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20), tooltip: 'New Walk-in', onPressed: () => _openAdd(_PaneMode.addWalkIn)),
              if (p.can(Perm.opdPatientRegisterPhone))
                IconButton(icon: Icon(Icons.phone_in_talk_rounded, color: AppColors.primary, size: 20), tooltip: 'Phone Appointment', onPressed: () => _openAdd(_PaneMode.addPhone)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _segmentedToggle(),
          ),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildStatCards()),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildSearchBar()),
          const SizedBox(height: 6),
          if (_refreshing) LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, color: AppColors.primary),
          Expanded(child: _buildList()),
          if (_meta != null) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _segmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        Expanded(child: _segBtn('Today', !_showAll, () => _toggleShowAll(false))),
        Expanded(child: _segBtn('All Patients', _showAll, () => _toggleShowAll(true))),
      ]),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.sm)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildStatCards() {
    final s = _stats;
    return Row(children: [
      Expanded(child: _statChip('Total', s?.total ?? 0, AppColors.primary)),
      const SizedBox(width: 8),
      Expanded(child: _statChip('Waiting', s?.waiting ?? 0, AppColors.orange)),
      const SizedBox(width: 8),
      Expanded(child: _statChip('Done', s?.completed ?? 0, AppColors.green)),
    ]);
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search name, MRD or contact...',
        hintStyle: TextStyle(fontSize: 13, color: AppColors.primaryA45),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryA55, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primaryA55, size: 18), onPressed: () {
                _searchCtrl.clear();
                _onSearchChanged('');
              })
            : null,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) return const AppSkeletonList();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => _goToPage(_currentPage), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Retry')),
          ]),
        ),
      );
    }
    if (_patients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.primaryA22),
            const SizedBox(height: 10),
            Text(_search.isNotEmpty ? 'No results match your search.' : 'No patients found.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _patients.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.primaryA08),
      itemBuilder: (_, i) {
        final p = _patients[i];
        return _PatientListTile(patient: p, selected: p.id == _selectedId, onTap: () => _selectPatient(p));
      },
    );
  }

  Widget _buildPaginationBar() {
    final meta = _meta!;
    final lastPage = meta.lastPage;
    if (lastPage <= 1) return const SizedBox(height: 8);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.primaryA08))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), iconSize: 20, onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null),
        Text('Page $_currentPage / $lastPage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), iconSize: 20, onPressed: _currentPage < lastPage ? () => _goToPage(_currentPage + 1) : null),
      ]),
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.addWalkIn || _paneMode == _PaneMode.addPhone) {
      return _panelBox(
        child: PatientFormScreen(mode: _paneMode == _PaneMode.addWalkIn ? PatientFormMode.addWalkIn : PatientFormMode.addPhone, user: widget.user, hospital: widget.hospital, onSaved: _onFormSaved, onCancel: _cancelForm),
      );
    }
    final selected = _patients.where((p) => p.id == _selectedId).firstOrNull;
    if (_paneMode == _PaneMode.edit && selected != null) {
      return _panelBox(
        child: PatientFormScreen(mode: PatientFormMode.edit, patient: selected, user: widget.user, hospital: widget.hospital, onSaved: _onFormSaved, onCancel: _cancelForm),
      );
    }
    if (_paneMode == _PaneMode.history && selected != null) {
      return _panelBox(
        child: PatientHistoryScreen(user: widget.user, hospital: widget.hospital, patient: selected, onBack: () => setState(() => _paneMode = _PaneMode.view), onNotReady: _notReady),
      );
    }
    if (selected == null) {
      return _panelBox(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_rounded, size: 56, color: AppColors.primaryA22),
            const SizedBox(height: 12),
            Text('Select a patient to view details', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          ]),
        ),
      );
    }
    return _panelBox(child: _PatientDetailView(patient: selected, onEdit: () => _openEdit(selected), onDelete: () => _deletePatient(selected), onHistory: () => _openHistory(selected), onCheckin: () => _openCheckin(selected), onPrimaryExam: () => _openPrimaryExam(selected), onSecondaryExam: () => _openSecondaryExam(selected), onPrintBill: () => _openPrintBill(selected), onNotReady: _notReady));
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

class _PatientListTile extends StatelessWidget {
  final Patient patient;
  final bool selected;
  final VoidCallback onTap;

  const _PatientListTile({required this.patient, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final subtitle = [if (p.age != null) '${p.age}y', if (p.gender != null) p.genderDisplay, if (p.contactNo != null) p.contactNo!].join(' · ');
    final (statusLabel, statusColor) = switch (p.status) {
      PatientStatus.completed => ('Completed', AppColors.teal),
      PatientStatus.primaryDone => ('Primary Done', AppColors.primary),
      PatientStatus.waiting => ('Waiting', AppColors.orange),
    };
    return Material(
      color: selected ? AppColors.primaryA08 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(p.firstName.isNotEmpty ? p.firstName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary), overflow: TextOverflow.ellipsis),
                Text([p.patientCode, if (subtitle.isNotEmpty) subtitle].join(' · '), style: TextStyle(fontSize: 11, color: AppColors.primaryA55), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: Text(statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Detail view ────────────────────────────────────────────────────────

class _PatientDetailView extends StatelessWidget {
  final Patient patient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final VoidCallback onCheckin;
  final VoidCallback onPrimaryExam;
  final VoidCallback onSecondaryExam;
  final VoidCallback onPrintBill;
  final void Function(String label) onNotReady;

  const _PatientDetailView({required this.patient, required this.onEdit, required this.onDelete, required this.onHistory, required this.onCheckin, required this.onPrimaryExam, required this.onSecondaryExam, required this.onPrintBill, required this.onNotReady});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final perm = PermissionService.instance;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(p.firstName.isNotEmpty ? p.firstName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip(p.patientCode, AppColors.primaryA10, AppColors.primary),
                  _statusChip(p.status),
                  if (p.age != null || p.gender != null) _chip([if (p.age != null) '${p.age}y', if (p.gender != null) p.genderDisplay].join(' · '), AppColors.primaryA07, AppColors.primary),
                ]),
              ]),
            ),
            Row(children: [
              if (perm.can(Perm.opdPatientEdit)) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', color: AppColors.primary),
              if (perm.can(Perm.opdPatientDelete)) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete', color: AppColors.red),
            ]),
          ]),
          const SizedBox(height: 20),
          _apptBar(p),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 560;
            final personal = _infoCard(bg: AppColors.primaryA06, title: 'Personal', items: [
              _InfoRow(Icons.work_outline_rounded, 'Occupation', p.occupation ?? '—'),
              _InfoRow(Icons.person_pin_outlined, 'Referrer', p.referrer?.name ?? '—'),
              _InfoRow(Icons.schedule_outlined, 'Registered', _fmtDate(p.createdAt)),
            ]);
            final contact = _infoCard(bg: AppColors.tealA06, title: 'Contact', items: [
              _InfoRow(Icons.phone_outlined, 'Phone', p.contactNo ?? '—'),
              _InfoRow(Icons.chat_outlined, 'WhatsApp', p.whatsappNo ?? '—'),
              _InfoRow(Icons.location_on_outlined, 'Location', p.location?.display ?? '—'),
            ]);
            return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: personal), const SizedBox(width: 14), Expanded(child: contact)]) : Column(children: [personal, const SizedBox(height: 14), contact]);
          }),
          const SizedBox(height: 16),
          _examCard(p),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (perm.can(Perm.opdExamPrimary) && p.primaryDoneAt == null) _actionBtn('Primary Exam', Icons.assignment_outlined, onPrimaryExam),
            if (perm.can(Perm.opdExamSecondary) && p.primaryDoneAt != null) _actionBtn('Secondary Exam', Icons.remove_red_eye_outlined, onSecondaryExam),
            if (perm.can(Perm.opdExamHistory)) _actionBtn('History', Icons.history_rounded, onHistory),
            if (perm.can(Perm.opdBillPrint)) _actionBtn('Print Bill', Icons.print_outlined, onPrintBill),
            if (perm.can(Perm.opdPatientRegister) && p.type == 'phone' && p.caseId == null) _actionBtn('Check-in', Icons.how_to_reg_rounded, onCheckin),
          ]),
        ],
      ),
    );
  }

  Widget _apptBar(Patient p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: AppColors.primaryA05, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        _apptItem(Icons.calendar_today_outlined, 'Appointment', p.appointmentDate ?? '—'),
        _apptDiv(),
        _apptItem(Icons.person_outline_rounded, 'Doctor', p.doctor?.name ?? '—'),
        _apptDiv(),
        _apptItem(Icons.category_outlined, 'Case', p.caseType?.caseType ?? '—'),
        _apptDiv(),
        _apptItem(Icons.currency_rupee_rounded, 'Fee', p.caseFee != null ? '₹${p.caseFee!.toInt()}' : '—'),
      ]),
    );
  }

  Widget _apptItem(IconData icon, String label, String value) => Expanded(
        child: Column(children: [
          Icon(icon, size: 15, color: AppColors.primaryA55),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primaryA55)),
          const SizedBox(height: 2),
          Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      );

  Widget _apptDiv() => Container(width: 1, height: 40, color: AppColors.primaryA12);

  Widget _infoCard({required Color bg, required String title, required List<_InfoRow> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primaryA60)),
          const SizedBox(height: 10),
          ...items.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.icon, size: 14, color: AppColors.primaryA55),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.label, style: TextStyle(fontSize: 10, color: AppColors.primaryA50)),
                      Text(r.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ]),
                  ),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _examCard(Patient p) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.primaryA04, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA10)),
        child: Row(children: [
          Expanded(child: _examStatus('PRIMARY', Icons.assignment_outlined, p.primaryDoneAt)),
          Container(width: 1, height: 64, color: AppColors.primaryA12),
          Expanded(child: _examStatus('SECONDARY', Icons.remove_red_eye_outlined, p.secondaryDoneAt)),
        ]),
      );

  Widget _examStatus(String title, IconData icon, DateTime? doneAt) {
    final done = doneAt != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: done ? AppColors.teal : Colors.grey.shade400, size: 30),
        const SizedBox(height: 5),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.primaryA60)),
        const SizedBox(height: 3),
        Text(done ? _fmtDate(doneAt) : 'Pending', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: done ? AppColors.teal : Colors.grey.shade400)),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primaryA22), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  Widget _statusChip(PatientStatus status) {
    final (label, bg, fg) = switch (status) {
      PatientStatus.completed => ('Completed', AppColors.tealA13, const Color(0xFF0E9E82)),
      PatientStatus.primaryDone => ('Primary Done', AppColors.primaryA13, AppColors.primary),
      PatientStatus.waiting => ('Waiting', AppColors.orangeA13, const Color(0xFFE67E22)),
    };
    return _chip(label, bg, fg);
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}
