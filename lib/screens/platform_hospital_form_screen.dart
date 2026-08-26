import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/platform_tenant_models.dart';
import '../services/platform_tenant_service.dart';
import '../utils/app_decorations.dart';
import '../utils/phone_rules.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_section_header.dart';

/// Tablet Hospital create/edit form — embedded in the Hospitals detail pane
/// (Pattern C) instead of being pushed as its own route. Business logic
/// (slug auto-fill, validation, create/update) ported unchanged from
/// eye_care_app/lib/screens/platform_hospital_form_screen.dart.
class PlatformHospitalFormScreen extends StatefulWidget {
  final TenantDetail? tenant; // null = create mode
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const PlatformHospitalFormScreen({super.key, this.tenant, required this.onSaved, required this.onCancel});

  @override
  State<PlatformHospitalFormScreen> createState() => _PlatformHospitalFormScreenState();
}

class _PlatformHospitalFormScreenState extends State<PlatformHospitalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPhone = TextEditingController();
  final _password = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading = false;
  bool _slugEdited = false;
  String _plan = 'monthly';

  bool get _isEdit => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final t = widget.tenant!;
      _nameCtrl.text = t.name;
      _slugCtrl.text = t.slug;
      _adminName.text = t.adminName ?? '';
      _adminPhone.text = t.adminPhone ?? '';
      _city.text = t.city ?? '';
      _state.text = t.state ?? '';
    }
    _nameCtrl.addListener(() {
      if (!_isEdit && !_slugEdited) _slugCtrl.text = _toSlug(_nameCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminPhone.dispose();
    _password.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  String _toSlug(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    late ({bool success, String message}) result;
    if (_isEdit) {
      result = await PlatformTenantService.instance.update(widget.tenant!.id, {
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'admin_name': _adminName.text.trim(),
        'admin_phone': _adminPhone.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
      });
    } else {
      result = await PlatformTenantService.instance.create({
        'hospital_name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'admin_name': _adminName.text.trim(),
        'admin_email': _adminEmail.text.trim(),
        'admin_phone': _adminPhone.text.trim(),
        'password': _password.text,
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'plan': _plan,
      });
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
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
    return Row(children: [
      IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Cancel'),
      Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(_isEdit ? Icons.edit_rounded : Icons.add_business_rounded, color: AppColors.primary, size: 20)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isEdit ? 'Edit Hospital' : 'New Hospital', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Tenant, admin and billing details', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEdit)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.orange.withValues(alpha: 0.25))),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Changing the slug will break existing bookmarks and share links.', style: TextStyle(fontSize: 12, color: AppColors.orange))),
              ]),
            ),
          AppSectionHeader(title: 'Hospital Details', icon: Icons.local_hospital_rounded),
          const SizedBox(height: 10),
          _row2(
            _field(_nameCtrl, 'Hospital Name *', validator: (v) => (v == null || v.trim().length < 3) ? 'Min 3 characters' : null),
            _field(_slugCtrl, 'URL Slug *', hint: 'e.g. apollo-hospital', onChanged: (_) => _slugEdited = true, validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[a-z0-9\-]+$').hasMatch(v.trim())) return 'Only lowercase letters, numbers, hyphens';
              if (v.trim().length < 3) return 'Min 3 characters';
              return null;
            }),
          ),
          const SizedBox(height: 18),
          AppSectionHeader(title: 'Admin Details', icon: Icons.person_rounded),
          const SizedBox(height: 10),
          _row2(
            _field(_adminName, 'Admin Name *', validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            _isEdit ? _field(_adminPhone, 'Admin Phone *', keyboardType: TextInputType.phone, inputFormatters: [LengthLimitingTextInputFormatter(16)], validator: PhoneRules.required) : _field(_adminEmail, 'Admin Email *', keyboardType: TextInputType.emailAddress, validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            }),
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 10),
            _row2(
              _field(_adminPhone, 'Admin Phone *', keyboardType: TextInputType.phone, inputFormatters: [LengthLimitingTextInputFormatter(16)], validator: PhoneRules.required),
              TextFormField(
                controller: _password,
                obscureText: _obscurePass,
                decoration: AppDecorations.inputDecoration(labelText: 'Password *', suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryA45, size: 20), onPressed: () => setState(() => _obscurePass = !_obscurePass))),
                validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
              ),
            ),
          ],
          const SizedBox(height: 18),
          AppSectionHeader(title: 'Location (Optional)', icon: Icons.location_on_rounded),
          const SizedBox(height: 10),
          _row2(_field(_city, 'City'), _field(_state, 'State')),
          if (!_isEdit) ...[
            const SizedBox(height: 18),
            AppSectionHeader(title: 'Billing Plan', icon: Icons.payment_rounded),
            const SizedBox(height: 10),
            Row(
              children: ['monthly', 'quarterly', 'yearly'].map((p) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p[0].toUpperCase() + p.substring(1)),
                    selected: _plan == p,
                    onSelected: (_) => setState(() => _plan = p),
                    selectedColor: AppColors.primaryA15,
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _plan == p ? AppColors.primary : AppColors.textSecondary),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: _plan == p ? AppColors.primary : AppColors.primaryA12),
                  ),
                ),
              )).toList(),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text('Hospital will start on a trial period regardless of plan selection.', style: TextStyle(fontSize: 11, color: AppColors.secondary))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : Text(_isEdit ? 'Save Changes' : 'Create Hospital', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) return Column(children: [a, const SizedBox(height: 12), b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onChanged, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: AppDecorations.inputDecoration(labelText: label, hintText: hint),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      validator: validator,
    );
  }
}
