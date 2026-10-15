import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import 'date_format.dart';

/// Centered calendar card. The month grid stays on screen, and a date can
/// be typed in the field under it. That field does not replace the calendar.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  TransitionBuilder? builder,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final dialog = _CalendarDialog(first: firstDate, last: lastDate, initial: initialDate);
      return builder?.call(ctx, dialog) ?? dialog;
    },
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  TransitionBuilder? builder,
}) {
  final start = initialDateRange?.start ?? DateTime.now();
  return showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final dialog = _CalendarDialog(first: firstDate, last: lastDate, initial: start, initialEnd: initialDateRange?.end ?? start, range: true);
      return builder?.call(ctx, dialog) ?? dialog;
    },
  );
}

DateTime _only(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clamp(DateTime d, DateTime first, DateTime last) {
  final day = _only(d);
  if (day.isBefore(_only(first))) return _only(first);
  if (day.isAfter(_only(last))) return _only(last);
  return day;
}

bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _fieldText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime? _parseField(String raw) {
  final t = raw.trim();
  final m = RegExp(r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$').firstMatch(t);
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class _CalendarDialog extends StatefulWidget {
  final DateTime first;
  final DateTime last;
  final DateTime initial;
  final DateTime? initialEnd;
  final bool range;

  const _CalendarDialog({required this.first, required this.last, required this.initial, this.initialEnd, this.range = false});

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _month;
  late DateTime _start;
  DateTime? _end;
  late final TextEditingController _startField;
  late final TextEditingController _endField;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = _clamp(widget.initial, widget.first, widget.last);
    _end = widget.range ? _clamp(widget.initialEnd ?? _start, widget.first, widget.last) : null;
    if (_end != null && _end!.isBefore(_start)) {
      final swap = _start;
      _start = _end!;
      _end = swap;
    }
    _month = DateTime(_start.year, _start.month);
    _startField = TextEditingController(text: _fieldText(_start));
    _endField = TextEditingController(text: _end == null ? '' : _fieldText(_end!));
  }

  @override
  void dispose() {
    _startField.dispose();
    _endField.dispose();
    super.dispose();
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= 760;

  bool _outside(DateTime day) => day.isBefore(_only(widget.first)) || day.isAfter(_only(widget.last));

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final firstMonth = DateTime(widget.first.year, widget.first.month);
    final lastMonth = DateTime(widget.last.year, widget.last.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => _month = next);
  }

  void _onDay(DateTime day) {
    if (_outside(day)) return;
    setState(() {
      _error = null;
      if (!widget.range) {
        _start = day;
        _startField.text = _fieldText(day);
        return;
      }
      if (_end != null || day.isBefore(_start)) {
        _start = day;
        _end = null;
        _endField.text = '';
      } else {
        _end = day;
        _endField.text = _fieldText(day);
      }
      _startField.text = _fieldText(_start);
    });
  }

  void _onStartTyped(String raw) {
    final parsed = _parseField(raw);
    if (parsed == null || _outside(parsed)) return;
    setState(() {
      _start = parsed;
      _month = DateTime(parsed.year, parsed.month);
      _error = null;
      if (_end != null && _end!.isBefore(_start)) {
        _end = _start;
        _endField.text = _fieldText(_end!);
      }
    });
  }

  void _onEndTyped(String raw) {
    final parsed = _parseField(raw);
    if (parsed == null || _outside(parsed)) return;
    setState(() {
      if (parsed.isBefore(_start)) {
        _end = _start;
        _start = parsed;
        _startField.text = _fieldText(_start);
        _endField.text = _fieldText(_end!);
        _month = DateTime(parsed.year, parsed.month);
      } else {
        _end = parsed;
      }
      _error = null;
    });
  }

  void _ok() {
    final start = _parseField(_startField.text);
    if (start == null || _outside(start)) {
      setState(() => _error = 'Use a date like 01/10/2026');
      return;
    }
    if (!widget.range) {
      Navigator.pop(context, start);
      return;
    }
    final end = _parseField(_endField.text);
    if (end == null || _outside(end) || end.isBefore(start)) {
      setState(() => _error = 'Enter a start and an end date');
      return;
    }
    Navigator.pop(context, DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final twoMonths = widget.range && _wide;
    final screen = MediaQuery.sizeOf(context).width;
    final width = math.min(twoMonths ? 680.0 : 360.0, screen - 48);
    final headline = !widget.range
        ? toDisplayDate(_start)
        : _end == null
            ? '${toDisplayDate(_start)}  –'
            : '${toDisplayDate(_start)}  –  ${toDisplayDate(_end!)}';
    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.range ? 'Select range' : 'Select date', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(headline, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(tooltip: 'Previous month', onPressed: () => _shift(-1), icon: Icon(Icons.chevron_left_rounded, color: AppColors.primary)),
              Expanded(
                child: Text(
                  twoMonths ? '${_monthTitle(_month)}   –   ${_monthTitle(DateTime(_month.year, _month.month + 1))}' : _monthTitle(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkNavy),
                ),
              ),
              IconButton(tooltip: 'Next month', onPressed: () => _shift(1), icon: Icon(Icons.chevron_right_rounded, color: AppColors.primary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: twoMonths
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _MonthGrid(month: _month, start: _start, end: _end, range: true, outside: _outside, onDay: _onDay)),
                    const SizedBox(width: 12),
                    Expanded(child: _MonthGrid(month: DateTime(_month.year, _month.month + 1), start: _start, end: _end, range: true, outside: _outside, onDay: _onDay)),
                  ])
                : _MonthGrid(month: _month, start: _start, end: widget.range ? _end : _start, range: widget.range, outside: _outside, onDay: _onDay),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: widget.range
                ? Row(children: [
                    Expanded(child: _typeField('Start', _startField, _onStartTyped)),
                    const SizedBox(width: 10),
                    Expanded(child: _typeField('End', _endField, _onEndTyped)),
                  ])
                : _typeField('Type a date', _startField, _onStartTyped),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
              const SizedBox(width: 4),
              FilledButton(onPressed: _ok, style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('OK')),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _typeField(String label, TextEditingController controller, ValueChanged<String> onChanged) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkNavy),
      decoration: InputDecoration(
        labelText: label,
        hintText: '01/10/2026',
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primaryA12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: AppColors.primary, width: 1.4)),
      ),
    );
  }
}

