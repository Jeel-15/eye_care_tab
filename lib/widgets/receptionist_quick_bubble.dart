import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/permissions.dart';
import '../models/auth_models.dart';
import '../screens/ot_appointment_list_screen.dart';
import '../screens/patient_form_screen.dart';
import '../services/access_guard.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import 'app_dialog.dart';

/// Counts open dialogs so the receptionist bubble can step aside while a
/// form, date picker, or other popup is on screen.
class ReceptionBubbleGate extends ChangeNotifier {
  ReceptionBubbleGate._();
  static final ReceptionBubbleGate instance = ReceptionBubbleGate._();

  int _popups = 0;
  int get popups => _popups;

  void pushPopup() {
    _popups++;
    notifyListeners();
  }

  void popPopup() {
    if (_popups == 0) return;
    _popups--;
    notifyListeners();
  }
}

class ReceptionBubbleObserver extends NavigatorObserver {
  ReceptionBubbleObserver._();
  static final ReceptionBubbleObserver instance = ReceptionBubbleObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _after(() => ReceptionBubbleGate.instance.pushPopup());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _after(() => ReceptionBubbleGate.instance.popPopup());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _after(() => ReceptionBubbleGate.instance.popPopup());
  }

  void _after(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}

/// Set by [TabletShell] so a save from the bubble reloads whichever module
/// is on screen. Null on login, where the bubble is hidden anyway.
Future<void> Function()? receptionBubbleRefresh;

/// Draggable circle for whichever role can register a patient/appointment
/// (receptionist, and — web pull 2026-10-07 — the dedicated `ot_appointment`
/// role). Tap opens Walk-in, Phone, and/or OT appointment, each gated on its
/// own permission. Hidden while a dialog is open, and hidden when the
/// current role has none of these create permissions.
class ReceptionQuickBubble extends StatefulWidget {
  const ReceptionQuickBubble({super.key});

  @override
  State<ReceptionQuickBubble> createState() => _ReceptionQuickBubbleState();
}

class _ReceptionQuickBubbleState extends State<ReceptionQuickBubble> {
  static const double _size = 56;

  Offset? _frac;
  bool _open = false;
  int? _loadedFor;
  Offset _drag = Offset.zero;
  Offset _origin = Offset.zero;

  @override
  void initState() {
    super.initState();
    PermissionService.instance.addListener(_rebuild);
    ReceptionBubbleGate.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    PermissionService.instance.removeListener(_rebuild);
    ReceptionBubbleGate.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    final id = _user?.id;
    if (id != null && id != _loadedFor) _loadFrac();
  }

  UserInfo? get _user => AuthService.instance.activeUser;

  bool get _show {
    if (_user == null) return false;
    if (ReceptionBubbleGate.instance.popups > 0) return false;
    final p = PermissionService.instance;
    return p.can(Perm.opdPatientRegister) || p.can(Perm.opdPatientRegisterPhone) || p.can(Perm.otAppointmentCreate);
  }

  String get _posKey => 'rec_bubble_xy_v1_${_user?.id ?? 0}';

