import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/user_service.dart';
import '../utils/phone_rules.dart';
import '../widgets/app_animations.dart';

enum UserFormMode { add, edit }

/// Tablet user add/edit form — embedded in the Users detail pane (Pattern C:
/// 2-column field grid) instead of being pushed as its own route, matching
/// [PatientFormScreen]'s convention. Business logic (form-data load, image
/// pick/size-check, submit) ported unchanged from
/// eye_care_app/lib/screens/user_form_screen.dart.
class UserFormPane extends StatefulWidget {
  final UserFormMode mode;
  final HospitalUserModel? editUser;
  final void Function(HospitalUserModel saved) onSaved;
  final VoidCallback onCancel;

  const UserFormPane({super.key, required this.mode, this.editUser, required this.onSaved, required this.onCancel});

  @override
  State<UserFormPane> createState() => _UserFormPaneState();
}

class _UserFormPaneState extends State<UserFormPane> {
  bool get _isEdit => widget.mode == UserFormMode.edit;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _expYrsCtrl = TextEditingController();

  String _status = 'active';
  String _doctorType = 'primary';
  bool _focPerm = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _saving = false;

  UserRole? _selectedRole;
  List<UserRole> _roles = [];
  bool _loadingForm = true;
  String? _formError;

  File? _signatureFile;
  File? _profilePhotoFile;
  String? _existingSignatureUrl;
  String? _existingPhotoUrl;
  bool _clearSignature = false;
  bool _clearProfilePhoto = false;

