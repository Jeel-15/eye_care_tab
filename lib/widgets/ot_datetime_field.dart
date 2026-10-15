import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../utils/date_format.dart';
import '../utils/app_date_picker.dart';

/// Date + time picker field — the app equivalent of web's
/// `<input type="datetime-local">` (e.g. Ward Entry → Eye Drop "Administered
/// At"). [value] is a hospital wall-clock time (not an absolute instant);
/// send it to the API with [toApiDateTimeLocal].
class OtDateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const OtDateTimeField({super.key, required this.label, required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = toHospitalTime(DateTime.now());
    final date = await showAppDatePicker(
      context: context,
      initialDate: DateTime(value.year, value.month, value.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: value.hour, minute: value.minute));
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final h12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final text = '${toDisplayDate(value)}, ${h12.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF0F6FB),
          suffixIcon: Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
