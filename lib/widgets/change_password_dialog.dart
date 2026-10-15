import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_animations.dart';
import 'app_dialog.dart';
import 'form_kit.dart';

/// Current / new / confirm password form shared by Settings and Profile,
/// which save through different endpoints — each passes its own [onSubmit].
/// A throw from [onSubmit] keeps the dialog open and shows the message.
class ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String currentPassword, String newPassword, String confirmPassword) onSubmit;
  final VoidCallback onSuccess;

  const ChangePasswordDialog({super.key, required this.onSubmit, required this.onSuccess});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_currentCtrl.text, _newCtrl.text, _confirmCtrl.text);
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
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(icon: Icons.password_rounded, title: 'Change Password', onClose: _saving ? null : () => Navigator.pop(context)),
      body: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _field('Current Password', _currentCtrl, _showCurrent, () => setState(() => _showCurrent = !_showCurrent), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
          const SizedBox(height: 14),
          _field('New Password (min 8 chars)', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew), validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v.length < 8) return 'Minimum 8 characters';
            return null;
          }),
          const SizedBox(height: 14),
          _field('Confirm New Password', _confirmCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm), validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v != _newCtrl.text) return 'Passwords do not match';
            return null;
          }),
        ]),
      ),
      actions: [
        AppSecondaryButton(onPressed: _saving ? null : () => Navigator.pop(context)),
        AppPrimaryButton(label: 'Update Password', icon: Icons.check_rounded, loading: _saving, onPressed: _submit),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool show, VoidCallback toggleShow, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkNavy),
      decoration: appFieldDecoration(label, suffix: IconButton(icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.primaryA35), onPressed: toggleShow)),
      validator: validator,
    );
  }
}