  bool get _isDoctorRole => _selectedRole?.isDoctorRole == true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfCtrl.dispose();
    _prefixCtrl.dispose();
    _regNoCtrl.dispose();
    _expYrsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final data = await UserService.instance.fetchFormData();
      if (!mounted) return;
      setState(() {
        _roles = data.roles;
        _loadingForm = false;
      });
      if (_isEdit) _fillFromEdit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = e.toString().replaceFirst('Exception: ', '');
        _loadingForm = false;
      });
    }
  }

  void _fillFromEdit() {
    final u = widget.editUser!;
    _nameCtrl.text = u.name;
    _emailCtrl.text = u.email;
    _contactCtrl.text = u.contact;
    _status = u.status;
    _focPerm = u.focPermission;
    if (u.role != null) {
      _selectedRole = _roles.firstWhere((r) => r.id == u.role!.id, orElse: () => u.role!);
    }
    _doctorType = u.doctorType ?? 'primary';
    _prefixCtrl.text = u.doctorPrefix ?? '';
    _regNoCtrl.text = u.registrationNo ?? '';
    _expYrsCtrl.text = u.experienceYears?.toString() ?? '';
    _existingSignatureUrl = u.signatureUrl;
    _existingPhotoUrl = u.profilePhotoUrl;
    setState(() {});
  }

  Future<void> _pickImage(bool isSignature) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);
    if (picked == null) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > 20 * 1024) {
      if (mounted) showAppSnackBar(context, 'Image must be under 20 KB. Please choose a smaller/more compressed image.');
      return;
    }
    setState(() {
      if (isSignature) {
        _signatureFile = file;
        _clearSignature = false;
      } else {
        _profilePhotoFile = file;
        _clearProfilePhoto = false;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      showAppSnackBar(context, 'Please select a role.');
      return;
    }
    setState(() => _saving = true);
    try {
      final HospitalUserModel saved;
      if (_isEdit) {
        saved = await UserService.instance.updateUser(
          widget.editUser!.id,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          contact: _contactCtrl.text.trim(),
          roleId: _selectedRole!.id,
          password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
          passwordConfirmation: _passwordCtrl.text.isNotEmpty ? _passwordConfCtrl.text : null,
          status: _status,
          doctorType: _isDoctorRole ? _doctorType : null,
          doctorPrefix: _isDoctorRole && _prefixCtrl.text.trim().isNotEmpty ? _prefixCtrl.text.trim().toUpperCase() : null,
          registrationNo: _isDoctorRole && _regNoCtrl.text.trim().isNotEmpty ? _regNoCtrl.text.trim() : null,
          experienceYears: _isDoctorRole && _expYrsCtrl.text.isNotEmpty ? int.tryParse(_expYrsCtrl.text) : null,
          focPermission: _isDoctorRole ? _focPerm : false,
          signature: _signatureFile,
          clearSignature: _clearSignature,
          profilePhoto: _profilePhotoFile,
          clearProfilePhoto: _clearProfilePhoto,
        );
      } else {
        saved = await UserService.instance.createUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          contact: _contactCtrl.text.trim(),
          roleId: _selectedRole!.id,
          password: _passwordCtrl.text,
          passwordConfirmation: _passwordConfCtrl.text,
          status: _status,
          doctorType: _isDoctorRole ? _doctorType : null,
          doctorPrefix: _isDoctorRole && _prefixCtrl.text.trim().isNotEmpty ? _prefixCtrl.text.trim().toUpperCase() : null,
          registrationNo: _isDoctorRole && _regNoCtrl.text.trim().isNotEmpty ? _regNoCtrl.text.trim() : null,
          experienceYears: _isDoctorRole && _expYrsCtrl.text.isNotEmpty ? int.tryParse(_expYrsCtrl.text) : null,
          focPermission: _isDoctorRole ? _focPerm : false,
          signature: _signatureFile,
          profilePhoto: _profilePhotoFile,
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _pickRole() async {
    final picked = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => _RolePickerDialog(roles: _roles, selected: _selectedRole),
    );
    if (picked != null) {
      setState(() {
        _selectedRole = picked;
        if (!picked.isDoctorRole) _focPerm = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingForm) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_formError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_formError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _loadFormData, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
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
    return Row(
      children: [
        IconButton(icon: Icon(Icons.close_rounded, color: AppColors.primary), onPressed: widget.onCancel, tooltip: 'Cancel'),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primaryA10, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(_isEdit ? Icons.edit_rounded : Icons.person_add_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit User' : 'Add User', style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Manage account, role and doctor details', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            icon: Icons.person_outline_rounded,
            label: 'BASIC INFORMATION',
            children: [
              _row2(
                _field('Full Name *', _styledField(controller: _nameCtrl, hint: 'Enter full name', textCapitalization: TextCapitalization.words, validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null)),
                _field('Email Address *', _styledField(controller: _emailCtrl, hint: 'Enter email address', keyboardType: TextInputType.emailAddress, validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                })),
              ),
              _field('Contact Number', _styledField(controller: _contactCtrl, hint: 'Contact number (e.g. +91XXXXXXXXXX)', keyboardType: TextInputType.phone, maxLength: 16, validator: PhoneRules.nullable), fullWidth: true),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.admin_panel_settings_rounded,
            label: 'ROLE & STATUS',
            children: [
              _field('Role *', _buildRolePicker()),
              if (_selectedRole?.isSuper == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.orange.withValues(alpha: 0.30))),
                  child: Row(children: [
                    Icon(Icons.shield_rounded, size: 16, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Super Admin role — bypasses all permission checks.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.orange))),
                  ]),
                ),
              ],
              const SizedBox(height: 4),
              _field('Status *', Row(children: [
                Expanded(child: _statusOption('Active', true, _status == 'active', () => setState(() => _status = 'active'))),
                const SizedBox(width: 10),
                Expanded(child: _statusOption('Inactive', false, _status == 'inactive', () => setState(() => _status = 'inactive'))),
              ])),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            icon: Icons.lock_outline_rounded,
            label: 'SECURITY',
            children: [
              _row2(
                _field(_isEdit ? 'New Password (leave blank to keep)' : 'Password *', _passwordField(_passwordCtrl, _showPassword, () => setState(() => _showPassword = !_showPassword), hint: _isEdit ? 'Enter new password to change' : 'Minimum 8 characters', validator: (v) {
                  if (!_isEdit && (v == null || v.isEmpty)) return 'Password is required';
                  if (v != null && v.isNotEmpty && v.length < 8) return 'Password must be at least 8 characters';
                  return null;
                })),
                _field(_isEdit ? 'Confirm New Password' : 'Confirm Password *', _passwordField(_passwordConfCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm), hint: 'Re-enter password', validator: (v) {
                  if (_passwordCtrl.text.isNotEmpty && v != _passwordCtrl.text) return 'Passwords do not match';
                  if (!_isEdit && (v == null || v.isEmpty)) return 'Please confirm password';
                  return null;
                })),
              ),
            ],
          ),
          if (_isDoctorRole) ...[
            const SizedBox(height: 16),
            _sectionCard(icon: Icons.medical_services_rounded, label: 'DOCTOR DETAILS', badgeText: 'Auto-detected from role', children: [
              _field('Doctor Type', Row(children: [
                Expanded(child: _doctorTypeOption('Primary', 'Ophthalmologist', _doctorType == 'primary', () => setState(() => _doctorType = 'primary'))),
                const SizedBox(width: 10),
                Expanded(child: _doctorTypeOption('Secondary', 'Optometrist', _doctorType == 'secondary', () => setState(() => _doctorType = 'secondary'))),
              ])),
              _row2(
                _field('Prefix (2–5 letters)', _styledField(controller: _prefixCtrl, hint: 'e.g. DR', maxLength: 5, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')), _UpperCaseFormatter()], validator: (v) => (v != null && v.isNotEmpty && v.length < 2) ? 'Min 2 letters' : null)),
                _field('Exp. Years', _styledField(controller: _expYrsCtrl, hint: '0–60', keyboardType: TextInputType.number, maxLength: 2, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = int.tryParse(v);
                  if (n == null || n < 0 || n > 60) return '0–60';
                  return null;
                })),
              ),
              _field('Registration Number', _styledField(controller: _regNoCtrl, hint: 'Medical council registration no.'), fullWidth: true),
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.primaryA05, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA10)),
                child: SwitchListTile(
                  title: Text('FOC Permission', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                  subtitle: Text('Allow this doctor to mark visits as free of charge', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  value: _focPerm,
                  onChanged: (v) => setState(() => _focPerm = v),
                  activeThumbColor: AppColors.primary,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _imageUploadCard(label: 'Profile Photo', existingUrl: _clearProfilePhoto ? null : _existingPhotoUrl, pickedFile: _profilePhotoFile, onPick: () => _pickImage(false), onClear: () => setState(() {
                  _profilePhotoFile = null;
                  _existingPhotoUrl = null;
                  _clearProfilePhoto = true;
                }))),
                const SizedBox(width: 10),
                Expanded(child: _imageUploadCard(label: 'Signature', existingUrl: _clearSignature ? null : _existingSignatureUrl, pickedFile: _signatureFile, onPick: () => _pickImage(true), onClear: () => setState(() {
                  _signatureFile = null;
                  _existingSignatureUrl = null;
                  _clearSignature = true;
                }))),
              ]),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.orange.withValues(alpha: 0.25))),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Images must be under 20 KB (JPG/PNG). Use low-resolution photos.', style: TextStyle(fontSize: 11, color: AppColors.orange, fontWeight: FontWeight.w600))),
                ]),
              ),
            ]),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Update User' : 'Create User', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Field helpers (mirrors PatientFormScreen's 2-col Pattern C) ──────────

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 520) return Column(children: [a, b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _field(String label, Widget child, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        child,
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        filled: true,
        fillColor: AppColors.primaryA05,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primaryA50, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.red)),
        counterText: '',
        suffixIcon: suffix,
      );

  Widget _styledField({required TextEditingController controller, String? hint, TextInputType? keyboardType, int? maxLength, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
      decoration: _inputDeco(hint ?? ''),
    );
  }

  Widget _passwordField(TextEditingController ctrl, bool visible, VoidCallback onToggle, {required String hint, required String? Function(String?) validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      validator: validator,
      style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
      decoration: _inputDeco(hint, suffix: IconButton(icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppColors.textSecondary), onPressed: onToggle)),
    );
  }

  Widget _buildRolePicker() {
    return GestureDetector(
      onTap: _pickRole,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: AppColors.primaryA05, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA12)),
        child: Row(children: [
          if (_selectedRole != null) ...[
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _selectedRole!.parsedColor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(_selectedRole!.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary))),
          ] else
            Expanded(child: Text('Select a role', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _statusOption(String label, bool isActive, bool selected, VoidCallback onTap) {
    final color = isActive ? AppColors.green : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? color.withValues(alpha: 0.10) : Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? color : AppColors.primaryA12, width: selected ? 2 : 1)),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 15, color: selected ? color : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? color : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _doctorTypeOption(String label, String subtitle, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: selected ? AppColors.primaryA07 : Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: selected ? AppColors.primaryA50 : AppColors.primaryA12, width: selected ? 1.8 : 1)),
        child: Column(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: selected ? AppColors.primary : AppColors.textSecondary)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: selected ? AppColors.primaryA60 : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _imageUploadCard({required String label, String? existingUrl, File? pickedFile, required VoidCallback onPick, required VoidCallback onClear}) {
    final hasImage = pickedFile != null || (existingUrl != null && existingUrl.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 100,
            decoration: BoxDecoration(color: AppColors.primaryA05, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: hasImage ? AppColors.primaryA30 : AppColors.primaryA12)),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? (pickedFile != null
                    ? Stack(fit: StackFit.expand, children: [
                        Image.file(pickedFile, fit: BoxFit.cover),
                        Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.sm)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
                      ])
                    : Image.network(existingUrl!, fit: BoxFit.cover, errorBuilder: (ctx, e, s) => _imageEmptyState()))
                : _imageEmptyState(),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(onTap: onClear, child: Text('Remove', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.red))),
          ),
      ],
    );
  }

  Widget _imageEmptyState() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_photo_alternate_rounded, size: 28, color: AppColors.primaryA30),
        const SizedBox(height: 6),
        Text('Tap to upload', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ]);

  Widget _sectionCard({required IconData icon, required String label, String? badgeText, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.primaryA07), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: AppColors.primary)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.primaryA75)),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.blueA12, borderRadius: BorderRadius.circular(AppRadius.xl)), child: Text(badgeText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.blue))),
              ],
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ],
      ),
    );
  }
}

