import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/onboarding_models.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding/onboarding_visuals.dart';

/// One-time, role-aware onboarding tour shown right after a user's first
/// login on a device — see ONBOARDING_SCREENS_PRD.md for the full spec.
/// Same visual language as mobile's version (living background, ghost text,
/// layered mock-card stack, vertical progress rail); content is centered
/// and width-capped here since a tablet screen is much wider than the
/// portrait layout this design was built for.
class OnboardingScreen extends StatefulWidget {
  final List<OnboardingSlideData> slides;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.slides, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _index = 0;
  bool _finishing = false;

  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await OnboardingService.instance.markSeen();
    if (!mounted) return;
    widget.onDone();
  }

  void _next() {
    if (_index < widget.slides.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.slides.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            Positioned.fill(child: OnboardingLivingBackground(accent: widget.slides[_index].accent)),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    _entranceCtrl.forward(from: 0);
                  },
                  itemBuilder: (context, i) => _SlideBody(slide: widget.slides[i], entrance: _entranceCtrl, index: i),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(child: OnboardingProgressRail(total: widget.slides.length, currentIndex: _index)),
            ),
            Positioned(
              right: 40,
              bottom: 48,
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 8,
                  ),
                  child: Text(isLast ? 'Get Started' : 'Next', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBody extends StatelessWidget {
  final OnboardingSlideData slide;
  final Animation<double> entrance;
  final int index;
  const _SlideBody({required this.slide, required this.entrance, required this.index});

  @override
  Widget build(BuildContext context) {
    final words = slide.headline.split(' ');
    final topWord = words.isNotEmpty ? words.first : '';
    final bottomWord = words.length > 1 ? words.last : '';

    return Stack(
      children: [
        Positioned.fill(child: OnboardingGhostText(topWord: topWord, bottomWord: bottomWord)),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: FadeTransition(
                      opacity: entrance,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(slide.headline, style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                          const SizedBox(height: 16),
                          Text(slide.subtext, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.80), height: 1.6)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 4,
                    child: OnboardingMockCardStack(kind: slide.cardKind, accent: slide.accent, entrance: entrance, index: index),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