String _monthTitle(DateTime month) {
  const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return '${names[month.month - 1]} ${month.year}';
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime start;
  final DateTime? end;
  final bool range;
  final bool Function(DateTime day) outside;
  final ValueChanged<DateTime> onDay;

  const _MonthGrid({required this.month, required this.start, required this.end, required this.range, required this.outside, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= count; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(children: [
      Row(children: [
        for (final label in _weekdays)
          Expanded(child: Center(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)))),
      ]),
      const SizedBox(height: 4),
      for (var i = 0; i < cells.length; i += 7)
        Row(children: [
          for (final day in cells.sublist(i, i + 7)) Expanded(child: _cell(day)),
        ]),
    ]);
  }

  Widget _cell(DateTime? day) {
    if (day == null) return const SizedBox(height: 36);
    final disabled = outside(day);
    final isStart = _same(day, start);
    final isEnd = end != null && _same(day, end!);
    final inSpan = range && end != null && !day.isBefore(start) && !day.isAfter(end!);
    final selected = !range ? isStart : isStart || isEnd;
    final today = _same(day, DateTime.now());
    final radius = BorderRadius.horizontal(
      left: Radius.circular(!range || isStart || !inSpan ? 18 : 0),
      right: Radius.circular(!range || isEnd || !inSpan ? 18 : 0),
    );
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected
              ? AppColors.primary
              : inSpan
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
          borderRadius: range ? radius : BorderRadius.circular(18),
          child: InkWell(
            onTap: disabled ? null : () => onDay(day),
            borderRadius: range ? radius : BorderRadius.circular(18),
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: today && !selected ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary)) : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: disabled
                        ? AppColors.textDisabled
                        : selected
                            ? Colors.white
                            : AppColors.darkNavy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
