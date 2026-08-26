import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../utils/circular_reveal_route.dart';
import '../widgets/pulsing_pupil_loader.dart';
import 'tablet_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnim;

  // Phase 1 — exit fade for decorative elements (text, bar, watermark)
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  // Phase 2 — spinner fades out as the circular reveal begins
  late final AnimationController _spinnerCtrl;
  late final Animation<double> _spinnerFade;

  late final Future<void> _sessionFuture;
  UserInfo? _sessionResult;
  HospitalInfo? _hospitalResult;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward();

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut),
    );

    _spinnerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _spinnerFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _spinnerCtrl, curve: Curves.easeOut),
    );

    _sessionFuture = _loadSession();
    Future.delayed(const Duration(milliseconds: 3000), _onSplashDone);
  }

  Future<void> _loadSession() async {
    await AuthService.instance.restoreSession();

    final token = await AuthService.instance.getStoredToken();
    if (token == null) return;

    _hospitalResult = await AuthService.instance.getStoredHospital();

    try {
      _sessionResult = await AuthService.instance.refreshSession();
    } catch (_) {
      _sessionResult = await AuthService.instance.getStoredUser();
    }
  }

  Future<void> _onSplashDone() async {
    await _sessionFuture;
    if (!mounted) return;

    await _exitCtrl.forward();
    if (!mounted) return;

    if (_sessionResult != null && _hospitalResult != null) {
      _spinnerCtrl.forward();
      PermissionService.instance.load(_sessionResult!.role);
      Navigator.of(context).pushReplacement(
        circularRevealRoute(
          page: TabletShell(user: _sessionResult!, hospital: _hospitalResult!),
        ),
      );
    } else {
      _spinnerCtrl.forward();
      Navigator.of(context).pushReplacement(
        circularRevealRoute(page: const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _exitCtrl.dispose();
    _spinnerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Faint watermark logo — FADES OUT in Phase 1 ───────────────
          Positioned(
            bottom: -(size.height * 0.20),
            left: -(size.width * 0.30),
            child: FadeTransition(
              opacity: _exitFade,
              child: Opacity(
                opacity: 0.035,
                child: Image.asset(
                  'assets/images/black_logo.png',
                  width: size.width * 1.2,
                  height: size.height * 1.4,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // ── Left-edge progress bar — FADES OUT in Phase 1 ─────────────
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: FadeTransition(
              opacity: _exitFade,
              child: SizedBox(
                width: 4,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.10),
                  child: AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: _progressAnim.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  blurRadius: 15,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Top-right logo — fades out with Phase 1 decorative elements ──
          Positioned(
            top: 48,
            right: 40,
            child: FadeTransition(
              opacity: _exitFade,
              child: Image.asset(
                'assets/images/wight_logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // ── Centre loader — fades at Phase 2 start (reveal origin) ────
          Center(
            child: FadeTransition(
              opacity: _spinnerFade,
              child: const PulsingPupilLoader(size: 64),
            ),
          ),

          // ── Bottom-left headline text — FADES OUT in Phase 1 ──────────
          Positioned(
            bottom: 56,
            left: 56,
            child: FadeTransition(
              opacity: _exitFade,
              child: Transform.rotate(
                angle: -2 * math.pi / 180,
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _headline('Eye-', 84, Colors.white),
                    _headline('SaaS', 84, Colors.white),
                    _headline('HMS', 112, AppColors.splashAccent.withValues(alpha: 0.90)),
                    const SizedBox(height: 20),
                    Text(
                      'TABLET WORKSPACE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.70),
                        letterSpacing: 2.6,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom-right version label — FADES OUT in Phase 1 ─────────
          Positioned(
            bottom: 96,
            right: -48,
            child: FadeTransition(
              opacity: _exitFade,
              child: Transform.rotate(
                angle: math.pi / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'POWERED BY EYE-SAAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.40),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.24),
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headline(String text, double size, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        height: 0.85,
        letterSpacing: -1.5,
      ),
    );
  }
}
