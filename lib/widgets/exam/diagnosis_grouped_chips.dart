import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../services/exam_masters_service.dart';

/// Diagnosis chip list split into three labelled sections — Starred,
/// Selected, Remaining — each sorted A→Z. A starred diagnosis that is also
/// selected is listed under Selected (so it can't appear twice). Empty
/// sections are hidden. Callers pass the already search-filtered [items] and
/// build each chip themselves via [chipBuilder].
class DiagnosisGroupedChips extends StatelessWidget {
  final List<ExamMasterItem> items;
  final Set<int> selectedIds;
  final Widget Function(ExamMasterItem item) chipBuilder;

  const DiagnosisGroupedChips({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.chipBuilder,
  });

  static int _byName(ExamMasterItem a, ExamMasterItem b) => a.value.toLowerCase().compareTo(b.value.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final selected = items.where((d) => selectedIds.contains(d.id)).toList()..sort(_byName);
    final starred = items.where((d) => d.isFavourite && !selectedIds.contains(d.id)).toList()..sort(_byName);
    final remaining = items.where((d) => !d.isFavourite && !selectedIds.contains(d.id)).toList()..sort(_byName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('★  Starred', starred, Colors.amber.shade800),
        _section('✓  Selected', selected, AppColors.teal),
        _section('All Others', remaining, AppColors.primaryA50),
      ],
    );
  }

  Widget _section(String title, List<ExamMasterItem> list, Color color) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '$title  (${list.length})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: color),
            ),
          ),
          Wrap(spacing: 6, runSpacing: 6, children: list.map(chipBuilder).toList()),
        ],
      ),
    );
  }
}
