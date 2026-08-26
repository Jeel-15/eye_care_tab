import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../utils/date_format.dart';
import '../models/patient_models.dart';
import '../services/masters_service.dart';
import '../services/patient_service.dart';
import '../utils/phone_rules.dart';
import '../widgets/app_animations.dart';

/// Tablet Patient Check-in — shown as a dialog (not a full-screen route) from
/// the Patients detail pane, since it's a short discrete action. Business
/// logic ported from eye_care_app/lib/screens/patient_checkin_screen.dart.
/// Mobile navigates to OpdBillScreen on success; that screen is Phase 11
/// here, so success just closes the dialog and hands the updated Patient
/// back via [onDone].
class PatientCheckinScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;
  final Patient patient;
  final void Function(Patient updated) onDone;
  final VoidCallback onCancel;

  const PatientCheckinScreen({
    super.key,
    required this.user,
    required this.hospital,
    required this.patient,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<PatientCheckinScreen> createState() => _PatientCheckinScreenState();
}

class _PatientCheckinScreenState extends State<PatientCheckinScreen> {
  final _formKey = GlobalKey<FormState>();

  final _contactCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _caseFeeCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _apptDateCtrl = TextEditingController();

  int? _selectedCaseId;
  int? _selectedDoctorId;
  int? _selectedLocationId;
  int? _selectedSlotId;
  int? _selectedReferrerId;
  String _selectedGender = 'male';

  MastersData? _masters;
  bool _mastersLoading = true;
  String? _mastersError;
  bool _submitting = false;
  DateTime _appointmentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _prefill(widget.patient);
    _loadMasters();
  }

  void _prefill(Patient p) {
    _contactCtrl.text = p.contactNo ?? '';
    _whatsappCtrl.text = p.whatsappNo ?? '';
    _firstCtrl.text = p.firstName;
    _lastCtrl.text = p.lastName;
    _middleCtrl.text = p.middleName;
    _caseFeeCtrl.text = p.caseFee?.toInt().toString() ?? '';
    _ageCtrl.text = p.age?.toString() ?? '';
    _occupationCtrl.text = p.occupation ?? '';
    _selectedGender = p.gender ?? 'male';
    _selectedCaseId = p.caseId;
    _selectedDoctorId = p.doctor?.id;
    _selectedLocationId = p.location?.id;
    _districtCtrl.text = p.location?.district ?? '';
    _stateCtrl.text = p.location?.state ?? '';
    _selectedSlotId = p.slotId;
    _selectedReferrerId = p.referrerId;
    if (p.appointmentDate != null) {
      _appointmentDate = DateTime.tryParse(p.appointmentDate!) ?? DateTime.now();
    }
    _apptDateCtrl.text = _fmtDate(_appointmentDate);
  }

  Future<void> _loadMasters() async {
    setState(() {
      _mastersLoading = true;
      _mastersError = null;
    });
    try {
      final m = await MastersService.instance.fetchAll();
      if (!mounted) return;
      setState(() => _masters = m);
      if (_selectedLocationId != null) {
        final loc = m.locations.where((l) => l.id == _selectedLocationId).firstOrNull;
        if (loc != null && mounted) {
          setState(() {
            _districtCtrl.text = loc.district;
            _stateCtrl.text = loc.state;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _mastersError = e.toString());
    } finally {
      if (mounted) setState(() => _mastersLoading = false);
    }
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _whatsappCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _middleCtrl.dispose();
    _caseFeeCtrl.dispose();
    _ageCtrl.dispose();
    _occupationCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _apptDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null && mounted) {
      setState(() {
        _appointmentDate = picked;
        _apptDateCtrl.text = _fmtDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'appointment_date': _fmtDateIso(_appointmentDate),
        'contact_no': _contactCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _selectedGender,
        'occupation': _occupationCtrl.text.trim().isEmpty ? null : _occupationCtrl.text.trim(),
        'doctor_id': _selectedDoctorId,
        'location_id': _selectedLocationId,
        'case_id': _selectedCaseId,
        'case_fee': double.tryParse(_caseFeeCtrl.text.trim()) ?? 0,
        'slot_id': _selectedSlotId,
        'referrer_id': _selectedReferrerId,
      };

      final updated = await PatientService.instance.checkIn(widget.patient.id, data);
      if (mounted) widget.onDone(updated);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true, duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _mastersLoading
                  ? Padding(padding: const EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                  : _mastersError != null
                      ? _buildError()
                      : Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), child: SingleChildScrollView(child: _buildForm())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final p = widget.patient;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.blueLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.md)), child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Patient Check-In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('MRD: ${p.patientCode}  ·  Verify details & assign case', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
          ]),
        ),
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: widget.onCancel),
      ]),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.red),
        const SizedBox(height: 12),
        Text(_mastersError ?? 'Failed to load form data.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _loadMasters, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary)),
      ]),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoNotice(),
          _row2(_field('MRD Number', _readonlyField(TextEditingController(text: widget.patient.patientCode), 'MRD No.', Icons.badge_outlined)), _field('Appointment Date *', _datefield())),
          _row2(_field('Contact No *', _textField(_contactCtrl, 'Contact number', inputType: TextInputType.phone, maxLength: 16, validator: PhoneRules.required)), _field('WhatsApp No', _textField(_whatsappCtrl, 'Same if blank', inputType: TextInputType.phone, maxLength: 10))),
          _row2(_field('First Name *', _textField(_firstCtrl, 'First Name', required: true)), _field('Surname *', _textField(_lastCtrl, 'Surname', required: true))),
          _row2(_field('Middle Name', _textField(_middleCtrl, 'Middle Name')), _field('Doctor *', _doctorDropdown())),
          _row2(_field('Case Type *', _caseTypeDropdown()), _field('Case Fee (₹) *', _caseFeeField())),
          _field('City *', _locationDropdown(), fullWidth: true),
          _row2(_field('District', _readonlyField(_districtCtrl, 'District', Icons.location_city_outlined)), _field('State', _readonlyField(_stateCtrl, 'State', Icons.map_outlined))),
          _row2(_field('Age *', _textField(_ageCtrl, 'Age', inputType: TextInputType.number, required: true, maxLength: 3)), _field('Gender *', _genderDropdown())),
          _row2(_field('Occupation', _textField(_occupationCtrl, 'Occupation')), _field('Time Slot', _slotDropdown())),
          _field('Referred By', _referrerDropdown(), fullWidth: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.how_to_reg_rounded, size: 20),
              label: const Text('Check In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.primaryA50, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)), elevation: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) return Column(children: [a, b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _field(String label, Widget child, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)), const SizedBox(height: 5), child]),
    );
  }

  Widget _infoNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(color: const Color(0xFFD6EAF8), borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: AppColors.blueLight, width: 4))),
      child: const Row(children: [
        Icon(Icons.info_outline_rounded, color: AppColors.blueLight, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text('Pre-filled from phone appointment. Verify and update if needed before checking in.', style: TextStyle(fontSize: 11, color: Color(0xFF1A5276)))),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, {IconData? prefix, bool readOnly = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppColors.primaryA40),
      prefixIcon: prefix != null ? Icon(prefix, size: 18, color: AppColors.primaryA50) : null,
      filled: true,
      fillColor: readOnly ? AppColors.primaryA04 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primaryA18)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primaryA18)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType inputType = TextInputType.text, bool required = false, int? maxLength, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      maxLength: maxLength,
      inputFormatters: inputType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: _inputDeco(hint).copyWith(counterText: ''),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? '$hint is required' : null : null),
    );
  }

  Widget _readonlyField(TextEditingController ctrl, String hint, IconData icon) {
    return TextFormField(controller: ctrl, readOnly: true, style: TextStyle(color: AppColors.primary.withValues(alpha: 0.65), fontWeight: FontWeight.w500), decoration: _inputDeco(hint, prefix: icon, readOnly: true));
  }

  Widget _datefield() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(child: TextFormField(controller: _apptDateCtrl, decoration: _inputDeco('Pick date', prefix: Icons.calendar_today_outlined), validator: (v) => (v == null || v.isEmpty) ? 'Appointment date required' : null)),
    );
  }

  Widget _caseFeeField() {
    return TextFormField(
      controller: _caseFeeCtrl,
      keyboardType: TextInputType.number,
      decoration: _inputDeco('0').copyWith(
        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: AppColors.green),
        filled: true,
        fillColor: const Color(0xFFEAFAF1),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFA9DFBF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
      ),
      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Fee required';
        if (double.tryParse(v.trim()) == null) return 'Invalid fee';
        return null;
      },
    );
  }

  Widget _buildDropdown<T>({required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged, required String hint, String? Function(T?)? validator}) {
    return DropdownButtonFormField<T>(initialValue: value, items: items, onChanged: onChanged, validator: validator, decoration: _inputDeco(hint), style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500), icon: Icon(Icons.expand_more_rounded, color: AppColors.primaryA60), dropdownColor: Colors.white, isExpanded: true);
  }

  Widget _caseTypeDropdown() {
    final cases = _masters?.cases ?? [];
    return _buildDropdown<int>(
      value: _selectedCaseId,
      hint: 'Select Case Type',
      items: cases.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) => setState(() {
        _selectedCaseId = v;
        final c = cases.where((x) => x.id == v).firstOrNull;
        if (c != null) _caseFeeCtrl.text = c.fee.toInt().toString();
      }),
      validator: (v) => v == null ? 'Case type required' : null,
    );
  }

  Widget _doctorDropdown() {
    final docs = _masters?.doctors ?? [];
    return _buildDropdown<int>(value: _selectedDoctorId, hint: 'Select Doctor', items: docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(), onChanged: (v) => setState(() => _selectedDoctorId = v), validator: (v) => v == null ? 'Doctor required' : null);
  }

  Widget _locationDropdown() {
    final locs = _masters?.locations ?? [];
    return _buildDropdown<int>(
      value: _selectedLocationId,
      hint: 'Select City',
      items: locs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.city, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) => setState(() {
        _selectedLocationId = v;
        final loc = locs.where((l) => l.id == v).firstOrNull;
        if (loc != null) {
          _districtCtrl.text = loc.district;
          _stateCtrl.text = loc.state;
        }
      }),
      validator: (v) => v == null ? 'City required' : null,
    );
  }

  Widget _genderDropdown() {
    return _buildDropdown<String>(value: _selectedGender, hint: 'Gender', items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (v) => setState(() => _selectedGender = v ?? 'male'));
  }

  Widget _slotDropdown() {
    final slots = _masters?.slots ?? [];
    return _buildDropdown<int>(value: _selectedSlotId, hint: 'No Slot', items: slots.map((s) => DropdownMenuItem(value: s.id, child: Text(s.display, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(), onChanged: (v) => setState(() => _selectedSlotId = v));
  }

  Widget _referrerDropdown() {
    final refs = _masters?.referrers ?? [];
    return _buildDropdown<int>(value: _selectedReferrerId, hint: 'No Referrer', items: refs.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(), onChanged: (v) => setState(() => _selectedReferrerId = v));
  }

  String _fmtDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  String _fmtDateIso(DateTime dt) => toIsoDate(dt);
}
