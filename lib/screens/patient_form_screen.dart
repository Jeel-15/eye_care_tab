import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/auth_models.dart';
import '../models/ot_appointment_models.dart';
import '../models/patient_models.dart';
import '../utils/date_format.dart';
import '../services/masters_service.dart';
import '../services/patient_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/phone_rules.dart';
import '../widgets/app_animations.dart';

enum PatientFormMode { addWalkIn, addPhone, edit }

/// Tablet patient add/edit form — embedded in the Patients detail pane
/// (Pattern C: 2-column field grid, no accordion/stepper) instead of being
/// pushed as its own route. Business logic (masters load, contact lookup,
/// submit) ported unchanged from eye_care_app/lib/screens/patient_form_screen.dart.
class PatientFormScreen extends StatefulWidget {
  final PatientFormMode mode;
  final Patient? patient;
  final UserInfo user;
  final HospitalInfo hospital;
  final void Function(Patient saved) onSaved;
  final VoidCallback onCancel;
  // Light client-side prefill when opening "Walk-In" from an OT appointment
  // row (receptionist "Today Added Patients" widget) — name/contact/age/
  // gender only, no backend link to the OT appointment (that's the separate,
  // optional TASK 5.3). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §9.
  final OtAppointmentItem? prefillOt;

  const PatientFormScreen({
    super.key,
    required this.mode,
    this.patient,
    required this.user,
    required this.hospital,
    required this.onSaved,
    required this.onCancel,
    this.prefillOt,
  });

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _mrdCtrl = TextEditingController();
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

  List<ContactSuggestion> _suggestions = [];
  Timer? _contactDebounce;
  bool _showSuggestions = false;

  bool _submitting = false;
  bool _isOldPatient = false;
  bool _examDoneWarning = false;
  bool _warnDismissed = false;

