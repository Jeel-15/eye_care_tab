import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../models/auth_models.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../widgets/app_animations.dart';

/// Tablet Profile screen — centered max-width form (personal settings don't
/// need full rail-content width) instead of mobile's AppBar+footer sandwich.
/// Change Password is a dialog instead of an inline expandable card.
/// Business logic ported unchanged from eye_care_app/lib/screens/profile_screen.dart.
class ProfileScreen extends StatefulWidget {
  final UserInfo user;
  final HospitalInfo hospital;

  const ProfileScreen({super.key, required this.user, required this.hospital});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileData? _profile;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  bool _isDirty = false;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final TextEditingController _regNoCtrl = TextEditingController();
  final TextEditingController _expYearsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _regNoCtrl.dispose();
    _expYearsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await ProfileService.instance.fetchProfile();
      if (!mounted) return;
      _nameCtrl.text = profile.name;
      _emailCtrl.text = profile.email;
      if (profile.isDoctor) {
        _regNoCtrl.text = profile.registrationNo ?? '';
        _expYearsCtrl.text = profile.experienceYears?.toString() ?? '';
      }
      setState(() { _profile = profile; _loading = false; _isDirty = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final isDoctor = _profile?.isDoctor ?? false;
      final regNo = _regNoCtrl.text.trim();
      final expStr = _expYearsCtrl.text.trim();
      final updated = await ProfileService.instance.updateProfile(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        registrationNo: isDoctor ? (regNo.isEmpty ? null : regNo) : null,
        experienceYears: isDoctor && expStr.isNotEmpty ? int.tryParse(expStr) : null,
      );
      if (!mounted) return;
      setState(() { _profile = updated; _saving = false; _isDirty = false; });
      _snack('Profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    showAppSnackBar(context, msg, isError: isError, isSuccess: !isError, duration: Duration(milliseconds: isError ? 4000 : 2500));
  }

  void _showChangePasswordDialog() {
    final p = _profile;
    if (p == null) return;
    showDialog(context: context, builder: (_) => _ChangePasswordDialog(currentName: p.name, currentEmail: p.email, onSuccess: () => _snack('Password changed successfully.')));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return _buildError();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(key: _formKey, child: _buildBody()),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.red.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildAccountSection(),
          if (_profile?.isDoctor == true) ...[const SizedBox(height: 16), _buildDoctorSection()],
          const SizedBox(height: 16),
          _buildSecuritySection(),
          if (kDebugMode) ...[const SizedBox(height: 16), _buildDebugSection()],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isDirty && !_saving) ? _save : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primaryA35, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final profile = _profile;
    final name = profile?.name ?? widget.user.name;
    final email = profile?.email ?? widget.user.email;
    final contact = profile?.contact ?? widget.user.contact;
    final role = profile?.role;
    final roleName = role?.name ?? widget.user.role?.name;

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.blueLight]), borderRadius: BorderRadius.circular(AppRadius.xxl)),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.20), border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 2)),
          child: Text(_initials(name), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        const SizedBox(height: 14),
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.70))),
        if (contact != null && contact.isNotEmpty) ...[const SizedBox(height: 2), Text(contact, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.70)))],
        const SizedBox(height: 14),
        if (roleName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Text(roleName.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
          ),
      ]),
    );
  }

  Widget _buildAccountSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('ACCOUNT INFORMATION', Icons.person_outline_rounded),
      const SizedBox(height: 10),
      _card([
        _fieldRow(label: 'FULL NAME', ctrl: _nameCtrl, suffix: Icons.edit_outlined, textCapitalization: TextCapitalization.words, validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
        const SizedBox(height: 16),
        _fieldRow(label: 'EMAIL ADDRESS', ctrl: _emailCtrl, suffix: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null),
      ]),
    ]);
  }

  Widget _buildDoctorSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('DOCTOR INFORMATION', Icons.medical_services_outlined),
      const SizedBox(height: 10),
      _card([
        _fieldRow(label: 'REGISTRATION NO.', ctrl: _regNoCtrl, suffix: Icons.badge_outlined, textCapitalization: TextCapitalization.characters),
        const SizedBox(height: 16),
        _fieldRow(label: 'EXPERIENCE (YEARS)', ctrl: _expYearsCtrl, suffix: Icons.work_history_outlined, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
          if (v == null || v.isEmpty) return null;
          final n = int.tryParse(v);
          if (n == null || n < 0 || n > 60) return 'Enter 0–60';
          return null;
        }),
      ]),
    ]);
  }

  Widget _buildSecuritySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('SECURITY', Icons.security_rounded),
      const SizedBox(height: 10),
      _card([
        InkWell(
          onTap: _showChangePasswordDialog,
          borderRadius: BorderRadius.circular(10),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)), alignment: Alignment.center, child: Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
            Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primaryA50),
          ]),
        ),
      ]),
    ]);
  }

  // Debug-only — never rendered in a release build (see kDebugMode guard at
  // the call site). Lets a developer replay the one-time onboarding tour
  // without uninstalling the app.
  Widget _buildDebugSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('DEVELOPER', Icons.bug_report_outlined),
      const SizedBox(height: 10),
      _card([
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await OnboardingService.instance.resetForTesting();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding will show again on next app open.')));
          },
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)), alignment: Alignment.center, child: Icon(Icons.replay_rounded, color: AppColors.primary, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text('Reset Onboarding', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkNavy))),
            Icon(Icons.chevron_right_rounded, size: 24, color: AppColors.primaryA50),
          ]),
        ),
      ]),
    ]);
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primaryA50),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA50, letterSpacing: 1.4)),
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primaryA08), boxShadow: [BoxShadow(color: AppColors.primaryA05, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _fieldRow({required String label, required TextEditingController ctrl, IconData? suffix, TextInputType? keyboardType, TextCapitalization textCapitalization = TextCapitalization.none, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkNavy),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            validator: validator,
            onChanged: (_) => _markDirty(),
          ),
        ),
        if (suffix != null) Icon(suffix, size: 20, color: AppColors.primary.withValues(alpha: 0.30)),
      ]),
      Divider(height: 1, color: AppColors.primaryA18),
    ]);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final words = parts.where((p) => !(p.length <= 4 && p.endsWith('.'))).toList();
    final effective = words.isEmpty ? parts : words;
    if (effective.length == 1) {
      final w = effective[0];
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w[0].toUpperCase();
    }
    return '${effective[0][0]}${effective[1][0]}'.toUpperCase();
  }
}

// ── Change Password Dialog ──────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final VoidCallback onSuccess;
  const _ChangePasswordDialog({required this.currentName, required this.currentEmail, required this.onSuccess});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _saving = false;
  bool _showCur = false;
  bool _showNew = false;
  bool _showConf = false;

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ProfileService.instance.updateProfile(name: widget.currentName, email: widget.currentEmail, currentPassword: _curCtrl.text, newPassword: _newCtrl.text);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true, duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primaryA08, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.password_rounded, size: 20, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              _pwField('Current Password', _curCtrl, _showCur, () => setState(() => _showCur = !_showCur), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
              const SizedBox(height: 14),
              _pwField('New Password (min 8 chars)', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew), validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              }),
              const SizedBox(height: 14),
              _pwField('Confirm New Password', _confCtrl, _showConf, () => setState(() => _showConf = !_showConf), validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primaryA35, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)), elevation: 0),
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggleShow, {String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryA40, letterSpacing: 1.0)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: ctrl,
            obscureText: !show,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkNavy),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            validator: validator,
          ),
        ),
        GestureDetector(onTap: toggleShow, child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.primaryA35)),
      ]),
      Divider(height: 1, color: AppColors.primaryA18),
    ]);
  }
}