  Future<void> _loadFrac() async {
    final id = _user?.id;
    if (id == null) return;
    _loadedFor = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_posKey);
      if (raw == null || !mounted) return;
      final parts = raw.split(',');
      if (parts.length != 2) return;
      final dx = double.tryParse(parts[0]);
      final dy = double.tryParse(parts[1]);
      if (dx == null || dy == null) return;
      setState(() => _frac = Offset(dx, dy));
    } catch (_) {}
  }

  Future<void> _saveFrac(Offset frac) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_posKey, '${frac.dx.toStringAsFixed(4)},${frac.dy.toStringAsFixed(4)}');
    } catch (_) {}
  }

  Offset _pixel(Size size) {
    final raw = _frac == null ? Offset(size.width - _size - 20, size.height * 0.62) : Offset(_frac!.dx * size.width, _frac!.dy * size.height);
    return _clamp(raw, size);
  }

  Offset _clamp(Offset o, Size size) {
    const pad = 12.0;
    final maxX = (size.width - _size - pad).clamp(pad, size.width);
    final maxY = (size.height - _size - pad).clamp(pad, size.height);
    return Offset(o.dx.clamp(pad, maxX), o.dy.clamp(pad, maxY));
  }

  BuildContext? get _navContext => AccessGuard.instance.navigatorKey.currentContext;

  Future<void> _openWalkIn() async {
    final user = _user;
    final hospital = AuthService.instance.cachedHospital;
    final nav = _navContext;
    if (user == null || hospital == null || nav == null) return;
    setState(() => _open = false);
    await showPaneDialog<void>(
      nav,
      barrierDismissible: false,
      builder: (dCtx) => PatientFormScreen(
        mode: PatientFormMode.addWalkIn,
        user: user,
        hospital: hospital,
        onSaved: (_) {
          Navigator.pop(dCtx);
          receptionBubbleRefresh?.call();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openPhone() async {
    final user = _user;
    final hospital = AuthService.instance.cachedHospital;
    final nav = _navContext;
    if (user == null || hospital == null || nav == null) return;
    setState(() => _open = false);
    await showPaneDialog<void>(
      nav,
      barrierDismissible: false,
      builder: (dCtx) => PatientFormScreen(
        mode: PatientFormMode.addPhone,
        user: user,
        hospital: hospital,
        onSaved: (_) {
          Navigator.pop(dCtx);
          receptionBubbleRefresh?.call();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  Future<void> _openOt() async {
    final nav = _navContext;
    if (nav == null) return;
    setState(() => _open = false);
    await showPaneDialog<void>(
      nav,
      barrierDismissible: false,
      builder: (dCtx) => OtAppointmentFormPane(
        item: null,
        onSaved: () {
          Navigator.pop(dCtx);
          receptionBubbleRefresh?.call();
        },
        onCancel: () => Navigator.pop(dCtx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final pos = _pixel(size);
    final p = PermissionService.instance;
    final actions = <_BubbleAction>[
      if (p.can(Perm.opdPatientRegister)) _BubbleAction(Icons.person_add_alt_1_rounded, 'Walk-in', _openWalkIn),
      if (p.can(Perm.opdPatientRegisterPhone)) _BubbleAction(Icons.phone_in_talk_rounded, 'Phone appt', _openPhone),
      if (p.can(Perm.otAppointmentCreate)) _BubbleAction(Icons.event_note_rounded, 'OT appt', _openOt),
    ];
    final above = pos.dy > 180;
    final toLeft = pos.dx > size.width / 2;

    final menu = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: toLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final action in actions) ...[
          _ActionChip(action: action),
          const SizedBox(height: 8),
        ],
      ],
    );

    return Stack(children: [
      if (_open)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _open = false),
          ),
        ),
      if (_open)
        Positioned(
          left: toLeft ? null : pos.dx,
          right: toLeft ? size.width - pos.dx - _size : null,
          top: above ? null : pos.dy + _size + 8,
          bottom: above ? size.height - pos.dy + 8 : null,
          child: menu,
        ),
      Positioned(
        left: pos.dx,
        top: pos.dy,
        child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  _drag = Offset.zero;
                  _origin = pos;
                },
                onPointerMove: (event) {
                  _drag += event.delta;
                  if (_drag.distance < 8) return;
                  final next = _clamp(_origin + _drag, size);
                  setState(() => _frac = Offset(next.dx / size.width, next.dy / size.height));
                },
                onPointerUp: (_) {
                  if (_drag.distance >= 8) {
                    final at = _frac ?? Offset(pos.dx / size.width, pos.dy / size.height);
                    _saveFrac(at);
                  } else {
                    setState(() => _open = !_open);
                  }
                },
                child: Material(
                  color: AppColors.primary,
                  elevation: 6,
                  shadowColor: const Color(0x44000000),
                  shape: const CircleBorder(),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: Icon(_open ? Icons.close_rounded : Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
      ),
    ]);
  }
}

class _BubbleAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BubbleAction(this.icon, this.label, this.onTap);
}

class _ActionChip extends StatelessWidget {
  final _BubbleAction action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(action.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(action.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkNavy)),
          ]),
        ),
      ),
    );
  }
}
