import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/patient_models.dart';
import '../../services/ot_booking_service.dart';
import '../../services/ot_surgery_type_service.dart';
import '../app_animations.dart';
import '../app_dialog.dart';
import '../form_kit.dart';

/// Doctor's "Recommend Surgery / Refer to Counsellor" action — the exam-
/// screen handoff into the OT workflow (Round 3.5, `ot.surgery.recommend`).
/// Returns `true` if a booking was created/updated.
Future<bool?> showRecommendSurgeryDialog(
  BuildContext context, {
  required Patient patient,
  String? diagnosisHint,
  Future<void> Function()? beforeRecommend,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _RecommendSurgeryDialog(patient: patient, diagnosisHint: diagnosisHint, beforeRecommend: beforeRecommend),
  );
}

class _RecommendSurgeryDialog extends StatefulWidget {
  final Patient patient;
  final String? diagnosisHint;
  final Future<void> Function()? beforeRecommend;
  const _RecommendSurgeryDialog({required this.patient, this.diagnosisHint, this.beforeRecommend});

  @override
  State<_RecommendSurgeryDialog> createState() => _RecommendSurgeryDialogState();
}

class _RecommendSurgeryDialogState extends State<_RecommendSurgeryDialog> {
  static const _eyeOptions = ['RE', 'LE', 'Both'];

  late final TextEditingController _diagnosisCtrl;
  String _eye = 'RE';
  List<OtSurgeryTypeItem> _surgeryTypes = [];
  OtSurgeryTypeItem? _selectedSurgeryType;

  bool _loadingMasters = true;
  String? _mastersError;
  bool _saving = false;
  String? _typeError;

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl = TextEditingController(text: widget.diagnosisHint ?? '');
    _loadMasters();
  }

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final surgeryTypes = await OtBookingService.instance.fetchSurgeryTypesForRecommend();
      if (!mounted) return;
      setState(() {
        _surgeryTypes = surgeryTypes;
        _loadingMasters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mastersError = e.toString().replaceFirst('Exception: ', '');
        _loadingMasters = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _typeError = _selectedSurgeryType == null ? 'Please select a surgery type' : null;
    });
    if (_typeError != null) return;

    setState(() => _saving = true);
    try {
      if (widget.beforeRecommend != null) await widget.beforeRecommend!();
      await OtBookingService.instance.recommendSurgery(
        patientId: widget.patient.id,
        eye: _eye,
        otSurgeryTypeId: _selectedSurgeryType!.id,
        diagnosisHint: _diagnosisCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
        showAppSnackBar(context, 'Surgery recommended — sent to OT Counsellor', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      size: AppDialogSize.small,
      header: AppDialogHeader(
        icon: Icons.medical_services_rounded,
        title: 'Recommend Surgery',
        subtitle: widget.patient.fullName,
        colors: const [AppColors.tealDark, AppColors.teal],
        onClose: _saving ? null : () => Navigator.pop(context),
      ),
      body: _loadingMasters
          ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
          : _mastersError != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_mastersError!, style: const TextStyle(color: AppColors.red)),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: () { setState(() { _loadingMasters = true; _mastersError = null; }); _loadMasters(); }, child: const Text('Retry')),
                  ]),
                )
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Eye', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _eyeOptions.map((e) => ChoiceChip(
                      label: Text(e),
                      selected: _eye == e,
                      onSelected: (_) => setState(() => _eye = e),
                      selectedColor: AppColors.teal.withValues(alpha: 0.18),
                      labelStyle: TextStyle(color: _eye == e ? AppColors.tealDark : AppColors.textPrimary, fontWeight: FontWeight.w600),
                    )).toList(),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<OtSurgeryTypeItem>(
                    initialValue: _selectedSurgeryType,
                    isExpanded: true,
                    decoration: appFieldDecoration('Surgery Type *').copyWith(errorText: _typeError),
                    items: _surgeryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.surgeryName, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() { _selectedSurgeryType = v; _typeError = null; }),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _diagnosisCtrl,
                    maxLines: 2,
                    // Matches web's `maxlength="255"` on this exact
                    // field — the backend's diagnosis_hint validation
                    // is max:255.
                    maxLength: 255,
                    decoration: appFieldDecoration('Diagnosis Hint (optional)'),
                  ),
                ]),
      actions: [
        AppSecondaryButton(onPressed: _saving ? null : () => Navigator.pop(context)),
        AppPrimaryButton(
          label: 'Recommend Surgery',
          color: AppColors.teal,
          loading: _saving,
          onPressed: (_loadingMasters || _mastersError != null) ? null : _save,
        ),
      ],
    );
  }
}