  DateTime _appointmentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initDate();
    _loadMasters();
    if (widget.mode == PatientFormMode.edit && widget.patient != null) {
      _prefillFromPatient(widget.patient!);
    } else if (widget.mode == PatientFormMode.addWalkIn && widget.prefillOt != null) {
      _prefillFromOt(widget.prefillOt!);
    }
  }

  void _initDate() {
    if (widget.mode == PatientFormMode.addPhone) {
      _appointmentDate = DateTime.now().add(const Duration(days: 1));
    } else if (widget.mode == PatientFormMode.edit && widget.patient?.appointmentDate != null) {
      _appointmentDate = DateTime.tryParse(widget.patient!.appointmentDate!) ?? DateTime.now();
    }
    _apptDateCtrl.text = _formatDate(_appointmentDate);
  }

  void _prefillFromPatient(Patient p) {
    _mrdCtrl.text = p.patientCode;
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
    _selectedReferrerId = p.referrer?.id;
    _isOldPatient = p.isOldPatient;
    _examDoneWarning = p.primaryDoneAt != null;
  }

  void _prefillFromOt(OtAppointmentItem o) {
    _firstCtrl.text = o.patientName;
    _middleCtrl.text = o.middleName ?? '';
    _lastCtrl.text = o.surname;
    _contactCtrl.text = o.mobileNo;
    _whatsappCtrl.text = o.whatsappNo ?? '';
    _ageCtrl.text = o.age > 0 ? o.age.toString() : '';
    _selectedGender = o.gender.toLowerCase() == 'female' ? 'female' : 'male';
    _occupationCtrl.text = o.occupation ?? '';
  }

  Future<void> _loadMasters() async {
    setState(() {
      _mastersLoading = true;
      _mastersError = null;
    });
    try {
      final masters = await MastersService.instance.fetchAll();
      if (!mounted) return;
      setState(() => _masters = masters);
      if (widget.mode != PatientFormMode.edit) {
        final mrd = await PatientService.instance.fetchNextMrd();
        if (mounted) _mrdCtrl.text = mrd;
      }
    } catch (e) {
      if (mounted) setState(() => _mastersError = e.toString());
    } finally {
      if (mounted) setState(() => _mastersLoading = false);
    }
  }

  @override
  void dispose() {
    _mrdCtrl.dispose();
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
    _contactDebounce?.cancel();
    super.dispose();
  }

  void _onContactChanged(String val) {
    _contactDebounce?.cancel();
    if (!PhoneRules.hasEnoughDigits(val)) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _contactDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await PatientService.instance.searchByContact(val);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _showSuggestions = results.isNotEmpty;
          });
        }
      } catch (_) {}
    });
  }

  void _fillFromSuggestion(ContactSuggestion s) {
    setState(() {
      _firstCtrl.text = s.firstName;
      _lastCtrl.text = s.lastName;
      _middleCtrl.text = s.middleName;
      _ageCtrl.text = s.age?.toString() ?? '';
      _occupationCtrl.text = s.occupation ?? '';
      if (s.whatsappNo != null) _whatsappCtrl.text = s.whatsappNo!;
      if (s.gender != null) _selectedGender = s.gender!;
      if (s.locationId != null) {
        final loc = _masters?.locations.where((l) => l.id == s.locationId).firstOrNull;
        if (loc != null) {
          _selectedLocationId = s.locationId;
          _districtCtrl.text = loc.district;
          _stateCtrl.text = loc.state;
        }
      }
      _isOldPatient = true;
      _suggestions = [];
      _showSuggestions = false;
    });
    if (s.type == 'shared') {
      showAppSnackBar(context, 'Shared patient selected — please verify city/location.');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: widget.mode == PatientFormMode.edit ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _appointmentDate = picked;
        _apptDateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _addCity() async {
    final cityCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final stateCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.blueLight], begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Row(children: [
            const Icon(Icons.add_location_alt_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Add City', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(ctx, false)),
          ]),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          _dialogField(cityCtrl, 'City *'),
          const SizedBox(height: 12),
          _dialogField(distCtrl, 'District'),
          const SizedBox(height: 12),
          _dialogField(stateCtrl, 'State'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Add', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (result != true || cityCtrl.text.trim().isEmpty) return;

    try {
      final loc = await MastersService.instance.addLocation(city: cityCtrl.text.trim(), district: distCtrl.text.trim(), state: stateCtrl.text.trim());
      if (mounted) {
        setState(() {
          _masters = MastersData(cases: _masters!.cases, doctors: _masters!.doctors, locations: [..._masters!.locations, loc], slots: _masters!.slots, referrers: _masters!.referrers);
          _selectedLocationId = loc.id;
          _districtCtrl.text = loc.district;
          _stateCtrl.text = loc.state;
        });
        showAppSnackBar(context, 'City "${loc.city}" added.', isSuccess: true);
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final isPhone = widget.mode == PatientFormMode.addPhone;
      final isEdit = widget.mode == PatientFormMode.edit;

      final data = <String, dynamic>{
        'appointment_date': _formatDate(_appointmentDate, iso: true),
        'contact_no': _contactCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim(),
        'doctor_id': _selectedDoctorId,
        'location_id': _selectedLocationId,
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _selectedGender,
        'occupation': _occupationCtrl.text.trim().isEmpty ? null : _occupationCtrl.text.trim(),
        'referrer_id': _selectedReferrerId,
        'is_old_patient': _isOldPatient,
      };

      if (!isPhone) {
        data['case_id'] = _selectedCaseId;
        data['case_fee'] = double.tryParse(_caseFeeCtrl.text.trim()) ?? 0;
      } else {
        data['slot_id'] = _selectedSlotId;
      }

      if (widget.mode == PatientFormMode.addWalkIn && widget.prefillOt != null) {
        data['ot_appointment_id'] = widget.prefillOt!.id;
      }

      Patient saved;
      if (isEdit) {
        data['case_fee'] = double.tryParse(_caseFeeCtrl.text.trim()) ?? 0;
        data['case_id'] = _selectedCaseId;
        saved = await PatientService.instance.updatePatient(widget.patient!.id, data);
      } else if (isPhone) {
        saved = await PatientService.instance.registerPhone(data);
      } else {
        saved = await PatientService.instance.registerWalkIn(data);
      }

      if (mounted) widget.onSaved(saved);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true, duration: const Duration(seconds: 4));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mastersLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_mastersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_mastersError ?? 'Failed to load form data.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _loadMasters, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary)),
          ]),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(child: SingleChildScrollView(child: _buildForm())),
      ],
    );
  }

  Widget _buildHeader() {
    final (title, subtitle, icon) = switch (widget.mode) {
      PatientFormMode.addWalkIn => ('Register New Patient', 'Capture patient information and appointment details', Icons.person_add_rounded),
      PatientFormMode.addPhone => ('Register Phone Appointment', 'Capture caller details and appointment information', Icons.phone_in_talk_rounded),
      PatientFormMode.edit => ('Edit Patient', 'Update patient information and appointment details', Icons.edit_rounded),
    };
    return Row(
      children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Cancel'),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final isPhone = widget.mode == PatientFormMode.addPhone;
    final isEdit = widget.mode == PatientFormMode.edit;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEdit && _examDoneWarning && !_warnDismissed) _buildWarnBanner(),

          _row2(
            _field('MRD Number', _readonlyField(_mrdCtrl, 'MRD No.', Icons.badge_outlined)),
            _field('Appointment Date *', _datefield()),
          ),
          _row2(
            _field('Contact Number *', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_contactField(), if (_showSuggestions) _suggestionDropdown()])),
            _field('WhatsApp Number', _textField(_whatsappCtrl, 'WhatsApp No (same if blank)', inputType: TextInputType.phone, maxLength: 16, validator: PhoneRules.nullable)),
          ),
          _row2(
            _field('First Name *', _textField(_firstCtrl, 'First Name', required: true)),
            _field('Surname *', _textField(_lastCtrl, 'Surname', required: true)),
          ),
          _row2(
            _field('Middle Name', _textField(_middleCtrl, 'Middle Name')),
            _field('Doctor Name *', _doctorDropdown()),
          ),
          if (!isPhone)
            _row2(
              _field('Case Type *', _caseTypeDropdown()),
              _field(
                'Case Fee (₹) *',
                _textField(_caseFeeCtrl, 'Case Fee', inputType: TextInputType.number, required: true, readOnly: widget.mode == PatientFormMode.addWalkIn, hintOverride: widget.mode == PatientFormMode.addWalkIn ? 'Auto-filled from Case Type' : null),
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
              _locationDropdown(),
            ]),
            fullWidth: true,
          ),
          _row2(
            _field('District', _readonlyField(_districtCtrl, 'District', Icons.location_city_outlined)),
            _field('State', _readonlyField(_stateCtrl, 'State', Icons.map_outlined)),
          ),
          _row2(
            _field('Age *', _textField(_ageCtrl, 'Age', inputType: TextInputType.number, required: true, maxLength: 3)),
            _field('Gender *', _genderDropdown()),
          ),
          _row2(
            _field('Occupation', _textField(_occupationCtrl, 'Occupation')),
            isPhone ? _field('Time Slot', _slotDropdown()) : _field('Referred By', _referrerDropdown()),
          ),
          if (isPhone) _field('Referred By', _referrerDropdown(), fullWidth: true),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _submitButton(isEdit: isEdit, isPhone: isPhone)),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)), side: BorderSide(color: AppColors.primaryA22)),
              child: const Text('Cancel'),
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Layout helpers ──────────────────────────────────────────────────────

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(children: [a, b]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _field(String label, Widget child, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, {IconData? prefix, bool readOnly = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppColors.primary.withValues(alpha: 0.4)),
      prefixIcon: prefix != null ? Icon(prefix, size: 18, color: AppColors.primary.withValues(alpha: 0.5)) : null,
      filled: true,
      fillColor: readOnly ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType inputType = TextInputType.text, bool required = false, bool readOnly = false, int? maxLength, String? Function(String?)? validator, String? hintOverride}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      readOnly: readOnly,
      maxLength: maxLength,
      inputFormatters: inputType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: _inputDeco(hintOverride ?? hint, readOnly: readOnly).copyWith(counterText: ''),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? '$hint is required' : null : null),
    );
  }

  Widget _readonlyField(TextEditingController ctrl, String hint, IconData icon) {
    return TextFormField(controller: ctrl, readOnly: true, style: TextStyle(color: AppColors.primary.withValues(alpha: 0.65), fontWeight: FontWeight.w500), decoration: _inputDeco(hint, prefix: icon, readOnly: true));
  }

  Widget _datefield() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(controller: _apptDateCtrl, decoration: _inputDeco('Pick date', prefix: Icons.calendar_today_outlined), validator: (v) => (v == null || v.isEmpty) ? 'Appointment date required' : null),
      ),
    );
  }

  Widget _contactField() {
    return TextFormField(
      controller: _contactCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [LengthLimitingTextInputFormatter(16)],
      onChanged: _onContactChanged,
      decoration: _inputDeco('Contact number (e.g. +91XXXXXXXXXX)', prefix: Icons.phone_outlined).copyWith(counterText: ''),
      validator: PhoneRules.required,
    );
  }

  Widget _suggestionDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(
        children: _suggestions.map((s) {
          final isLocal = s.type == 'local';
          return InkWell(
            onTap: () => _fillFromSuggestion(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.fullName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                    if (s.age != null || s.gender != null)
                      Text([if (s.age != null) '${s.age}y', if (s.gender != null) '${s.gender![0].toUpperCase()}${s.gender!.substring(1)}'].join(' · '), style: TextStyle(fontSize: 11, color: AppColors.primary.withValues(alpha: 0.55))),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: isLocal ? const Color(0xFFD1FAE5) : const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: isLocal ? const Color(0xFF10B981) : const Color(0xFFFFC107))),
                  child: Text(isLocal ? 'Own' : s.hospitalName ?? 'Partner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isLocal ? const Color(0xFF065F46) : const Color(0xFF856404))),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown<T>({required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged, required String hint, String? Function(T?)? validator}) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: _inputDeco(hint),
      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
      icon: Icon(Icons.expand_more_rounded, color: AppColors.primary.withValues(alpha: 0.6)),
      dropdownColor: Colors.white,
      isExpanded: true,
    );
  }

  Widget _caseTypeDropdown() {
    final cases = _masters?.cases ?? [];
    return _buildDropdown<int>(
      value: _selectedCaseId,
      hint: 'Select Case Type',
      items: cases.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) {
        setState(() {
          _selectedCaseId = v;
          final caseObj = cases.where((c) => c.id == v).firstOrNull;
          if (caseObj != null && widget.mode != PatientFormMode.edit) {
            _caseFeeCtrl.text = caseObj.fee.toInt().toString();
          }
        });
      },
      validator: (v) => v == null ? 'Case type required' : null,
    );
  }

  Widget _doctorDropdown() {
    final docs = _masters?.doctors ?? [];
    return _buildDropdown<int>(
      value: _selectedDoctorId,
      hint: 'Select Doctor',
      items: docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) => setState(() => _selectedDoctorId = v),
      validator: (v) => v == null ? 'Doctor required' : null,
    );
  }

  Widget _locationDropdown() {
    final locs = _masters?.locations ?? [];
    return _buildDropdown<int>(
      value: _selectedLocationId,
      hint: 'Select City',
      items: locs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.city, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) {
        setState(() {
          _selectedLocationId = v;
          final loc = locs.where((l) => l.id == v).firstOrNull;
          if (loc != null) {
            _districtCtrl.text = loc.district;
            _stateCtrl.text = loc.state;
          }
        });
      },
      validator: (v) => v == null ? 'City required' : null,
    );
  }

  Widget _genderDropdown() {
    return _buildDropdown<String>(
      value: _selectedGender,
      hint: 'Gender',
      items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))],
      onChanged: (v) => setState(() => _selectedGender = v ?? 'male'),
    );
  }

  Widget _slotDropdown() {
    final slots = _masters?.slots ?? [];
    return _buildDropdown<int>(
      value: _selectedSlotId,
      hint: 'No Slot (optional)',
      items: slots.map((s) => DropdownMenuItem(value: s.id, child: Text(s.display, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) => setState(() => _selectedSlotId = v),
    );
  }

  Widget _referrerDropdown() {
    final refs = _masters?.referrers ?? [];
    return _buildDropdown<int>(
      value: _selectedReferrerId,
      hint: 'No Referrer (optional)',
      items: refs.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
      onChanged: (v) => setState(() => _selectedReferrerId = v),
    );
  }

  Widget _buildWarnBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: const Color(0xFFFDEBD0), borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: Color(0xFFE67E22), width: 4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFE67E22), size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Examination Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF784212))),
            SizedBox(height: 2),
            Text('Primary examination has already been done. Changes will not affect examination data.', style: TextStyle(fontSize: 11, color: Color(0xFF784212))),
          ]),
        ),
        IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF784212)), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() => _warnDismissed = true)),
      ]),
    );
  }

  Widget _submitButton({required bool isEdit, required bool isPhone}) {
    final label = isEdit ? 'Update Patient' : isPhone ? 'Register Phone Appointment' : 'Register Patient';
    return ElevatedButton(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        elevation: 2,
      ),
      child: _submitting
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline_rounded, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
    );
  }

  String _formatDate(DateTime dt, {bool iso = false}) {
    if (iso) return toIsoDate(dt);
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }
}
