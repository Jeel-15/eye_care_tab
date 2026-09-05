import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/date_format.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_counsellor_models.dart';
import '../models/ot_inventory_models.dart';
import '../services/ot_accountant_service.dart';
import '../services/ot_counsellor_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/split_pane_scaffold.dart';
import '../widgets/skeleton.dart';
import '../widgets/ot/signature_pad_field.dart';
import '../utils/currency_format.dart';

/// Tablet OT Counsellor Dashboard (Round 3 Phase 1) — Pattern A (list +
/// detail split), matching `PatientsScreen`/`OtAppointmentListScreen` — the
/// full-screen push this used to open for "Awaiting Counselling" felt like
/// leaving the tablet app entirely and wasted the wide-screen space (a
/// centered narrow form with big blank gutters either side). See
/// OT_WEB_PARITY_FIX_PRD.md §3.4. Web has two tables: "Awaiting Counselling"
/// (tappable, own queue) and read-only "Payment Status".
///
/// **Known gap:** no dedicated endpoint returns the Payment Status queue —
/// reusing the Accountant "completed" queue as the closest substitute.
class OtCounsellorDashboardScreen extends StatefulWidget {
  const OtCounsellorDashboardScreen({super.key});

  @override
  State<OtCounsellorDashboardScreen> createState() => _OtCounsellorDashboardScreenState();
}

enum _PaneMode { list, counselling, consent }

