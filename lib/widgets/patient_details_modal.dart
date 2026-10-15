import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/patient_models.dart';
import '../services/masters_service.dart';
import '../services/patient_service.dart';
import '../utils/currency_format.dart';
import '../utils/date_format.dart';
import 'app_animations.dart';
import 'app_dialog.dart';
import 'form_kit.dart';

/// Web pull parity (2026-09-29) — `exam/_patient_info_modal.blade.php`'s
/// "Patient Details" button, shown in the exam header next to the Wait
/// Status pill on both Primary and Secondary Exam. Two sections: an
/// editable Personal Information block (doctor-only on the server, PATCHes
/// `quick-personal`) and a read-only Appointment Information block.
/// See WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #2.
Future<void> showPatientDetailsModal(
  BuildContext context,
  Patient patient, {
  void Function(Patient updated)? onSaved,
}) {
  return showDialog<void>(
    context: context,
    builder: (dCtx) => _PatientDetailsPane(patient: patient, onSaved: onSaved),
  );
}

class _PatientDetailsPane extends StatefulWidget {
  final Patient patient;
  final void Function(Patient updated)? onSaved;
  const _PatientDetailsPane({required this.patient, this.onSaved});

  @override
  State<_PatientDetailsPane> createState() => _PatientDetailsPaneState();
}

