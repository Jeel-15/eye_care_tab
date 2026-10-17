import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Doctor dashboard OPD / OT switch, shown in the app header (top bar) instead
/// of inside the dashboard body. [DoctorDashboardScreen] and the shell header
/// share the selection through [doctorDashTab].
final ValueNotifier<String> doctorDashTab = ValueNotifier<String>('opd');

class DashTabSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const DashTabSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn('OPD', 'opd'),
        const SizedBox(width: 3),
        _btn('OT', 'ot'),
      ]),
    );
  }

  Widget _btn(String label, String tab) {
    final active = value == tab;
    return GestureDetector(
      onTap: () => onChanged(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? AppColors.primary : Colors.white)),
      ),
    );
  }
}

/// "TP" (total patients) badge beside the switch: OPD = every patient
/// registered today, OT = OT appointments added today. Set by the dashboard
/// screen after each load; (opd, ot).
final ValueNotifier<(int, int)> doctorDashTp = ValueNotifier<(int, int)>((0, 0));

/// Header-ready switch + TP badge bound to [doctorDashTab] / [doctorDashTp].
class DoctorDashTabSwitch extends StatelessWidget {
  const DoctorDashTabSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: doctorDashTab,
      builder: (_, v, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        DashTabSwitch(value: v, onChanged: (t) => doctorDashTab.value = t),
        const SizedBox(width: 8),
        ValueListenableBuilder<(int, int)>(
          valueListenable: doctorDashTp,
          builder: (_, tp, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
            child: Text('TP: ${v == 'ot' ? tp.$2 : tp.$1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
