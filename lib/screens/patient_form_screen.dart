import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/auth_models.dart';
import '../models/ot_appointment_models.dart';
import '../models/patient_models.dart';
import '../utils/date_format.dart';
import '../services/base_service.dart' show StaleRecordException;
import '../services/masters_service.dart';
import '../services/ot_appointment_service.dart';
import '../services/patient_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/phone_rules.dart';
import '../widgets/add_city_dialog.dart';
import '../widgets/app_animations.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';
import '../utils/app_date_picker.dart';

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
  bool _fillingSuggestion = false;

  // ── OT check-in search (walk-in only) — web parity: `create.blade.php`'s
  // optional "OT check-in search" panel lets reception pick a same-day,
  // not-yet-checked-in OT appointment to pre-fill this form from and, on
  // submit, mark that appointment completed + linked to the new patient
  // (see PatientApiController::store()'s `ot_appointment_id` handling,
  // already wired — only this search UI was missing).
  final _otSearchCtrl = TextEditingController();
  Timer? _otSearchDebounce;
  List<OtAppointmentItem> _otSearchResults = [];
  bool _otSearchExpanded = false;
  bool _otSearching = false;
  int? _linkedOtAppointmentId;
  String? _linkedOtAppointmentNumber;

  bool _submitting = false;
  bool _isOldPatient = false;
  bool _examDoneWarning = false;
  bool _warnDismissed = false;

  DateTime _appointmentDate = DateTime.now();

  // Web parity (`patients/edit-phone.blade.php`, web pull 2026-10-05) — a
  // phone-registered patient who hasn't checked in yet (`type == 'phone' &&
  // case_id == null`) edits with the slimmer phone-style form (Slot instead
  // of Case Type/Fee), not the full walk-in edit form. Previously `isPhone`
  // was ONLY true for the addPhone *creation* mode, never during edit — so
  // editing a still-pending phone patient always opened the full walk-in
  // form, and saving it unconditionally sent `case_id`/`case_fee`, silently
  // converting the phone booking into a walk-in on save.
  bool get _isPhoneEdit =>
      widget.mode == PatientFormMode.edit &&
      widget.patient?.type == 'phone' &&
      widget.patient?.caseId == null;

  bool get _isPhoneForm =>
      widget.mode == PatientFormMode.addPhone || _isPhoneEdit;

  @override
  void initState() {
    super.initState();
    _initDate();
    _loadMasters();
    if (widget.mode == PatientFormMode.edit && widget.patient != null) {
      _prefillFromPatient(widget.patient!);
    } else if (widget.mode == PatientFormMode.addWalkIn &&
        widget.prefillOt != null) {
      _prefillFromOt(widget.prefillOt!);
    }
  }

  void _initDate() {
    if (widget.mode == PatientFormMode.addPhone) {
      _appointmentDate = DateTime.now().add(const Duration(days: 1));
    } else if (widget.mode == PatientFormMode.edit &&
        widget.patient?.appointmentDate != null) {
      _appointmentDate =
          parseApiPlainDate(widget.patient!.appointmentDate!) ?? DateTime.now();
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
    _selectedSlotId = p.slotId;
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
    // Doctor/City were never read here before (comment above used to say
    // "name/contact/age/gender only") — District/State can't be resolved
    // yet since `_masters` hasn't finished loading at this point (this runs
    // synchronously in initState, before `_loadMasters()`'s awaited fetch
    // returns); `_loadMasters()` resolves them once the location list is
    // actually available. The dropdowns themselves don't have this problem
    // — they aren't built until masters finishes loading, so setting the
    // id here is enough for them to show the right selection on first build.
    _selectedDoctorId = o.doctor?.id;
    _selectedLocationId = o.location?.id;
    _selectedReferrerId = o.referrerId;
    _linkedOtAppointmentId = o.id;
    _linkedOtAppointmentNumber = o.appointmentNumber;
    _otSearchCtrl.text = '${o.appointmentNumber} — ${o.fullName}';
    _otSearchExpanded = true;
  }

  // ── OT check-in search ───────────────────────────────────────────────────

  void _onOtSearchChanged(String val) {
    _otSearchDebounce?.cancel();
    if (val.trim().length < 3) {
      setState(() => _otSearchResults = []);
      return;
    }
    _otSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _otSearching = true);
      try {
        final result = await OtAppointmentService.instance.search(val.trim());
        if (mounted)
          setState(() {
            _otSearchResults = result.appointments;
            _otSearching = false;
          });
      } catch (_) {
        if (mounted)
          setState(() {
            _otSearchResults = [];
            _otSearching = false;
          });
      }
    });
  }

  void _selectOtAppointment(OtAppointmentItem o) {
    setState(() {
      _firstCtrl.text = o.patientName;
      _lastCtrl.text = o.surname;
      _middleCtrl.text = o.middleName ?? '';
      _whatsappCtrl.text = o.whatsappNo ?? '';
      _ageCtrl.text = o.age > 0 ? o.age.toString() : '';
      _occupationCtrl.text = o.occupation ?? '';
      _contactCtrl.text = o.mobileNo;
      _selectedGender = o.gender.toLowerCase() == 'female' ? 'female' : 'male';
      if (o.doctor != null) _selectedDoctorId = o.doctor!.id;
      if (o.referrerId != null) _selectedReferrerId = o.referrerId;
      if (o.location != null) {
        final loc = _masters?.locations
            .where((l) => l.id == o.location!.id)
            .firstOrNull;
        if (loc != null) {
          _selectedLocationId = loc.id;
          _districtCtrl.text = loc.district;
          _stateCtrl.text = loc.state;
        }
      }
      _linkedOtAppointmentId = o.id;
      _linkedOtAppointmentNumber = o.appointmentNumber;
      _otSearchCtrl.text = '${o.appointmentNumber} — ${o.fullName}';
      _otSearchResults = [];
    });
  }

  void _clearOtLink() {
    setState(() {
      _linkedOtAppointmentId = null;
      _linkedOtAppointmentNumber = null;
      _otSearchCtrl.clear();
      _otSearchResults = [];
    });
  }

  Future<void> _loadMasters() async {
    setState(() {
      _mastersLoading = true;
      _mastersError = null;
    });
    try {
      final masters = await MastersService.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _masters = masters;
        // Resolves District/State for the OT-dashboard-widget prefill flow
        // (_prefillFromOt already set _selectedLocationId, but couldn't look
        // up the district/state text since this list wasn't loaded yet).
        if (widget.mode == PatientFormMode.addWalkIn &&
            _selectedLocationId != null) {
          final loc = masters.locations
              .where((l) => l.id == _selectedLocationId)
              .firstOrNull;
          if (loc != null) {
            _districtCtrl.text = loc.district;
            _stateCtrl.text = loc.state;
          }
        }
      });
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
    _otSearchCtrl.dispose();
    _otSearchDebounce?.cancel();
    super.dispose();
  }

  // Web parity: the past-patient suggestion lookup is keyed off the Contact
  // Number only, not the Name — typing a new patient's name must never
  // surface someone else's record by name match.
  void _onLookupChanged(String val) {
    if (_fillingSuggestion) return;
    _contactDebounce?.cancel();
    final q = val.trim();
    if (q.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _contactDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await PatientService.instance.searchByContact(q);
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
    _fillingSuggestion = true;
    setState(() {
      _firstCtrl.text = s.firstName;
      _lastCtrl.text = s.lastName;
      _middleCtrl.text = s.middleName;
      _ageCtrl.text = s.age?.toString() ?? '';
      _occupationCtrl.text = s.occupation ?? '';
      if (s.whatsappNo != null) _whatsappCtrl.text = s.whatsappNo!;
      if (s.contactNo != null && s.contactNo!.isNotEmpty)
        _contactCtrl.text = s.contactNo!;
      if (s.gender != null) _selectedGender = s.gender!;
      if (s.locationId != null) {
        final loc = _masters?.locations
            .where((l) => l.id == s.locationId)
            .firstOrNull;
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
    _fillingSuggestion = false;
    if (s.type == 'shared') {
      showAppSnackBar(
        context,
        'Shared patient selected — please verify city/location.',
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _appointmentDate,
      firstDate: widget.mode == PatientFormMode.edit
          ? DateTime(2020)
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
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
    final loc = await showAddCityDialog(context);
    if (loc == null || !mounted) return;
    setState(() {
      _masters = MastersData(
        cases: _masters!.cases,
        doctors: _masters!.doctors,
        locations: [..._masters!.locations, loc],
        slots: _masters!.slots,
        referrers: _masters!.referrers,
      );
      _selectedLocationId = loc.id;
      _districtCtrl.text = loc.district;
      _stateCtrl.text = loc.state;
    });
    showAppSnackBar(context, 'City "${loc.city}" added.', isSuccess: true);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final isPhone = _isPhoneForm;
      final isEdit = widget.mode == PatientFormMode.edit;

      final data = <String, dynamic>{
        'appointment_date': _formatDate(_appointmentDate, iso: true),
        'contact_no': _contactCtrl.text.trim(),
        'whatsapp_no': _whatsappCtrl.text.trim().isEmpty
            ? null
            : _whatsappCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim(),
        'doctor_id': _selectedDoctorId,
        'location_id': _selectedLocationId,
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _selectedGender,
        'occupation': _occupationCtrl.text.trim().isEmpty
            ? null
            : _occupationCtrl.text.trim(),
        'referrer_id': _selectedReferrerId,
        'is_old_patient': _isOldPatient,
      };

      if (!isPhone) {
        data['case_id'] = _selectedCaseId;
        data['case_fee'] = double.tryParse(_caseFeeCtrl.text.trim()) ?? 0;
      } else {
        data['slot_id'] = _selectedSlotId;
      }

      if (widget.mode == PatientFormMode.addWalkIn &&
          _linkedOtAppointmentId != null) {
        data['ot_appointment_id'] = _linkedOtAppointmentId;
      }

      Patient saved;
      if (isEdit) {
        // case_fee/case_id are editable in edit — but NEVER for a still-
        // pending phone patient (no case assigned yet): sending them would
        // silently convert the phone booking into a walk-in on save, since
        // `case_id`/`case_fee` being set is exactly what distinguishes a
        // checked-in patient from a pending phone appointment server-side.
        if (!isPhone) {
          data['case_fee'] = double.tryParse(_caseFeeCtrl.text.trim()) ?? 0;
          data['case_id'] = _selectedCaseId;
        }
        // Optimistic-concurrency guard — see
        // ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 5.
        if (widget.patient!.updatedAt != null) {
          data['expected_updated_at'] = widget.patient!.updatedAt!
              .toIso8601String();
        }
        saved = await PatientService.instance.updatePatient(
          widget.patient!.id,
          data,
        );
      } else if (isPhone) {
        saved = await PatientService.instance.registerPhone(data);
      } else {
        saved = await PatientService.instance.registerWalkIn(data);
      }

      if (mounted) widget.onSaved(saved);
    } on StaleRecordException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        await showStaleRecordDialog(context, e.humanMessage, widget.onCancel);
      }
      return;
    } catch (e) {
      if (mounted)
        showAppSnackBar(
          context,
          e.toString(),
          isError: true,
          duration: const Duration(seconds: 4),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mastersLoading) {
      return const AppSkeletonList(count: 6, itemHeight: 60);
    }
    if (_mastersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _mastersError ?? 'Failed to load form data.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadMasters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
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
      PatientFormMode.addWalkIn => (
        'Register New Patient',
        'Capture patient information and appointment details',
        Icons.person_add_rounded,
      ),
      PatientFormMode.addPhone => (
        'Register Phone Appointment',
        'Capture caller details and appointment information',
        Icons.phone_in_talk_rounded,
      ),
      // Web parity (`patients/edit-phone.blade.php`) — a still-pending
      // phone patient edits under its own title, matching web exactly.
      PatientFormMode.edit when _isPhoneEdit => (
        'Edit Phone Appointment',
        'Update caller details and appointment information',
        Icons.phone_in_talk_rounded,
      ),
      PatientFormMode.edit => (
        'Edit Patient',
        'Update patient information and appointment details',
        Icons.edit_rounded,
      ),
    };
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.primary),
          onPressed: widget.onCancel,
          tooltip: 'Cancel',
        ),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.blueLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.darkNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final isPhone = _isPhoneForm;
    final isEdit = widget.mode == PatientFormMode.edit;
    final isWalkIn = widget.mode == PatientFormMode.addWalkIn;

    // Field ORDER here must match web's exact DOM order — confirmed against
    // `patients/create.blade.php` (walk-in), `create-phone.blade.php` and
    // `edit.blade.php` (walk-in/edit share one order; phone differs by
    // skipping MRD/Case Type/Case Fee and inserting Slot Time after
    // Doctor). Web itself has no named sections in this form (just one
    // continuous grid under one "Add Patient" card) — an earlier pass here
    // grouped fields into Appointment/Contact/Personal/Visit-Details cards,
    // which read nicer but silently reordered fields relative to web; that
    // grouping is reverted. `_row2` still packs 2-per-row for the tablet's
    // narrower dialog (web's own grid is wider), but always pairs
    // *consecutive* fields, so left-to-right/top-to-bottom reading order
    // stays identical to web's.
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEdit && _examDoneWarning && !_warnDismissed) _buildWarnBanner(),
          if (isWalkIn) _buildOtCheckinSection(),

          // MRD — its own line above everything else, matching web's
          // `rpc-grid--1` row. Web has no MRD on the phone pre-registration
          // (create) form — no patient_code yet — but DOES show it, read-
          // only, when editing a phone patient (`edit-phone.blade.php`),
          // since the patient already has a code by then.
          if (isEdit || !isPhone) ...[
            _readonlyField(_mrdCtrl, 'MRD Number', Icons.badge_outlined),
            const SizedBox(height: 14),
          ],

          _row2(
            _datefield(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _contactField(),
                if (_showSuggestions) _suggestionDropdown(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _row2(
            _textField(
              _whatsappCtrl,
              'WhatsApp Number',
              hint: 'Same as contact if blank',
              inputType: TextInputType.phone,
              maxLength: 16,
              validator: PhoneRules.nullable,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(_firstCtrl, 'First Name *', required: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _row2(
            _textField(_lastCtrl, 'Surname *', required: true),
            _textField(_middleCtrl, 'Middle Name'),
          ),
          const SizedBox(height: 14),

          if (!isPhone) ...[
            _row2(
              _caseTypeDropdown(),
              _textField(
                _caseFeeCtrl,
                'Case Fee (${widget.hospital.currencySymbol}) *',
                inputType: TextInputType.number,
                required: true,
                readOnly: isWalkIn,
                hintOverride: isWalkIn ? 'Auto-filled from Case Type' : null,
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: Text(
                  'CITY',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addCity,
                icon: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Add City',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _row2(
            _locationDropdown(),
            _readonlyField(
              _districtCtrl,
              'District',
              Icons.location_city_outlined,
            ),
          ),
          const SizedBox(height: 14),
          _row2(
            _readonlyField(_stateCtrl, 'State', Icons.map_outlined),
            _doctorDropdown(),
          ),
          const SizedBox(height: 14),

          if (isPhone) ...[
            _row2(
              _slotDropdown(),
              _textField(
                _ageCtrl,
                'Age *',
                inputType: TextInputType.number,
                required: true,
                maxLength: 3,
              ),
            ),
            const SizedBox(height: 14),
            _row2(_genderDropdown(), _textField(_occupationCtrl, 'Occupation')),
            const SizedBox(height: 14),
            _referrerDropdown(),
          ] else ...[
            _row2(
              _textField(
                _ageCtrl,
                'Age *',
                inputType: TextInputType.number,
                required: true,
                maxLength: 3,
              ),
              _genderDropdown(),
            ),
            const SizedBox(height: 14),
            _row2(
              _textField(_occupationCtrl, 'Occupation'),
              _referrerDropdown(),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: isEdit
                      ? 'Update Patient'
                      : isPhone
                      ? 'Register Phone Appointment'
                      : 'Register Patient',
                  icon: Icons.check_circle_outline_rounded,
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(width: 12),
              AppSecondaryButton(onPressed: widget.onCancel),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Layout helpers ──────────────────────────────────────────────────────

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(children: [a, const SizedBox(height: 14), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType inputType = TextInputType.text,
    bool required = false,
    bool readOnly = false,
    int? maxLength,
    String? Function(String?)? validator,
    String? hintOverride,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      readOnly: readOnly,
      onChanged: onChanged,
      maxLength: maxLength,
      inputFormatters: inputType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: appFieldDecoration(
        label,
        hint: hintOverride ?? hint,
        readOnly: readOnly,
      ).copyWith(counterText: ''),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? '$label is required'
                    : null
              : null),
    );
  }

  Widget _readonlyField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      style: TextStyle(
        color: AppColors.primary.withValues(alpha: 0.65),
        fontWeight: FontWeight.w500,
      ),
      decoration: appFieldDecoration(label, prefix: icon, readOnly: true),
    );
  }

  Widget _datefield() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _apptDateCtrl,
          decoration: appFieldDecoration(
            'Appointment Date *',
            prefix: Icons.calendar_today_outlined,
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Appointment date required' : null,
        ),
      ),
    );
  }

  Widget _contactField() {
    return TextFormField(
      controller: _contactCtrl,
      keyboardType: TextInputType.phone,
      inputFormatters: [LengthLimitingTextInputFormatter(16)],
      onChanged: _onLookupChanged,
      decoration: appFieldDecoration(
        'Contact Number *',
        hint: 'e.g. +91XXXXXXXXXX',
        prefix: Icons.phone_outlined,
      ).copyWith(counterText: ''),
      validator: PhoneRules.required,
    );
  }

  Widget _suggestionDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _suggestions.map((s) {
          final isLocal = s.type == 'local';
          return InkWell(
            onTap: () => _fillFromSuggestion(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        if (s.age != null ||
                            s.gender != null ||
                            (s.contactNo ?? '').isNotEmpty)
                          Text(
                            [
                              if (s.age != null) '${s.age}y',
                              if (s.gender != null)
                                '${s.gender![0].toUpperCase()}${s.gender!.substring(1)}',
                              if ((s.contactNo ?? '').isNotEmpty) s.contactNo!,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isLocal
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: isLocal
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFFC107),
                      ),
                    ),
                    child: Text(
                      isLocal ? 'Own' : s.hospitalName ?? 'Partner',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isLocal
                            ? const Color(0xFF065F46)
                            : const Color(0xFF856404),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required String label,
    String? placeholder,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: appFieldDecoration(label, hint: placeholder),
      style: TextStyle(
        color: AppColors.primary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      icon: Icon(
        Icons.expand_more_rounded,
        color: AppColors.primary.withValues(alpha: 0.6),
      ),
      dropdownColor: Colors.white,
      isExpanded: true,
    );
  }

  Widget _caseTypeDropdown() {
    final cases = _masters?.cases ?? [];
    return _buildDropdown<int>(
      value: _selectedCaseId,
      label: 'Case Type *',
      placeholder: 'Select case type',
      items: cases
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
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
      label: 'Doctor Name *',
      placeholder: 'Select doctor',
      items: docs
          .map(
            (d) => DropdownMenuItem(
              value: d.id,
              child: Text(d.name, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedDoctorId = v),
      validator: (v) => v == null ? 'Doctor required' : null,
    );
  }

  Widget _locationDropdown() {
    final locs = _masters?.locations ?? [];
    return _buildDropdown<int>(
      value: _selectedLocationId,
      label: 'City *',
      placeholder: 'Select city',
      items: locs
          .map(
            (l) => DropdownMenuItem(
              value: l.id,
              child: Text(l.city, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
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
      label: 'Gender *',
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
      ],
      onChanged: (v) => setState(() => _selectedGender = v ?? 'male'),
    );
  }

  Widget _slotDropdown() {
    final slots = _masters?.slots ?? [];
    return _buildDropdown<int>(
      value: _selectedSlotId,
      label: 'Time Slot',
      placeholder: 'No slot (optional)',
      items: slots
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(
                s.display,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedSlotId = v),
    );
  }

  Widget _referrerDropdown() {
    final refs = _masters?.referrers ?? [];
    return _buildDropdown<int>(
      value: _selectedReferrerId,
      label: 'Referred By',
      placeholder: 'No referrer (optional)',
      items: refs
          .map(
            (r) => DropdownMenuItem(
              value: r.id,
              child: Text(r.name, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedReferrerId = v),
    );
  }

  Widget _buildOtCheckinSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _otSearchExpanded = !_otSearchExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OT check-in search (optional)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  Icon(
                    _otSearchExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.blue,
                  ),
                ],
              ),
            ),
          ),
          if (_otSearchExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _otSearchCtrl,
                    onChanged: _linkedOtAppointmentId == null
                        ? _onOtSearchChanged
                        : null,
                    readOnly: _linkedOtAppointmentId != null,
                    decoration:
                        appFieldDecoration(
                          null,
                          hint: 'Search by APT number, name or mobile...',
                          prefix: Icons.search_rounded,
                        ).copyWith(
                          suffixIcon: _otSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : (_linkedOtAppointmentId != null
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        onPressed: _clearOtLink,
                                      )
                                    : null),
                        ),
                  ),
                  if (_otSearchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _otSearchResults
                            .map(
                              (o) => InkWell(
                                onTap: () => _selectOtAppointment(o),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${o.appointmentNumber} — ${o.fullName}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Text(
                                              '${o.mobileNo}${o.doctor != null ? ' · Dr. ${o.doctor!.name}' : ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.55),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (_linkedOtAppointmentId != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Linked to $_linkedOtAppointmentNumber',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarnBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBD0),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: const Border(
          left: BorderSide(color: Color(0xFFE67E22), width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE67E22),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Examination Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF784212),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Primary examination has already been done. Changes will not affect examination data.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF784212)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Color(0xFF784212),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _warnDismissed = true),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt, {bool iso = false}) {
    if (iso) return toIsoDate(dt);
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }
}
