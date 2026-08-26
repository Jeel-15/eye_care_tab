import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/platform_admin_models.dart';
import '../services/platform_auth_service.dart';
import '../services/platform_profile_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_section_header.dart';

/// Tablet Platform Profile — centered max-width form (personal settings
/// don't need full rail width), matching the hospital-side Profile screen's
/// convention. Business logic (update profile / change password) ported
/// unchanged from eye_care_app/lib/screens/platform_profile_screen.dart.
class PlatformProfileScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformProfileScreen({super.key, required this.admin});

  @override
  State<PlatformProfileScreen> createState() => _PlatformProfileScreenState();
}

class _PlatformProfileScreenState extends State<PlatformProfileScreen> {
  late PlatformAdmin _admin;

  final _profileKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  bool _profileSaving = false;

  final _pwKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _pwSaving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    _admin = widget.admin;
    _nameCtrl = TextEditingController(text: _admin.name);
    _emailCtrl = TextEditingController(text: _admin.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    setState(() => _profileSaving = true);

    final result = await PlatformProfileService.instance.updateProfile(_nameCtrl.text.trim(), _emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _profileSaving = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);

    if (result.success && result.admin != null) {
      setState(() => _admin = result.admin!);
      await PlatformAuthService.instance.refreshSession();
    }
  }

  Future<void> _changePassword() async {
    if (!_pwKey.currentState!.validate()) return;
    setState(() => _pwSaving = true);

    final result = await PlatformProfileService.instance.changePassword(currentPassword: _currentPwCtrl.text, password: _newPwCtrl.text, passwordConfirmation: _confirmPwCtrl.text);

    if (!mounted) return;
    setState(() => _pwSaving = false);
    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);

    if (result.success) {
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(AppRadius.xxl)),
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)),
                    child: Center(child: Text(_admin.initials, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))),
                  ),
                  const SizedBox(height: 12),
                  Text(_admin.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(_admin.email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text(_admin.role.toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
                  ),
                  if (_admin.lastLoginAt != null) ...[
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text('Last login: ${_formatDateTime(_admin.lastLoginAt!)}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                      if (_admin.lastLoginIp != null) ...[const SizedBox(width: 6), Text('· ${_admin.lastLoginIp}', style: const TextStyle(fontSize: 10, color: Colors.white60))],
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
              AppSectionHeader(title: 'Edit Profile', icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: Form(
                  key: _profileKey,
                  child: Column(children: [
                    TextFormField(controller: _nameCtrl, decoration: AppDecorations.inputDecoration(labelText: 'Full Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    const SizedBox(height: 10),
                    TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: AppDecorations.inputDecoration(labelText: 'Email Address *'), validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    }),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _profileSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                        child: _profileSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Update Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              AppSectionHeader(title: 'Change Password', icon: Icons.lock_outline_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card(),
                child: Form(
                  key: _pwKey,
                  child: Column(children: [
                    TextFormField(controller: _currentPwCtrl, obscureText: !_showCurrent, decoration: AppDecorations.inputDecoration(labelText: 'Current Password *', suffixIcon: _eyeToggle(_showCurrent, () => setState(() => _showCurrent = !_showCurrent))), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 10),
                    TextFormField(controller: _newPwCtrl, obscureText: !_showNew, decoration: AppDecorations.inputDecoration(labelText: 'New Password *', suffixIcon: _eyeToggle(_showNew, () => setState(() => _showNew = !_showNew))), validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 8) return 'Minimum 8 characters';
                      return null;
                    }),
                    const SizedBox(height: 10),
                    TextFormField(controller: _confirmPwCtrl, obscureText: !_showConfirm, decoration: AppDecorations.inputDecoration(labelText: 'Confirm New Password *', suffixIcon: _eyeToggle(_showConfirm, () => setState(() => _showConfirm = !_showConfirm))), validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != _newPwCtrl.text) return 'Passwords do not match';
                      return null;
                    }),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _pwSaving ? null : _changePassword,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                        child: _pwSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Change Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eyeToggle(bool visible, VoidCallback onTap) => IconButton(icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppColors.textDisabled), onPressed: onTap);

  String _formatDateTime(DateTime dt) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, $h:$min';
  }
}
