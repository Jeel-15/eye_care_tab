import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/permissions.dart';
import '../models/onboarding_models.dart';
import 'permission_service.dart';

/// Decides whether the one-time onboarding tour should run, and which
/// persona's slide set to show. Persona is picked from the SAME permission
/// checks the rail/drawer already use — not a hardcoded role name — so it
/// stays correct if a hospital creates custom roles. See
/// ONBOARDING_SCREENS_PRD.md for the full spec.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  static const _seenKey = 'has_seen_onboarding_v1';

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  /// Debug-only: clears the "seen" flag so the tour can be replayed without
  /// uninstalling. Never called from release-build code paths.
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }

  /// Returns null if the user has no module permission worth onboarding —
  /// caller should skip showing the tour entirely in that case.
  List<OnboardingSlideData>? slidesForCurrentUser({required String? roleSlug}) {
    final p = PermissionService.instance;

    if (roleSlug == 'hospital_admin') return _adminSlides;
    if (roleSlug == 'doctor') return _doctorSlides;

    final canOpd = p.can(Perm.opdPatientRegister) || p.can(Perm.opdPatientView);
    if (canOpd) return _frontDeskSlides;

    if (p.canModule('ot')) return _otSlides;

    return null;
  }

  static final _adminSlides = [
    const OnboardingSlideData(
      headline: 'Welcome to Eye-SaaS HMS',
      subtext: "Here's a 30-second look at what matters most for your role.",
      accent: AppColors.blue,
      cardKind: MockCardKind.dashboard,
    ),
    const OnboardingSlideData(
      headline: 'Your hospital, at a glance',
      subtext: "Dashboard shows today's stats, revenue trend, and what needs attention.",
      accent: AppColors.teal,
      cardKind: MockCardKind.dashboard,
    ),
    const OnboardingSlideData(
      headline: 'Reports whenever you need them',
      subtext: 'Filter, export, and track collections without leaving the app.',
      accent: AppColors.purple,
      cardKind: MockCardKind.reports,
    ),
    const OnboardingSlideData(
      headline: 'Manage your team',
      subtext: 'Add users, assign roles, and control exactly what each person can see.',
      accent: AppColors.orange,
      cardKind: MockCardKind.users,
    ),
  ];

  static final _doctorSlides = [
    const OnboardingSlideData(
      headline: 'Welcome to Eye-SaaS HMS',
      subtext: "Here's a quick look at your clinical workflow.",
      accent: AppColors.blue,
      cardKind: MockCardKind.queue,
    ),
    const OnboardingSlideData(
      headline: 'Your queue, always up to date',
      subtext: 'See who\'s waiting for Primary, Dilation, and Secondary at a glance.',
      accent: AppColors.teal,
      cardKind: MockCardKind.queue,
    ),
    const OnboardingSlideData(
      headline: 'Exams built for speed',
      subtext: 'Primary and Secondary Exam save section-by-section as you go.',
      accent: AppColors.purple,
      cardKind: MockCardKind.exam,
    ),
    const OnboardingSlideData(
      headline: 'History and prescriptions, one tap away',
      subtext: 'Pull up any patient\'s past visits or print a prescription instantly.',
      accent: AppColors.orange,
      cardKind: MockCardKind.patients,
    ),
  ];

  static final _frontDeskSlides = [
    const OnboardingSlideData(
      headline: 'Welcome to Eye-SaaS HMS',
      subtext: "Here's how patients move through your day.",
      accent: AppColors.blue,
      cardKind: MockCardKind.patients,
    ),
    const OnboardingSlideData(
      headline: 'Register in seconds',
      subtext: 'Walk-in or phone patient — new registration takes just a few fields.',
      accent: AppColors.teal,
      cardKind: MockCardKind.patients,
    ),
    const OnboardingSlideData(
      headline: 'Check-in sends them straight to the queue',
      subtext: 'Once checked in, the doctor sees them in the clinical queue immediately.',
      accent: AppColors.purple,
      cardKind: MockCardKind.queue,
    ),
  ];

  static final _otSlides = [
    const OnboardingSlideData(
      headline: 'Welcome to Eye-SaaS HMS',
      subtext: "Here's what you'll manage for the OT.",
      accent: AppColors.blue,
      cardKind: MockCardKind.ot,
    ),
    const OnboardingSlideData(
      headline: 'Keep OT masters ready',
      subtext: 'Slots, charge heads, and surgery types — set once, reuse every booking.',
      accent: AppColors.teal,
      cardKind: MockCardKind.ot,
    ),
  ];
}
