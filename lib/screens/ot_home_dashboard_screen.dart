import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/ot_booking_models.dart';
import '../services/ot_booking_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_error_state.dart';

/// Tablet OT Home Dashboard — reached via the "OT Dashboard" quick-action
/// tile, not a direct rail entry. Web's sidebar links directly to "OT
/// Appointments" (its own rail entry, `ot_appointments`) — this screen is
/// web's actual `/ot/dashboard` landing page (OT_WEB_PARITY_FIX_PRD.md §8),
/// only reachable via the bare `/ot` redirect on web, not the sidebar.
/// Ported from eye_care_app/lib/screens/ot_home_dashboard_screen.dart — "OT
/// Appointments" and "Counselling Queue" workspace buttons use the rail's
/// own navigation callback rather than pushing, matching how other tablet
/// dashboards work.
class OtHomeDashboardScreen extends StatefulWidget {
  final void Function(String id)? onNavigate;
  const OtHomeDashboardScreen({super.key, this.onNavigate});

  @override
  State<OtHomeDashboardScreen> createState() => _OtHomeDashboardScreenState();
}

class _OtHomeDashboardScreenState extends State<OtHomeDashboardScreen> {
  bool _loading = true;
  String? _error;
  OtReceptionistDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await OtBookingService.instance.fetchReceptionistDashboard();
      if (mounted) setState(() { _stats = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PermissionService.instance;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        const Expanded(child: Text('OT Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
        if (p.can(Perm.otAppointmentCreate))
          OutlinedButton.icon(
            onPressed: () => widget.onNavigate?.call('ot_appointments'),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('New Appointment'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? AppErrorState(message: _error!, onRetry: _load)
                : _buildBody(p),
      ),
    ]);
  }

  Widget _buildBody(PermissionService p) {
    final s = _stats!;
    return ListView(children: [
      Row(children: [
        Expanded(child: _kpiCard('Total OT Today', '${s.totalOtToday}', Icons.event_note_rounded, AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard('Pending Counselling', '${s.pendingCounselling}', Icons.support_agent_rounded, AppColors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _kpiCard('Ready For Surgery', '${s.readyForSurgery}', Icons.local_hospital_rounded, AppColors.green)),
      ]),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.primaryA08)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OT Workspace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(children: [
            if (p.can(Perm.otAppointmentView))
              OutlinedButton.icon(onPressed: () => widget.onNavigate?.call('ot_appointments'), icon: const Icon(Icons.event_note_rounded, size: 16), label: const Text('OT Appointments'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16))),
            if (p.can(Perm.otAppointmentView) && p.can(Perm.otCounsellingFill)) const SizedBox(width: 12),
            if (p.can(Perm.otCounsellingFill))
              OutlinedButton.icon(onPressed: () => widget.onNavigate?.call('ot_counsellor'), icon: const Icon(Icons.support_agent_rounded, size: 16), label: const Text('Counselling Queue'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16))),
          ]),
          const SizedBox(height: 14),
          Text('Book OT appointments, then continue counselling after the doctor recommends surgery. Manual OT booking is no longer used.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ]),
      ),
    ]);
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ]),
      );
}
