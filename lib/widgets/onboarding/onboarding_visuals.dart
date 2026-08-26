import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/onboarding_models.dart';

// ── Living background ────────────────────────────────────────────────────

/// Slowly shifting two-tone glow behind onboarding slides — a lightweight
/// approximation of an organic "living" background using a repeating
/// AnimationController + CustomPainter (no GLSL/fragment-shader dependency,
/// so it works identically on every platform this app ships to). One glow
/// blends towards [accent] (smoothly, whenever it changes) so each slide
/// reads as visually distinct at a glance, not just by its text/icon.
class OnboardingLivingBackground extends StatefulWidget {
  final Color accent;
  const OnboardingLivingBackground({super.key, required this.accent});

  @override
  State<OnboardingLivingBackground> createState() => _OnboardingLivingBackgroundState();
}

class _OnboardingLivingBackgroundState extends State<OnboardingLivingBackground> with TickerProviderStateMixin {
  late final AnimationController _motionCtrl;
  late final AnimationController _accentCtrl;
  late Color _fromAccent;
  late Color _toAccent;

  @override
  void initState() {
    super.initState();
    _motionCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _fromAccent = widget.accent;
    _toAccent = widget.accent;
    _accentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant OnboardingLivingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accent != widget.accent) {
      _fromAccent = _currentAccent;
      _toAccent = widget.accent;
      _accentCtrl
        ..value = 0
        ..forward();
    }
  }

  Color get _currentAccent => Color.lerp(_fromAccent, _toAccent, _accentCtrl.value) ?? _toAccent;

  @override
  void dispose() {
    _motionCtrl.dispose();
    _accentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_motionCtrl, _accentCtrl]),
      builder: (context, _) => CustomPaint(painter: _LivingGradientPainter(t: _motionCtrl.value, accent: _currentAccent), size: Size.infinite),
    );
  }
}

class _LivingGradientPainter extends CustomPainter {
  final double t;
  final Color accent;
  _LivingGradientPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.primary);

    final angle1 = t * 2 * math.pi;
    final angle2 = t * 2 * math.pi + math.pi;

    final c1 = Offset(size.width * (0.5 + 0.28 * math.cos(angle1)), size.height * (0.32 + 0.16 * math.sin(angle1 * 0.8)));
    final c2 = Offset(size.width * (0.5 + 0.30 * math.cos(angle2)), size.height * (0.66 + 0.18 * math.sin(angle2 * 0.7)));

    canvas.drawCircle(
      c1,
      size.longestSide * 0.55,
      Paint()..shader = RadialGradient(colors: [accent.withValues(alpha: 0.50), accent.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: c1, radius: size.longestSide * 0.55)),
    );
    canvas.drawCircle(
      c2,
      size.longestSide * 0.50,
      Paint()..shader = RadialGradient(colors: [AppColors.primaryDark.withValues(alpha: 0.60), AppColors.primaryDark.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: c2, radius: size.longestSide * 0.50)),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)], stops: const [0.55, 1.0]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _LivingGradientPainter oldDelegate) => oldDelegate.t != t || oldDelegate.accent != accent;
}

// ── Ghost watermark text ─────────────────────────────────────────────────

/// Oversized, heavily-rotated, near-invisible headline fragments bleeding
/// off-screen — same decorative idea as the splash screen's watermark logo,
/// applied to a word pulled from the slide's own headline.
class OnboardingGhostText extends StatelessWidget {
  final String topWord;
  final String bottomWord;
  const OnboardingGhostText({super.key, required this.topWord, required this.bottomWord});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(fontSize: 92, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2, height: 1.0);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: 44, left: -28, child: Transform.rotate(angle: -12 * math.pi / 180, child: Opacity(opacity: 0.08, child: Text(topWord.toUpperCase(), style: style)))),
          Positioned(top: 250, right: -36, child: Transform.rotate(angle: 9 * math.pi / 180, child: Opacity(opacity: 0.08, child: Text(bottomWord.toUpperCase(), style: style)))),
        ],
      ),
    );
  }
}

// ── Vertical progress rail ───────────────────────────────────────────────

/// Left-edge vertical dash stack — the current slide's dash is tall and
/// glowing white, the rest are short and faint. A vertical analogue of the
/// usual bottom dot-row, deliberately chosen since both apps already read
/// left-to-right rail/drawer navigation as "current position".
class OnboardingProgressRail extends StatelessWidget {
  final int total;
  final int currentIndex;
  const OnboardingProgressRail({super.key, required this.total, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: active ? 6 : 4,
          height: active ? 28 : 14,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(3),
            boxShadow: active ? [BoxShadow(color: Colors.white.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 1)] : null,
          ),
        );
      }),
    );
  }
}