class _OtCounsellorDashboardScreenState extends State<OtCounsellorDashboardScreen> {
  List<OtBookingSummary> _awaiting = [];
  List<OtBookingSummary> _paymentStatus = [];
  bool _loading = true;
  String? _error;

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
      // Not Future.wait([...]) — the two services' fetchBookings() now
      // return differently-shaped records (OtAccountantService's gained a
      // moneySummary field for the Refunds feature), so a homogeneous list
      // can't statically type them. Starting both futures before awaiting
      // either keeps this just as concurrent.
      final awaitingFuture = OtCounsellorService.instance.fetchBookings();
      final paymentStatusFuture = OtAccountantService.instance.fetchBookings(filter: 'completed');
      final awaiting = await awaitingFuture;
      final paymentStatus = await paymentStatusFuture;
      if (mounted) {
        setState(() {
          _awaiting = awaiting.items;
          _paymentStatus = paymentStatus.items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _openCounselling(OtBookingSummary item) => setState(() { _paneMode = _PaneMode.counselling; _selected = item; });

  void _goToConsent() => setState(() => _paneMode = _PaneMode.consent);

  void _backToCounselling() => setState(() => _paneMode = _PaneMode.counselling);

  void _finishFlow() {
    setState(() { _paneMode = _PaneMode.list; _selected = null; });
    _load();
  }

  void _closePane() {
    setState(() { _paneMode = _PaneMode.list; _selected = null; });
  }

  // Matches web's `optional($booking->surgery_date)->format('d M Y')` exactly.
  static String? _fmtDate(String? raw) {
    if (raw == null) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return toDisplayDate(d);
  }

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('OT Counsellor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
            IconButton(onPressed: _loading ? null : _load, icon: Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20), tooltip: 'Refresh'),
          ]),
        ),
        Expanded(
          child: _loading
              ? const AppSkeletonList(count: 6, itemHeight: 80)
              : _error != null
                  ? AppErrorState(message: _error!, onRetry: _load)
                  : _buildBody(),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: [
      const _SectionLabel('Awaiting Counselling'),
      if (_awaiting.isEmpty) const _EmptyRow('No bookings awaiting counselling.') else ..._awaiting.map((i) => _bookingRow(i, tappable: true)),
      const SizedBox(height: 24),
      const _SectionLabel('Payment Status', subtitle: 'Bookings billing has taken payment on'),
      if (_paymentStatus.isEmpty) const _EmptyRow('No bookings yet.') else ..._paymentStatus.map((i) => _bookingRow(i, tappable: false)),
    ]);
  }

  Widget _bookingRow(OtBookingSummary item, {required bool tappable}) {
    final recommended = item.otStatus == OtStatus.surgeryRecommended;
    final selected = tappable && _paneMode != _PaneMode.list && _selected?.id == item.id;
    final date = _fmtDate(item.surgeryDate);
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: selected ? AppColors.primaryA08 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.4) : recommended ? AppColors.orange.withValues(alpha: 0.35) : AppColors.primaryA08)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.patient?.fullName ?? 'Patient', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${item.patient?.patientCode ?? ''}${item.eye != null ? ' · ${item.eye}' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
          if (tappable && recommended)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.orangeA12, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Text('Recommended', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.orange)))
          else if (!tappable)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (item.otStatus == OtStatus.paid ? AppColors.orange : AppColors.green).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Text(item.otStatus == OtStatus.paid ? 'Paid' : 'Complete', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: item.otStatus == OtStatus.paid ? AppColors.orange : AppColors.green))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (item.patient?.contactNo != null) ...[Icon(Icons.call_rounded, size: 12, color: AppColors.primary.withValues(alpha: 0.5)), const SizedBox(width: 4), Text(item.patient!.contactNo!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))],
          if (date != null) ...[const SizedBox(width: 10), Icon(Icons.event_rounded, size: 12, color: AppColors.primary.withValues(alpha: 0.5)), const SizedBox(width: 4), Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))],
        ]),
        if (tappable && (item.otDoctor != null || item.otType != null)) ...[
          const SizedBox(height: 4),
          Row(children: [
            if (item.otDoctor != null) ...[Icon(Icons.medical_services_outlined, size: 12, color: AppColors.primary.withValues(alpha: 0.5)), const SizedBox(width: 4), Text('Dr. ${item.otDoctor!.name}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)],
            if (item.otType != null) ...[const SizedBox(width: 10), Expanded(child: Text(item.otType!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis))],
          ]),
        ],
        if (!tappable && item.packageAmount != null) ...[
          const SizedBox(height: 4),
          Text('${currentCurrencySymbol()}${item.packageAmount!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: tappable ? InkWell(onTap: () => _openCounselling(item), borderRadius: BorderRadius.circular(AppRadius.md), child: row) : row,
    );
  }

  // ── Detail pane ─────────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    if (_paneMode == _PaneMode.counselling && _selected != null) {
      return _panelBox(child: _CounsellingFormPane(key: ValueKey('counselling-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', onSaved: _goToConsent, onCancel: _closePane));
    }
    if (_paneMode == _PaneMode.consent && _selected != null) {
      return _panelBox(child: _ConsentFormPane(key: ValueKey('consent-${_selected!.id}'), bookingId: _selected!.id, patientName: _selected!.patient?.fullName ?? 'Patient', onBack: _backToCounselling, onDone: _finishFlow));
    }
    return _panelBox(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.support_agent_rounded, size: 56, color: AppColors.primaryA22),
          const SizedBox(height: 12),
          Text('Tap a booking under "Awaiting Counselling"', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
          Text('to begin counselling.', style: TextStyle(fontSize: 13, color: AppColors.primaryA55)),
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

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionLabel(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String message;
  const _EmptyRow(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );
}

// ── Counselling form pane (embedded in the detail pane, not a full screen)
// — matches _AppointmentFormPane's header/body vocabulary exactly. ─────────

class _CounsellingFormPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _CounsellingFormPane({super.key, required this.bookingId, required this.patientName, required this.onSaved, required this.onCancel});

  @override
  State<_CounsellingFormPane> createState() => _CounsellingFormPaneState();
}

class _CounsellingFormPaneState extends State<_CounsellingFormPane> {
  static final _genFmt = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];

  bool _loading = true;
  String? _loadError;
  OtCounsellingDetail? _detail;
  bool _saving = false;

  int? _selectedPackageId;

  late final TextEditingController _diagnosisCtrl, _lensCompanyCtrl, _lensModelCtrl, _estimatedPowerCtrl, _lensCostCtrl, _packageNameCtrl, _otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl, _notesCtrl;
  String _eye = 'Both';
  // Replaces the old surgery_type_confirmed checkbox — required, matches
  // web exactly. See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  String? _otType;
  bool _mediclaim = false;
  String _lensCategory = 'standard';
  String? _lensType;
  String _roomCategory = 'general';
  String _paymentMode = 'cash';
  // Now required on web (was optional) — null until the user actively
  // answers, so "not yet answered" is distinguishable from "No".
  bool? _bloodReportsVerified;
  bool? _bloodReportsNormal;

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl = TextEditingController();
    _lensCompanyCtrl = TextEditingController();
    _lensModelCtrl = TextEditingController();
    _estimatedPowerCtrl = TextEditingController();
    _lensCostCtrl = TextEditingController(text: '0');
    _packageNameCtrl = TextEditingController();
    _otChargesCtrl = TextEditingController(text: '0');
    _surgeonChargesCtrl = TextEditingController(text: '0');
    _nursingChargesCtrl = TextEditingController(text: '0');
    _consumablesChargesCtrl = TextEditingController(text: '0');
    _notesCtrl = TextEditingController();
    for (final c in [_otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl, _lensCostCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_diagnosisCtrl, _lensCompanyCtrl, _lensModelCtrl, _estimatedPowerCtrl, _lensCostCtrl, _packageNameCtrl, _otChargesCtrl, _surgeonChargesCtrl, _nursingChargesCtrl, _consumablesChargesCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalEstimate =>
      (double.tryParse(_otChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_surgeonChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_nursingChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_consumablesChargesCtrl.text.trim()) ?? 0) +
      (double.tryParse(_lensCostCtrl.text.trim()) ?? 0);

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final detail = await OtCounsellorService.instance.fetchCounsellingDetail(widget.bookingId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
          _eye = detail.counselling?.eye ?? detail.booking.eye ?? 'Both';
          final c = detail.counselling;
          if (c != null) {
            _diagnosisCtrl.text = c.diagnosis ?? '';
            _otType = c.otType;
            _mediclaim = c.mediclaim;
            _lensCategory = c.lensCategory ?? 'standard';
            _lensCompanyCtrl.text = c.lensCompany ?? '';
            _lensModelCtrl.text = c.lensModel ?? '';
            _lensType = c.lensType;
            _estimatedPowerCtrl.text = c.estimatedPower?.toString() ?? '';
            _lensCostCtrl.text = c.lensCost?.toString() ?? '0';
            _packageNameCtrl.text = c.packageName ?? '';
            _roomCategory = c.roomCategory;
            _otChargesCtrl.text = c.otCharges.toString();
            _surgeonChargesCtrl.text = c.surgeonCharges.toString();
            _nursingChargesCtrl.text = c.nursingCharges.toString();
            _consumablesChargesCtrl.text = c.consumablesCharges.toString();
            _paymentMode = c.mediclaim ? 'cash' : c.paymentMode;
            _bloodReportsVerified = c.bloodReportsVerified;
            _bloodReportsNormal = c.bloodReportsNormal;
            _notesCtrl.text = c.notes ?? '';
            // Best-effort: pre-select the matching package option by name +
            // room category (lens_cost is no longer a meaningful match key).
            final match = detail.packageCostOptions.where((p) => p.packageName == c.packageName && p.roomCategory == c.roomCategory).toList();
            if (match.isNotEmpty) _selectedPackageId = match.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  /// Selecting a package auto-fills package name, room category, and all 4
  /// charge fields — but NOT lens cost, which is a manually-typed field,
  /// fully decoupled from the package (web pull 2026-08-07). See
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
  void _selectPackage(OtPackageMasterItem pkg) {
    setState(() {
      _selectedPackageId = pkg.id;
      _roomCategory = pkg.roomCategory;
      _packageNameCtrl.text = pkg.packageName;
      _otChargesCtrl.text = pkg.otCharges.toString();
      _surgeonChargesCtrl.text = pkg.surgeonCharges.toString();
      _nursingChargesCtrl.text = pkg.nursingCharges.toString();
      _consumablesChargesCtrl.text = pkg.consumablesCharges.toString();
    });
  }

  Future<void> _save() async {
    if (_otType == null) {
      showAppSnackBar(context, 'Surgery type is required', isError: true);
      return;
    }
    if (_bloodReportsVerified == null || _bloodReportsNormal == null) {
      showAppSnackBar(context, 'Blood reports verified/normal must be answered', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final counselling = OtCounsellingItem(
        diagnosis: _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
        eye: _eye,
        otType: _otType,
        mediclaim: _mediclaim,
        lensCategory: _lensCategory,
        lensCompany: _lensCompanyCtrl.text.trim().isEmpty ? null : _lensCompanyCtrl.text.trim(),
        lensModel: _lensModelCtrl.text.trim().isEmpty ? null : _lensModelCtrl.text.trim(),
        lensType: _lensType,
        estimatedPower: double.tryParse(_estimatedPowerCtrl.text.trim()),
        lensCost: double.tryParse(_lensCostCtrl.text.trim()),
        packageName: _packageNameCtrl.text.trim().isEmpty ? null : _packageNameCtrl.text.trim(),
        roomCategory: _roomCategory,
        otCharges: double.tryParse(_otChargesCtrl.text.trim()) ?? 0,
        surgeonCharges: double.tryParse(_surgeonChargesCtrl.text.trim()) ?? 0,
        nursingCharges: double.tryParse(_nursingChargesCtrl.text.trim()) ?? 0,
        consumablesCharges: double.tryParse(_consumablesChargesCtrl.text.trim()) ?? 0,
        paymentMode: _paymentMode,
        bloodReportsVerified: _bloodReportsVerified!,
        bloodReportsNormal: _bloodReportsNormal!,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      final totalEstimate = await OtCounsellorService.instance.storeCounselling(widget.bookingId, counselling);
      if (!mounted) return;
      showAppSnackBar(context, 'Counselling saved — estimate ${currentCurrencySymbol()}${totalEstimate.toStringAsFixed(0)}', isSuccess: true);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  /// Yes/No pair for a field that's `required boolean` on the backend
  /// (blood_reports_verified/normal, web pull 2026-08-07 — was an optional
  /// checkbox defaulting to false before). `null` means "not yet answered",
  /// checked in `_save()` before submit.
  Widget _requiredYesNo(String label, bool? value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
      ChoiceChip(label: const Text('Yes'), selected: value == true, onSelected: (_) => onChanged(true)),
      const SizedBox(width: 8),
      ChoiceChip(label: const Text('No'), selected: value == false, onSelected: (_) => onChanged(false)),
    ]);
  }

  InputDecoration _deco(String label, {String? suffix}) => InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Close'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Counselling', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 70, padding: EdgeInsets.zero)
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : _buildForm(),
      ),
    ]);
  }

  Widget _buildForm() {
    final detail = _detail!;
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppSectionHeader(title: 'Diagnosis & Eye', icon: Icons.assignment_outlined),
            TextFormField(controller: _diagnosisCtrl, maxLines: 2, decoration: _deco('Diagnosis')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _otType,
                  isExpanded: true,
                  decoration: _deco('Surgery Type *'),
                  items: detail.otSurgeryTypes.map((t) => DropdownMenuItem(value: t.surgeryName, child: Text(t.surgeryName, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _otType = v),
                ),
              ),
              const SizedBox(width: 16),
              Wrap(spacing: 8, children: ['RE', 'LE', 'Both'].map((e) => ChoiceChip(label: Text(e), selected: _eye == e, onSelected: (_) => setState(() => _eye = e))).toList()),
              const Spacer(),
              Row(children: [
                Checkbox(value: _mediclaim, onChanged: (v) => setState(() => _mediclaim = v ?? false)),
                const Text('Mediclaim', style: TextStyle(fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 20),

            const AppSectionHeader(title: 'Lens', icon: Icons.remove_red_eye_outlined),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(initialValue: _lensType, isExpanded: true, decoration: _deco('Lens Type'), items: kOtLensTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setState(() => _lensType = v)),
              ),
              const SizedBox(width: 12),
              Wrap(spacing: 8, children: ['standard', 'premium'].map((c) => ChoiceChip(label: Text(c[0].toUpperCase() + c.substring(1)), selected: _lensCategory == c, onSelected: (_) => setState(() => _lensCategory = c))).toList()),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _lensCompanyCtrl, decoration: _deco('Lens Company'))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _lensModelCtrl, decoration: _deco('Lens Model'))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _estimatedPowerCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), inputFormatters: _genFmt, decoration: _deco('Estimated Power', suffix: 'D'))),
              const SizedBox(width: 12),
              // Lens Cost is now a plain manual field, decoupled from the
              // package (web pull 2026-08-07) — typed in and added into
              // Total Estimate, not autofilled by package selection anymore.
              Expanded(child: TextFormField(controller: _lensCostCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Lens Cost', suffix: currentCurrencySymbol()))),
            ]),
            const SizedBox(height: 20),

            const AppSectionHeader(title: 'Package / Room', icon: Icons.card_giftcard_rounded),
            DropdownButtonFormField<int>(
              initialValue: _selectedPackageId,
              isExpanded: true,
              decoration: _deco('OT Package'),
              items: detail.packageCostOptions.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.packageName} · ${p.roomCategory[0].toUpperCase()}${p.roomCategory.substring(1)}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) {
                if (v == null) return;
                _selectPackage(detail.packageCostOptions.firstWhere((p) => p.id == v));
              },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: ['general', 'private'].map((r) => ChoiceChip(label: Text(r[0].toUpperCase() + r.substring(1)), selected: _roomCategory == r, onSelected: (_) => setState(() => _roomCategory = r))).toList()),
            const SizedBox(height: 12),
            TextFormField(controller: _packageNameCtrl, decoration: _deco('Package Name')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _otChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('OT Charges', suffix: currentCurrencySymbol()))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _surgeonChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Surgeon Charges', suffix: currentCurrencySymbol()))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _nursingChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Nursing Charges', suffix: currentCurrencySymbol()))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _consumablesChargesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: _genFmt, decoration: _deco('Consumables', suffix: currentCurrencySymbol()))),
            ]),
            const SizedBox(height: 12),
            // Matches web exactly: Total Estimate = ot_charges + surgeon_charges
            // + nursing_charges + consumables_charges + lens_cost (web pull
            // 2026-08-07 changed this from lens_cost-only). See
            // WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §7.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA22)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Estimate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${currentCurrencySymbol()}${_totalEstimate.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 20),

            const AppSectionHeader(title: 'Payment & Reports', icon: Icons.receipt_long_outlined),
            if (!_mediclaim)
              Wrap(spacing: 8, children: ['cash', 'online'].map((m) => ChoiceChip(label: Text(m[0].toUpperCase() + m.substring(1)), selected: _paymentMode == m, onSelected: (_) => setState(() => _paymentMode = m))).toList())
            else
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.orangeA12, borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Text('Payment mode: Mediclaim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _requiredYesNo('Blood reports verified *', _bloodReportsVerified, (v) => setState(() => _bloodReportsVerified = v))),
              const SizedBox(width: 20),
              Expanded(child: _requiredYesNo('Blood reports normal *', _bloodReportsNormal, (v) => setState(() => _bloodReportsNormal = v))),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 3, decoration: _deco('Notes')),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save & Continue to Consent', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)), side: BorderSide(color: AppColors.primaryA22)),
          child: const Text('Cancel'),
        ),
      ]),
    ]);
  }
}

