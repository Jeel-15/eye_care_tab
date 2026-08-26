import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_breakpoints.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../services/platform_auth_service.dart';
import 'platform_shell.dart';

/// Tablet Platform Super Admin login — reached only via the hidden 5-tap
/// gesture on the hospital login screen's logo (matches mobile's own hidden
/// entry point; this console is deliberately not discoverable from the
/// regular staff login). Split layout (branding left / form right) reuses
/// the same visual language as [LoginScreen] instead of mobile's single
/// stacked card, for consistency across the tablet app. Business logic
/// (login, error/shake handling) ported unchanged from
/// eye_care_app/lib/screens/platform_login_screen.dart.
class PlatformLoginScreen extends StatefulWidget {
  const PlatformLoginScreen({super.key});

  @override
  State<PlatformLoginScreen> createState() => _PlatformLoginScreenState();
}

class _PlatformLoginScreenState extends State<PlatformLoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;
  bool _btnPressed = false;
  String? _errorMessage;

  late final AnimationController _entryCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.85, curve: Curves.easeOutQuart)));

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

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await PlatformAuthService.instance.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => PlatformShell(admin: result.admin!),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      setState(() { _isLoading = false; _errorMessage = result.message; });
      HapticFeedback.mediumImpact();
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(builder: (context, constraints) {
        // Width alone isn't enough — a portrait tablet is often still "wide"
        // past the compact threshold, but splitting a tall/narrow screen in
        // half looks cramped. Only split when actually landscape-shaped too.
        final isLandscapeShaped = constraints.maxWidth > constraints.maxHeight;
        final wide = isLandscapeShaped && constraints.maxWidth >= AppBreakpoints.compact;
        return wide ? _buildSplitLayout() : _buildStackedLayout();
      }),
    );
  }

  Widget _buildSplitLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.primary,
            child: Stack(children: [
              Positioned(top: -80, right: -80, child: _decoCircle(260, Colors.white.withValues(alpha: 0.05))),
              Positioned(bottom: -120, left: -100, child: _decoCircle(320, Colors.white.withValues(alpha: 0.04))),
              Center(child: _buildBrandContent()),
            ]),
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
                      child: Column(mainAxisSize: MainAxisSize.min, children: [_buildCard(), _buildBackLink()]),
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

  Widget _buildStackedLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(children: [
          const SizedBox(height: 24),
          _buildBrandContentDark(),
          const SizedBox(height: 36),
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (_, child) => Transform.translate(offset: Offset(_shake.value, 0), child: child),
            child: FadeTransition(opacity: _cardOpacity, child: SlideTransition(position: _cardSlide, child: _buildCard())),
          ),
          _buildBackLink(),
        ]),
      ),
    );
  }

  Widget _decoCircle(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _buildBrandContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1.5)),
          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 28),
        Text('SUPER ADMIN', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 8),
        Text('PLATFORM CONSOLE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.60), letterSpacing: 3)),
        const SizedBox(height: 20),
        Text('Manage hospitals, subscriptions, billing\nand platform-wide masters.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75), height: 1.6)),
      ]),
    );
  }

  Widget _buildBrandContentDark() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: AppColors.primaryA10, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryA20, width: 1.5)),
        child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 32),
      ),
      const SizedBox(height: 12),
      Text('SUPER ADMIN', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
      const SizedBox(height: 3),
      Text('PLATFORM CONSOLE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryA55, letterSpacing: 2.5)),
    ]);
  }

  Widget _buildBackLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
        label: Text('Back to Hospital Staff Login', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.xxl), boxShadow: [BoxShadow(color: AppColors.primaryA12, blurRadius: 48, offset: const Offset(0, 18))]),
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sign In', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('Platform administrator access', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryA40)),
            const SizedBox(height: 28),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutQuart,
              child: _errorMessage != null ? Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildErrorBanner(_errorMessage!)) : const SizedBox.shrink(),
            ),
            _buildField(controller: _emailCtrl, hint: 'Admin Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your email' : null),
            const SizedBox(height: 14),
            _buildField(
              controller: _passwordCtrl,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscure,
              suffixIcon: GestureDetector(onTap: () => setState(() => _obscure = !_obscure), child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.primaryA45, size: 20)),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, TextInputType keyboardType = TextInputType.text, bool obscureText = false, Widget? suffixIcon, String? Function(String?)? validator, void Function(String)? onFieldSubmitted}) {
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
        prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 10), child: Icon(icon, color: AppColors.blue, size: 20)),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.only(right: 14), child: suffixIcon) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: 0.15))),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFBA1A1A), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFBA1A1A)))),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTapDown: (_) => setState(() => _btnPressed = true),
      onTapUp: (_) => setState(() => _btnPressed = false),
      onTapCancel: () => setState(() => _btnPressed = false),
      onTap: _isLoading ? null : _submit,
      child: AnimatedScale(
        scale: _btnPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.75), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isLoading ? 'Signing In...' : 'Sign In', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
