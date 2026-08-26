import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/platform_admin_models.dart';
import '../services/platform_settings_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/skeleton.dart';

/// Tablet Platform Settings — persistent header row (title + Save button)
/// replacing mobile's AppBar action, matching the hospital-side Settings
/// screen's convention. 2-column field pairs within each section card.
/// Business logic (masked secrets, only-send-if-changed) ported unchanged
/// from eye_care_app/lib/screens/platform_settings_screen.dart.
class PlatformSettingsScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformSettingsScreen({super.key, required this.admin});

  @override
  State<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends State<PlatformSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();

  final _platformNameCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _trialDaysCtrl = TextEditingController();

  final _rzKeyCtrl = TextEditingController();
  final _rzSecretCtrl = TextEditingController();
  final _rzWebhookCtrl = TextEditingController();
  bool _hasRzKey = false;
  bool _hasRzSecret = false;
  bool _hasRzWebhook = false;

  final _mailHostCtrl = TextEditingController();
  final _mailPortCtrl = TextEditingController();
  final _mailUserCtrl = TextEditingController();
  final _mailPassCtrl = TextEditingController();
  final _mailFromNameCtrl = TextEditingController();
  final _mailFromEmailCtrl = TextEditingController();
  bool _hasMailPass = false;

  bool _showRzKey = false;
  bool _showRzSecret = false;
  bool _showRzWebhook = false;
  bool _showMailPass = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _platformNameCtrl.dispose();
    _supportEmailCtrl.dispose();
    _trialDaysCtrl.dispose();
    _rzKeyCtrl.dispose();
    _rzSecretCtrl.dispose();
    _rzWebhookCtrl.dispose();
    _mailHostCtrl.dispose();
    _mailPortCtrl.dispose();
    _mailUserCtrl.dispose();
    _mailPassCtrl.dispose();
    _mailFromNameCtrl.dispose();
    _mailFromEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await PlatformSettingsService.instance.getSettings();
    if (!mounted) return;
    if (data == null) {
      setState(() { _loading = false; _error = 'Could not load settings.'; });
      return;
    }
    _platformNameCtrl.text = data.platformName ?? '';
    _supportEmailCtrl.text = data.supportEmail ?? '';
    _trialDaysCtrl.text = data.trialDays ?? '';
    _mailHostCtrl.text = data.mailHost ?? '';
    _mailPortCtrl.text = data.mailPort ?? '';
    _mailUserCtrl.text = data.mailUsername ?? '';
    _mailFromNameCtrl.text = data.mailFromName ?? '';
    _mailFromEmailCtrl.text = data.mailFromEmail ?? '';
    _hasRzKey = data.hasRazorpayKey;
    _hasRzSecret = data.hasRazorpaySecret;
    _hasRzWebhook = data.hasRazorpayWebhookSecret;
    _hasMailPass = data.hasMailPassword;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'platform_name': _platformNameCtrl.text.trim(),
      'support_email': _supportEmailCtrl.text.trim(),
      'trial_days': int.tryParse(_trialDaysCtrl.text.trim()) ?? 14,
      'mail_host': _mailHostCtrl.text.trim().isEmpty ? null : _mailHostCtrl.text.trim(),
      'mail_port': _mailPortCtrl.text.trim().isEmpty ? null : int.tryParse(_mailPortCtrl.text.trim()),
      'mail_username': _mailUserCtrl.text.trim().isEmpty ? null : _mailUserCtrl.text.trim(),
      'mail_from_name': _mailFromNameCtrl.text.trim().isEmpty ? null : _mailFromNameCtrl.text.trim(),
      'mail_from_email': _mailFromEmailCtrl.text.trim().isEmpty ? null : _mailFromEmailCtrl.text.trim(),
    };
    if (_rzKeyCtrl.text.trim().isNotEmpty) data['razorpay_key'] = _rzKeyCtrl.text.trim();
    if (_rzSecretCtrl.text.trim().isNotEmpty) data['razorpay_secret'] = _rzSecretCtrl.text.trim();
    if (_rzWebhookCtrl.text.trim().isNotEmpty) data['razorpay_webhook_secret'] = _rzWebhookCtrl.text.trim();
    if (_mailPassCtrl.text.trim().isNotEmpty) data['mail_password'] = _mailPassCtrl.text.trim();

    final result = await PlatformSettingsService.instance.updateSettings(data);
    if (!mounted) return;
    setState(() => _saving = false);

    showAppSnackBar(context, result.message, isSuccess: result.success, isError: !result.success);
    if (result.success) {
      _rzKeyCtrl.clear();
      _rzSecretCtrl.clear();
      _rzWebhookCtrl.clear();
      _mailPassCtrl.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppSkeletonList(count: 4, itemHeight: 100);
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Platform Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 20),
            AppSectionHeader(title: 'General', icon: Icons.tune_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: _row2(
                _inputField(_platformNameCtrl, 'Platform Name *', required: true),
                _row2(_inputField(_supportEmailCtrl, 'Support Email *', required: true, keyboardType: TextInputType.emailAddress), _inputField(_trialDaysCtrl, 'Default Trial Days *', required: true, keyboardType: TextInputType.number)),
              ),
            ),
            const SizedBox(height: 16),
            AppSectionHeader(title: 'Razorpay', icon: Icons.payment_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: Column(children: [
                _row2(
                  _secretField(controller: _rzKeyCtrl, label: 'API Key', hasValue: _hasRzKey, show: _showRzKey, onToggle: () => setState(() => _showRzKey = !_showRzKey)),
                  _secretField(controller: _rzSecretCtrl, label: 'API Secret', hasValue: _hasRzSecret, show: _showRzSecret, onToggle: () => setState(() => _showRzSecret = !_showRzSecret)),
                ),
                const SizedBox(height: 10),
                _secretField(controller: _rzWebhookCtrl, label: 'Webhook Secret', hasValue: _hasRzWebhook, show: _showRzWebhook, onToggle: () => setState(() => _showRzWebhook = !_showRzWebhook)),
              ]),
            ),
            const SizedBox(height: 16),
            AppSectionHeader(title: 'Email (SMTP)', icon: Icons.email_outlined),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: Column(children: [
                Row(children: [Expanded(child: _inputField(_mailHostCtrl, 'Host')), const SizedBox(width: 10), SizedBox(width: 110, child: _inputField(_mailPortCtrl, 'Port', keyboardType: TextInputType.number))]),
                const SizedBox(height: 10),
                _row2(_inputField(_mailUserCtrl, 'Username'), _secretField(controller: _mailPassCtrl, label: 'Password', hasValue: _hasMailPass, show: _showMailPass, onToggle: () => setState(() => _showMailPass = !_showMailPass))),
                const SizedBox(height: 10),
                _row2(_inputField(_mailFromNameCtrl, 'From Name'), _inputField(_mailFromEmailCtrl, 'From Email', keyboardType: TextInputType.emailAddress)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 480) return Column(children: [a, const SizedBox(height: 10), b]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)]);
    });
  }

  Widget _inputField(TextEditingController ctrl, String label, {bool required = false, TextInputType? keyboardType}) {
    return TextFormField(controller: ctrl, keyboardType: keyboardType, decoration: AppDecorations.inputDecoration(labelText: label), validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null);
  }

  Widget _secretField({required TextEditingController controller, required String label, required bool hasValue, required bool show, required VoidCallback onToggle}) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      decoration: AppDecorations.inputDecoration(labelText: label, hintText: hasValue ? 'Leave empty to keep current' : 'Not set', suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppColors.textDisabled), onPressed: onToggle)),
    );
  }
}
