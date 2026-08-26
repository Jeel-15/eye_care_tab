import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../utils/app_route.dart';
import 'platform_login_screen.dart';
import 'tablet_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _btnPressed = false;
  String? _errorMessage;

  int _logoTapCount = 0;
  Timer? _logoTapTimer;

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _shakeCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _logoPulse;
  late final Animation<double> _shimmer;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.30, curve: Curves.easeOut)),
    );
    _brandOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.22, 0.55, curve: Curves.easeOut)),
    );
    _brandSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.22, 0.60, curve: Curves.easeOut)),
    );
    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.35, 0.75, curve: Curves.easeOut)),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.35, 0.85, curve: Curves.easeOutQuart)),
    );
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
    );

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))
      ..repeat(reverse: true);
    _logoPulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _shimmer = Tween<double>(begin: -1.0, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 1300), _loopShimmer);

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -11.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -11.0, end: 11.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 11.0, end: -9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -9.0, end: 9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _entryCtrl.forward();
  }

  void _loopShimmer() {
    if (!mounted || _isLoading) return;
    _shimmerCtrl.forward(from: 0).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 2600), _loopShimmer);
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _shakeCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    _logoTapTimer?.cancel();
    super.dispose();
  }

  // ── Hidden platform-admin entry: tap the logo 5x within 2s ────────────────

  void _onLogoTap() {
    _logoTapTimer?.cancel();
    _logoTapCount++;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      HapticFeedback.mediumImpact();
      Navigator.push(context, appRoute(const PlatformLoginScreen()));
      return;
    }

    if (_logoTapCount >= 3) HapticFeedback.selectionClick();

    _logoTapTimer = Timer(const Duration(seconds: 2), () {
      _logoTapCount = 0;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _shimmerCtrl.stop();

    final result = await AuthService.instance.login(_loginCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (result.success) {
      PermissionService.instance.load(result.user!.role);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => TabletShell(user: result.user!, hospital: result.hospital!),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 380),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      HapticFeedback.mediumImpact();
      _shakeCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), _loopShimmer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Width alone isn't enough — a portrait tablet is often still
          // "wide" past the compact threshold, but splitting a tall/narrow
          // screen in half looks cramped. Only split when the screen is
          // actually landscape-shaped (wider than it is tall) as well.
          final isLandscapeShaped = constraints.maxWidth > constraints.maxHeight;
          final wide = isLandscapeShaped && constraints.maxWidth >= AppBreakpoints.compact;
          return wide ? _buildSplitLayout() : _buildStackedLayout();
        },
      ),
    );
  }

  // ── Wide (tablet landscape) — branding left, form right ──────────────────

  Widget _buildSplitLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.primary,
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -80,
                  child: _decoCircle(260, Colors.white.withValues(alpha: 0.05)),
                ),
                Positioned(
                  bottom: -120,
                  left: -100,
                  child: _decoCircle(320, Colors.white.withValues(alpha: 0.04)),
                ),
                Center(child: _buildBrandContent()),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (_, child) => Transform.translate(offset: Offset(_shake.value, 0), child: child),
                  child: FadeTransition(
                    opacity: _cardOpacity,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLoginCard(),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _decoCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _buildBrandContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
            builder: (_, child) => Opacity(
              opacity: _logoOpacity.value.clamp(0.0, 1.0),
              child: Transform.scale(scale: _logoScale.value * _logoPulse.value, child: child),
            ),
            child: GestureDetector(
              onTap: _onLogoTap,
              child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.5),
              ),
              child: Center(
                child: Image.asset('assets/images/wight_logo.png', width: 60, height: 60, fit: BoxFit.contain),
              ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _brandOpacity,
            child: SlideTransition(
              position: _brandSlide,
              child: Column(
                children: [
                  Text(
                    AppConfig.hospitalName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'TABLET WORKSPACE',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.60),
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in to manage patients, clinical queues,\nexaminations and reports.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow (compact / portrait) fallback — stacked, mobile-like ──────────

  Widget _buildStackedLayout() {
    // Mirrors eye_care_app's login_screen.dart: a navy header positioned
    // behind the scroll content so _buildBrandContent()'s white text has a
    // dark background to sit on — without this, it renders on the light
    // Scaffold background and is nearly invisible.
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final topPad = mq.padding.top;
    final headerH = screenH * 0.36;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: headerH,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: headerH - topPad - 24, child: Center(child: _buildBrandContent())),
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (_, child) => Transform.translate(offset: Offset(_shake.value, 0), child: child),
                  child: FadeTransition(
                    opacity: _cardOpacity,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildLoginCard()),
                    ),
                  ),
                ),
                _buildFooter(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Login card (shared by both layouts) ───────────────────────────────────

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(color: AppColors.primaryA12, blurRadius: 48, offset: const Offset(0, 18)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign In',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter your credentials to continue',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryA40),
            ),
            const SizedBox(height: 28),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(offset: Offset(0, (1 - v) * -8), child: child),
                        ),
                        child: _buildErrorBanner(_errorMessage!),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _buildInputField(
              controller: _loginCtrl,
              hint: 'Email Address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your email' : null,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _passwordCtrl,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.primaryA45,
                  size: 20,
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blue),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSignInButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryA35),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(icon, color: AppColors.blue, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffixIcon) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBA1A1A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFBA1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _btnPressed = true),
      onTapUp: (_) => setState(() => _btnPressed = false),
      onTapCancel: () => setState(() => _btnPressed = false),
      onTap: _isLoading ? null : _submit,
      child: AnimatedScale(
        scale: _btnPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, child) {
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: Stack(
                children: [
                  child!,
                  if (!_isLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: OverflowBox(
                          maxWidth: double.infinity,
                          child: Transform.translate(
                            offset: Offset((_shimmer.value * 440) - 80, 0),
                            child: Container(
                              width: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading ? 'Signing In...' : 'Sign In',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _footerOpacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Powered by Eye-SaaS HMS',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryA40),
        ),
      ),
    );
  }
}