// ── Layered mock-card stack ──────────────────────────────────────────────

class _MockSpec {
  final IconData icon;
  final String stat1Value, stat1Label, stat2Value, stat2Label;
  const _MockSpec(this.icon, this.stat1Value, this.stat1Label, this.stat2Value, this.stat2Label);
}

const _mockSpecs = {
  MockCardKind.dashboard: _MockSpec(Icons.speed_rounded, '128', 'Patients Today', '₹42k', 'Collection'),
  MockCardKind.reports: _MockSpec(Icons.bar_chart_rounded, '64', 'Records', '12', 'Filters Applied'),
  MockCardKind.users: _MockSpec(Icons.groups_rounded, '18', 'Staff', '4', 'Roles'),
  MockCardKind.queue: _MockSpec(Icons.pending_actions_rounded, '6', 'Waiting', '2', 'In Exam'),
  MockCardKind.exam: _MockSpec(Icons.visibility_rounded, 'O/E', 'Sections', 'Auto', 'Save'),
  MockCardKind.patients: _MockSpec(Icons.folder_shared_rounded, '312', 'Patients', '8', 'New Today'),
  MockCardKind.ot: _MockSpec(Icons.medical_services_rounded, '5', 'Slots', '3', 'Booked'),
};

/// Three overlapping stylized "mini screenshot" cards (back/mid/front),
/// each rotated and offset for a parallax bento-stack look, revealed with a
/// staggered fade-slide-in as [entrance] advances from 0 to 1. Content is
/// hand-drawn per [MockCardKind] rather than a real screenshot, so it can
/// never go stale when the actual app UI changes. [index] (the slide's
/// position) alternates the whole arrangement — mirrored left/right,
/// rotation signs flipped — so consecutive slides aren't visually identical
/// compositions even before you read their text.
class OnboardingMockCardStack extends StatelessWidget {
  final MockCardKind kind;
  final Color accent;
  final Animation<double> entrance;
  final int index;

  const OnboardingMockCardStack({super.key, required this.kind, required this.accent, required this.entrance, this.index = 0});

  double _t(double start, double span) => ((entrance.value - start) / span).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final mirrored = index.isOdd;
    final sign = mirrored ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        return SizedBox(
          height: 300,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 6,
                right: mirrored ? null : 10,
                left: mirrored ? 10 : null,
                child: _reveal(_t(0.00, 0.5), rotation: 3 * sign, child: _MockCard(kind: kind, accent: accent, width: 190, height: 120)),
              ),
              Positioned(
                bottom: 30,
                left: mirrored ? null : 0,
                right: mirrored ? 0 : null,
                child: _reveal(_t(0.15, 0.5), rotation: -6 * sign, child: _MockCard(kind: kind, accent: accent, width: 210, height: 140)),
              ),
              Positioned(
                top: 55,
                left: 24,
                right: 24,
                child: _reveal(_t(0.30, 0.5), rotation: 1 * sign, child: _MockCard(kind: kind, accent: accent, width: double.infinity, height: 190, bordered: true)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reveal(double t, {required double rotation, required Widget child}) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 24),
        child: Transform.rotate(angle: rotation * math.pi / 180, child: child),
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final MockCardKind kind;
  final Color accent;
  final double width;
  final double height;
  final bool bordered;

  const _MockCard({required this.kind, required this.accent, required this.width, required this.height, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    final spec = _mockSpecs[kind]!;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: bordered ? Border.all(color: AppColors.primary, width: 3) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: bordered ? 0.35 : 0.20), blurRadius: bordered ? 26 : 14, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: bordered ? 44 : 28,
              height: bordered ? 44 : 28,
              decoration: BoxDecoration(color: accent.withValues(alpha: bordered ? 0.16 : 0.14), borderRadius: BorderRadius.circular(bordered ? 14 : 9)),
              child: Icon(spec.icon, size: bordered ? 24 : 15, color: accent),
            ),
            const SizedBox(width: 8),
            Container(width: 46, height: 8, decoration: BoxDecoration(color: AppColors.textDisabled.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4))),
            const Spacer(),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
          ]),
          const Spacer(),
          Row(children: [
            Expanded(child: _statBlock(spec.stat1Value, spec.stat1Label)),
            const SizedBox(width: 10),
            Expanded(child: _statBlock(spec.stat2Value, spec.stat2Label)),
          ]),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              final h = 6.0 + (i.isEven ? 10 : 18) + (i == 2 ? 6 : 0);
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(width: 8, height: h, decoration: BoxDecoration(color: accent.withValues(alpha: 0.55 - i * 0.06), borderRadius: BorderRadius.circular(3))),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _statBlock(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}