class _PatientDetailsPaneState extends State<_PatientDetailsPane> {
  late Patient _patient;
  bool _loading = true;
  bool _ready = false;
  bool _saving = false;
  String? _error;
  List<LocationOption> _locations = const [];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _contactCtrl;
  String? _gender;
  int? _locationId;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _nameCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _contactCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PatientService.instance.fetchOne(widget.patient.id),
        MastersService.instance.fetchAll(),
      ]);
      if (!mounted) return;
      final patient = results[0] as Patient;
      final masters = results[1] as MastersData;
      _apply(patient);
      setState(() {
        _locations = masters.locations;
        _syncChoices();
        _ready = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _ready = false;
          _loading = false;
        });
    }
  }

  void _apply(Patient patient) {
    _patient = patient;
    _nameCtrl.text = patient.fullName;
    _ageCtrl.text = patient.age?.toString() ?? '';
    _contactCtrl.text = patient.contactNo ?? '';
    _gender = patient.gender;
    _locationId = patient.location?.id;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    final contact = _phoneForApi(_contactCtrl.text);
    if (name.isEmpty ||
        age == null ||
        _gender == null ||
        contact.isEmpty ||
        _locationId == null) {
      showAppSnackBar(
        context,
        'Please fill every Personal Information field.',
        isError: true,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await PatientService.instance.quickUpdatePersonal(
        _patient.id,
        fullName: name,
        age: age,
        gender: _gender!,
        contactNo: contact,
        locationId: _locationId!,
      );
      if (!mounted) return;
      setState(() => _patient = updated);
      widget.onSaved?.call(updated);
      showAppSnackBar(context, 'Patient details updated.', isSuccess: true);
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  LocationOption? get _selectedLocation =>
      _locations.where((l) => l.id == _locationId).firstOrNull;

  void _syncChoices() {
    final gender = (_gender ?? '').toLowerCase();
    _gender = (gender == 'male' || gender == 'female' || gender == 'other')
        ? gender
        : null;
    if (!_locations.any((l) => l.id == _locationId)) _locationId = null;
  }

  String _cleanError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty || text == 'Exception') {
      return 'Save failed. Only a doctor can update these details.';
    }
    return text;
  }

  String _phoneForApi(String raw) {
    final t = raw.trim();
    final plus = t.startsWith('+');
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return plus ? '+$digits' : digits;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.medium,
      header: AppDialogHeader(
        icon: Icons.badge_rounded,
        title: _patient.fullName.isNotEmpty ? _patient.fullName : 'Patient',
        subtitle:
            'MRD: ${_patient.patientCode.isNotEmpty ? _patient.patientCode : '—'}',
        onClose: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : !_ready
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _error ?? 'Could not load this patient.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _sectionTitle(Icons.person_rounded, 'Personal Information'),
                const SizedBox(height: 12),
                _buildPersonalForm(),
                const SizedBox(height: 22),
                _sectionTitle(
                  Icons.event_available_rounded,
                  'Appointment Information',
                ),
                const SizedBox(height: 12),
                _buildAppointmentGrid(),
              ],
            ),
      actions: [
        AppSecondaryButton(
          label: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
        AppPrimaryButton(
          label: 'Save Changes',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _ready ? _save : null,
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Divider(height: 1, color: AppColors.primaryA08),
    ],
  );

  Widget _fieldRow(List<Widget> children) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        Expanded(
          flex: i == 0 && children.length == 3 ? 2 : 1,
          child: children[i],
        ),
      ],
    ],
  );

  Widget _buildPersonalForm() {
    return Column(
      children: [
        _fieldRow([
          TextField(
            controller: _nameCtrl,
            decoration: appFieldDecoration('Full Name'),
          ),
          TextField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: appFieldDecoration('Age'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            isExpanded: true,
            decoration: appFieldDecoration('Gender'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
        ]),
        const SizedBox(height: 12),
        _fieldRow([
          TextField(
            controller: _contactCtrl,
            keyboardType: TextInputType.phone,
            decoration: appFieldDecoration('Mobile Number'),
          ),
          DropdownButtonFormField<int>(
            initialValue: _locations.any((l) => l.id == _locationId)
                ? _locationId
                : null,
            isExpanded: true,
            decoration: appFieldDecoration('City'),
            items: _locations
                .map(
                  (l) => DropdownMenuItem(
                    value: l.id,
                    child: Text(l.city, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _locationId = v),
          ),
        ]),
        const SizedBox(height: 12),
        _fieldRow([
          _readonlyField(
            'District',
            _place(_selectedLocation?.district, _patient.location?.district),
          ),
          _readonlyField(
            'State',
            _place(_selectedLocation?.state, _patient.location?.state),
          ),
        ]),
      ],
    );
  }

  Widget _readonlyField(String label, String value) => InputDecorator(
    decoration: appFieldDecoration(label, readOnly: true),
    child: Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );

  String _place(String? selected, String? stored) {
    final a = (selected ?? '').trim();
    if (a.isNotEmpty) return a;
    final b = (stored ?? '').trim();
    return b.isEmpty ? '—' : b;
  }

  String _text(String? value) {
    final t = (value ?? '').trim();
    return t.isEmpty ? '—' : t;
  }

  Widget _buildAppointmentGrid() {
    final date = parseApiPlainDate(_patient.appointmentDate);
    final typeLabel = _patient.type == 'phone'
        ? 'Phone'
        : _patient.type == 'walkin'
        ? 'Walk-in'
        : _text(_patient.type);
    final fee = _patient.caseFee == null
        ? '—'
        : '${currentCurrencySymbol()}${_patient.caseFee!.toStringAsFixed(2)}';
    final row1 = <(String, String)>[
      ('Appointment Date', date != null ? toDisplayDate(date) : '—'),
      ('Type', typeLabel),
      ('Patient Status', _patient.isOldPatient ? 'Old Patient' : 'New Patient'),
      ('Doctor', _text(_patient.doctor?.name)),
    ];
    final row2 = <(String, String)>[
      ('Case Type', _text(_patient.caseType?.caseType)),
      ('Case Fee', fee),
      ('Receptionist', _text(_patient.receptionistName)),
      ('Referrer', _text(_patient.referrer?.name)),
    ];
    return Column(
      children: [_factRow(row1), const SizedBox(height: 10), _factRow(row2)],
    );
  }

  Widget _factRow(List<(String, String)> items) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: _infoTile(items[i].$1, items[i].$2)),
      ],
    ],
  );

  Widget _infoTile(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border.all(color: AppColors.primaryA08),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}
