import 'package:flutter/material.dart';
import '../models/patient_history_models.dart';
import '../models/patient_models.dart';
import '../services/patient_history_service.dart';
import '../utils/date_format.dart';
import '../utils/view_facts.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_error_state.dart';
import '../widgets/detail_card_kit.dart';
import '../widgets/exam_clinical_data_view.dart';
import '../widgets/form_kit.dart';
import '../widgets/skeleton.dart';

/// Doctor Dashboard exam module. Shows the patient's most recent examination
/// in the same sheet as Patient History: filled clinical data first, with
/// Full exam on the side.
Future<void> showLatestExamView(BuildContext context, Patient patient) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => LatestExamViewScreen(patient: patient),
  );
}

class LatestExamViewScreen extends StatefulWidget {
  final Patient patient;

  const LatestExamViewScreen({super.key, required this.patient});

  @override
  State<LatestExamViewScreen> createState() => _LatestExamViewScreenState();
}

class _LatestExamViewScreenState extends State<LatestExamViewScreen> {
  bool _loading = true;
  bool _showFull = false;
  String? _error;
  ExamRecord? _exam;
  Map<int, String> _diagnosisMasters = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await PatientHistoryService.instance.fetchHistory(widget.patient.id);
      ExamRecord? latest;
      for (final e in data.exams) {
        if (latest == null || e.examinedAt.isAfter(latest.examinedAt)) latest = e;
      }
      if (mounted) {
        setState(() {
          _exam = latest;
          _diagnosisMasters = data.diagnosisMasters;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final exam = _exam;
    return AppDialog(
      size: AppDialogSize.large,
      header: EntityDialogHeader(
        name: p.fullName,
        pills: [
          ...patientIdentityPills(p),
          if (exam != null) ExamChip(label: exam.isPrimary ? 'Primary' : 'Secondary', done: true, when: toDisplayDateTime(exam.examinedAt)),
        ],
        facts: exam == null
            ? null
            : HeaderFacts([
                HeaderFact('Doctor', doctorDisplayName(exam.doctorName)),
                HeaderFact('Examined', toDisplayDateTime(exam.examinedAt)),
              ]),
        actions: [
          if (exam != null)
            ViewSideButton(
              icon: _showFull ? Icons.compress_rounded : Icons.open_in_full_rounded,
              label: _showFull ? 'Filled only' : 'Full exam',
              active: _showFull,
              onTap: () => setState(() => _showFull = !_showFull),
            ),
        ],
        onClose: () => Navigator.pop(context),
      ),
      body: _loading
          ? const AppSkeletonList(count: 5, itemHeight: 70)
          : _error != null
              ? AppErrorState(message: _error!, onRetry: _load)
              : exam == null
                  ? const SheetNote('No examination records found.')
                  : buildExamClinicalData(exam, _diagnosisMasters, onlyFilled: !_showFull),
      actions: [AppSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context))],
    );
  }
}
