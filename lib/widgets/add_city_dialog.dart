import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/patient_models.dart';
import '../services/masters_service.dart';
import 'app_dialog.dart';
import 'form_kit.dart';

/// The one "Add City" dialog (Patient form, OT Appointment form). Saves the
/// location itself — spinner on Add, inline error on failure — and returns
/// the created [LocationOption], or null when cancelled. City and State are
/// required, matching web's `reception-patient-form.js`.
Future<LocationOption?> showAddCityDialog(BuildContext context) =>
    showDialog<LocationOption>(context: context, builder: (_) => const _AddCityDialog());

class _AddCityDialog extends StatefulWidget {
  const _AddCityDialog();

  @override
  State<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<_AddCityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _distCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final loc = await MastersService.instance.addLocation(city: _cityCtrl.text.trim(), district: _distCtrl.text.trim(), state: _stateCtrl.text.trim());
      if (mounted) Navigator.pop(context, loc);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(icon: Icons.add_location_alt_outlined, title: 'Add City', onClose: _saving ? null : () => Navigator.pop(context)),
      body: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.red.withValues(alpha: 0.25))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.red))),
              ]),
            ),
          TextFormField(controller: _cityCtrl, autofocus: true, textCapitalization: TextCapitalization.words, decoration: appFieldDecoration('City *', prefix: Icons.location_city_rounded), validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null),
          const SizedBox(height: 14),
          AppFormRow(children: [
            TextFormField(controller: _distCtrl, textCapitalization: TextCapitalization.words, decoration: appFieldDecoration('District', prefix: Icons.map_outlined)),
            TextFormField(controller: _stateCtrl, textCapitalization: TextCapitalization.words, decoration: appFieldDecoration('State *', prefix: Icons.public_rounded), validator: (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null),
          ]),
        ]),
      ),
      actions: [
        AppSecondaryButton(onPressed: _saving ? null : () => Navigator.pop(context)),
        AppPrimaryButton(label: 'Add', loading: _saving, onPressed: _save),
      ],
    );
  }
}
