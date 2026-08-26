import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_text_styles.dart';
import '../models/platform_admin_models.dart';
import '../models/platform_plan_models.dart';
import '../services/platform_plan_service.dart';
import '../utils/app_decorations.dart';
import '../widgets/app_animations.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_section_header.dart';

/// Tablet Plans & Pricing — single scrollable page (embedded, no own
/// Scaffold/AppBar since it's rail content). Edit-pricing uses a Dialog
/// instead of mobile's `DraggableScrollableSheet`, matching the tablet
/// dialog convention established since Phase 5. Business logic
/// (load/update, discount math already computed server-side) ported
/// unchanged from eye_care_app/lib/screens/platform_plans_screen.dart.
class PlatformPlansScreen extends StatefulWidget {
  final PlatformAdmin admin;

  const PlatformPlansScreen({super.key, required this.admin});

  @override
  State<PlatformPlansScreen> createState() => _PlatformPlansScreenState();
}

class _PlatformPlansScreenState extends State<PlatformPlansScreen> {
  bool _loading = true;
  String? _error;
  PlatformPlanData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await PlatformPlanService.instance.getPlans();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = 'Could not load plan data.';
      } else {
        _data = data;
      }
    });
  }

  void _showEditDialog() {
    final d = _data!;
    showDialog(
      context: context,
      builder: (_) => _EditPlanDialog(initial: d, onSaved: (updated) {
        setState(() => _data = updated);
        showAppSnackBar(context, 'Plan pricing updated.', isSuccess: true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final d = _data!;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('Plans & Pricing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary))),
              ElevatedButton.icon(onPressed: _showEditDialog, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Edit Pricing'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
            ]),
            const SizedBox(height: 16),
            _TrialBanner(data: d),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final cards = [
                _PlanCard(cycle: 'Monthly', icon: Icons.calendar_today_rounded, price: d.monthlyPrice, subLabel: '₹${d.monthlyPrice}/month', savingLabel: null, color: AppColors.primary),
                _PlanCard(cycle: 'Quarterly', icon: Icons.calendar_month_rounded, price: d.quarterlyPrice, subLabel: '₹${d.monthlyPrice}/month (billed ₹${d.quarterlyOriginal})', savingLabel: 'Save ${d.quarterlyDiscount}%', color: AppColors.teal),
                _PlanCard(cycle: 'Yearly', icon: Icons.workspace_premium_rounded, price: d.yearlyPrice, subLabel: '₹${d.monthlyPrice}/month (billed ₹${d.yearlyOriginal})', savingLabel: 'Save ${d.yearlyDiscount}%', color: AppColors.orange),
              ];
              if (!wide) return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: c)]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ]);
            }),
            const SizedBox(height: 20),
            const AppSectionHeader(title: "What's Included"),
            const SizedBox(height: 10),
            ...d.features.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: AppTextStyles.bodyMedium)),
                  ]),
                )),
          ],
        ),
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  final PlatformPlanData data;
  const _TrialBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.md)), child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Free Trial Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('${data.trialDays} days trial  •  ${data.graceDays} days grace period', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String cycle;
  final IconData icon;
  final int price;
  final String subLabel;
  final String? savingLabel;
  final Color color;

  const _PlanCard({required this.cycle, required this.icon, required this.price, required this.subLabel, required this.savingLabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cycle, style: AppTextStyles.cardTitle), const SizedBox(height: 2), Text(subLabel, style: AppTextStyles.cardSubtitle, overflow: TextOverflow.ellipsis)])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹$price', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          if (savingLabel != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)), child: Text(savingLabel!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green))),
        ]),
      ]),
    );
  }
}

// ── Edit Plan Dialog ─────────────────────────────────────────────────────

class _EditPlanDialog extends StatefulWidget {
  final PlatformPlanData initial;
  final void Function(PlatformPlanData updated) onSaved;

  const _EditPlanDialog({required this.initial, required this.onSaved});

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qDiscCtrl;
  late final TextEditingController _yDiscCtrl;
  late final TextEditingController _trialCtrl;
  late final TextEditingController _graceCtrl;
  late List<String> _features;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _priceCtrl = TextEditingController(text: d.monthlyPrice.toString());
    _qDiscCtrl = TextEditingController(text: d.quarterlyDiscount.toString());
    _yDiscCtrl = TextEditingController(text: d.yearlyDiscount.toString());
    _trialCtrl = TextEditingController(text: d.trialDays.toString());
    _graceCtrl = TextEditingController(text: d.graceDays.toString());
    _features = List.of(d.features);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qDiscCtrl.dispose();
    _yDiscCtrl.dispose();
    _trialCtrl.dispose();
    _graceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final result = await PlatformPlanService.instance.updatePlans({
      'monthly_price': int.parse(_priceCtrl.text.trim()),
      'quarterly_discount': int.parse(_qDiscCtrl.text.trim()),
      'yearly_discount': int.parse(_yDiscCtrl.text.trim()),
      'trial_days': int.parse(_trialCtrl.text.trim()),
      'grace_days': int.parse(_graceCtrl.text.trim()),
      'features': _features.where((f) => f.trim().isNotEmpty).toList(),
    });

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      final updated = await PlatformPlanService.instance.getPlans();
      if (mounted) {
        Navigator.pop(context);
        if (updated != null) widget.onSaved(updated);
      }
    } else {
      showAppSnackBar(context, result.message, isError: true);
    }
  }

  void _addFeature() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Add Feature', style: AppTextStyles.headingSmall),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Feature description')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) setState(() => _features.add(text));
              Navigator.pop(context);
            },
            child: Text('Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        width: 480,
        height: 640,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [
                  Expanded(child: Text('Edit Plan Pricing', style: AppTextStyles.headingSmall)),
                  IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              Divider(color: AppColors.primaryA12, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(title: 'Pricing'),
                      const SizedBox(height: 10),
                      _field(_priceCtrl, 'Monthly Price (₹)', min: 1, max: 99999),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: _field(_qDiscCtrl, 'Quarterly Discount %', min: 0, max: 70)), const SizedBox(width: 10), Expanded(child: _field(_yDiscCtrl, 'Yearly Discount %', min: 0, max: 70))]),
                      const SizedBox(height: 16),
                      const AppSectionHeader(title: 'Trial & Grace'),
                      const SizedBox(height: 10),
                      Row(children: [Expanded(child: _field(_trialCtrl, 'Trial Days', min: 1, max: 90)), const SizedBox(width: 10), Expanded(child: _field(_graceCtrl, 'Grace Days', min: 1, max: 30))]),
                      const SizedBox(height: 16),
                      AppSectionHeader(title: 'Features', trailing: IconButton(onPressed: _addFeature, icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22), tooltip: 'Add feature', padding: EdgeInsets.zero, constraints: const BoxConstraints())),
                      const SizedBox(height: 6),
                      ..._features.asMap().entries.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: AppDecorations.card(),
                            child: Row(children: [
                              Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.green),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.value, style: AppTextStyles.bodyMedium)),
                              GestureDetector(onTap: () => setState(() => _features.removeAt(e.key)), child: Icon(Icons.close_rounded, size: 18, color: AppColors.textDisabled)),
                            ]),
                          )),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Save Changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {required int min, required int max}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: AppDecorations.inputDecoration(labelText: label),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null) return 'Required';
        if (n < min || n > max) return '$min–$max';
        return null;
      },
    );
  }
}