// ── Role picker dialog ────────────────────────────────────────────────────

class _RolePickerDialog extends StatefulWidget {
  final List<UserRole> roles;
  final UserRole? selected;

  const _RolePickerDialog({required this.roles, this.selected});

  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  final _searchCtrl = TextEditingController();
  List<UserRole> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.roles;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {
      _filtered = v.isEmpty ? widget.roles : widget.roles.where((r) => r.name.toLowerCase().contains(v.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(children: [
              Text('Select Role', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.primary)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search roles...',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.primaryA05,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final role = _filtered[i];
                final color = role.parsedColor;
                final isSelected = widget.selected?.id == role.id;
                return ListTile(
                  onTap: () => Navigator.pop(context, role),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  tileColor: isSelected ? AppColors.primaryA06 : null,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.30))),
                    child: Center(child: Text(role.name.isNotEmpty ? role.name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14))),
                  ),
                  title: Text(role.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? AppColors.primary : AppColors.textPrimary, fontSize: 14)),
                  subtitle: Row(children: [
                    if (role.isDoctorRole) _roleBadge('Doctor', AppColors.blue, AppColors.blueA12),
                    if (role.isSuper) _roleBadge('Super Admin', AppColors.orange, AppColors.orangeA12),
                  ]),
                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) : null,
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _roleBadge(String text, Color textColor, Color bgColor) => Container(
        margin: const EdgeInsets.only(right: 4, top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: textColor)),
      );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}