// ── Consent form pane (second step, same detail pane, list stays visible
// throughout — the whole point of this rebuild) ────────────────────────────

class _ConsentFormPane extends StatefulWidget {
  final int bookingId;
  final String patientName;
  final VoidCallback onBack;
  final VoidCallback onDone;

  const _ConsentFormPane({super.key, required this.bookingId, required this.patientName, required this.onBack, required this.onDone});

  @override
  State<_ConsentFormPane> createState() => _ConsentFormPaneState();
}

class _ConsentFormPaneState extends State<_ConsentFormPane> {
  final _patientSigCtrl = SignatureController(penStrokeWidth: 2, penColor: AppColors.darkNavy);
  final _guardianSigCtrl = SignatureController(penStrokeWidth: 2, penColor: AppColors.darkNavy);
  final _witnessCtrl = TextEditingController();

  bool _loading = true;
  String? _loadError;
  bool _consentGiven = false;
  bool _savingConsent = false;
  bool _sendingToBilling = false;
  bool _consentSaved = false;
  String? _otStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _patientSigCtrl.dispose();
    _guardianSigCtrl.dispose();
    _witnessCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final detail = await OtCounsellorService.instance.fetchCounsellingDetail(widget.bookingId);
      if (mounted) {
        setState(() {
          _loading = false;
          _otStatus = detail.booking.otStatus;
          final consent = detail.consent;
          if (consent != null) {
            _consentGiven = consent.consentGiven;
            _witnessCtrl.text = consent.witnessName ?? '';
            _consentSaved = consent.consentGiven;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _saveConsent() async {
    if (!_consentGiven) {
      showAppSnackBar(context, 'Consent must be given to proceed', isError: true);
      return;
    }
    setState(() => _savingConsent = true);
    try {
      final patientSig = await exportSignatureDataUri(_patientSigCtrl);
      final guardianSig = await exportSignatureDataUri(_guardianSigCtrl);
      await OtCounsellorService.instance.storeConsent(
        widget.bookingId,
        consentGiven: _consentGiven,
        patientSignatureDataUri: patientSig,
        guardianSignatureDataUri: guardianSig,
        witnessName: _witnessCtrl.text.trim().isEmpty ? null : _witnessCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() { _savingConsent = false; _consentSaved = true; });
      showAppSnackBar(context, 'Consent saved', isSuccess: true);
    } catch (e) {
      if (mounted) {
        setState(() => _savingConsent = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  Future<void> _sendToBilling() async {
    setState(() => _sendingToBilling = true);
    try {
      await OtCounsellorService.instance.sendToBilling(widget.bookingId);
      if (!mounted) return;
      showAppSnackBar(context, 'Sent to Billing', isSuccess: true);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _sendingToBilling = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary), onPressed: widget.onBack, tooltip: 'Back to Counselling'),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(Icons.draw_rounded, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consent', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(widget.patientName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? const AppSkeletonList(count: 5, itemHeight: 70, padding: EdgeInsets.zero)
            : _loadError != null
                ? AppErrorState(message: _loadError!, onRetry: _load)
                : _buildForm(),
      ),
    ]);
  }

  Widget _buildForm() {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppSectionHeader(title: 'Informed Consent', icon: Icons.draw_rounded),
                Row(children: [
                  Checkbox(value: _consentGiven, onChanged: (v) => setState(() => _consentGiven = v ?? false)),
                  const Text('Patient / guardian has given consent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: SignaturePadField(label: 'Patient Signature', controller: _patientSigCtrl, height: 200)),
                  const SizedBox(width: 20),
                  Expanded(child: SignaturePadField(label: 'Guardian Signature (optional)', controller: _guardianSigCtrl, height: 200)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: 400,
                  child: TextFormField(controller: _witnessCtrl, decoration: const InputDecoration(labelText: 'Witness Name', border: OutlineInputBorder())),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _buildBillingCard(),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(
          onPressed: _savingConsent ? null : _saveConsent,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
          child: _savingConsent ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Consent'),
        ),
      ]),
    ]);
  }

  // Matches web's separate "Ready for Billing?" card exactly — its own
  // section with a status subtitle, not just a button glued onto the
  // Consent form's action row.
  Widget _buildBillingCard() {
    final alreadySent = _otStatus == OtStatus.counselled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
      constraints: const BoxConstraints(maxWidth: 560),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ready for Billing?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Requires counselling saved and consent given.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: (alreadySent || !_consentSaved || _sendingToBilling) ? null : _sendToBilling,
          icon: alreadySent ? const Icon(Icons.check_circle_outline_rounded, size: 18) : const Icon(Icons.send_rounded, size: 18),
          label: _sendingToBilling
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(alreadySent ? 'Already Sent to Billing' : 'Send to Billing', style: const TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
        ),
      ]),
    );
  }
}
