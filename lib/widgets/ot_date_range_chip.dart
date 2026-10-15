import 'package:flutter/material.dart';
import '../constants/app_radius.dart';
import '../utils/app_date_picker.dart';
import '../utils/date_format.dart';

/// The "pick a date range" control web shows next to the Queue/All pill
/// toggle once "All"/History mode is selected — light-on-dark chip meant to
/// sit inside [OtPanelHeader]'s `actions`. Web's own control is a flatpickr
/// range input (`from_date`/`to_date`, both default to today); this opens
/// the platform's [showDateRangePicker] instead, same two-value contract.
class OtDateRangeChip extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final ValueChanged<DateTimeRange> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const OtDateRangeChip({super.key, required this.from, required this.to, required this.onChanged, this.firstDate, this.lastDate});

  @override
  Widget build(BuildContext context) {
    final sameDay = from.year == to.year && from.month == to.month && from.day == to.day;
    final label = sameDay ? toDisplayDate(from) : '${toDisplayDate(from)} – ${toDisplayDate(to)}';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showAppDateRangePicker(
          context: context,
          firstDate: firstDate ?? DateTime(now.year - 3),
          lastDate: lastDate ?? now.add(const Duration(days: 1)),
          initialDateRange: DateTimeRange(start: from, end: to),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}
