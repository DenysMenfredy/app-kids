import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessment/presentation/assessment_intro_screen.dart';
import '../../features/assessment/presentation/assessment_question_screen.dart';
import '../../features/assessment/presentation/assessment_result_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/books/presentation/books_screen.dart';
import '../../features/child_home/presentation/child_home_screen.dart';
import '../../features/child_profile/presentation/profile_setup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/lesson/presentation/activities/listen_activity_screen.dart';
import '../../features/lesson/presentation/activities/match_activity_screen.dart';
import '../../features/lesson/presentation/activities/tap_activity_screen.dart';
import '../../features/lesson/presentation/activities/trace_activity_screen.dart';
import '../../features/lesson/presentation/lesson_intro_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/reward/presentation/reward_screen.dart';

/// Route names — use these with `context.goNamed` so paths can change freely.
abstract final class AppRoutes {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const login = 'login';
  static const register = 'register';
  static const profileSetup = 'profileSetup';
  static const assessmentIntro = 'assessmentIntro';
  static const assessmentQuestions = 'assessmentQuestions';
  static const assessmentResult = 'assessmentResult';
  static const dashboard = 'dashboard';
  static const paywall = 'paywall';
  static const childHome = 'childHome';
  static const lessonIntro = 'lessonIntro';
  static const activityTap = 'activityTap';
  static const activityMatch = 'activityMatch';
  static const activityTrace = 'activityTrace';
  static const activityListen = 'activityListen';
  static const reward = 'reward';
  static const books = 'books';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        name: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/assessment',
        name: AppRoutes.assessmentIntro,
        builder: (context, state) => const AssessmentIntroScreen(),
        routes: [
          GoRoute(
            path: 'questions',
            name: AppRoutes.assessmentQuestions,
            builder: (context, state) => const AssessmentQuestionScreen(),
          ),
          GoRoute(
            path: 'result',
            name: AppRoutes.assessmentResult,
            builder: (context, state) => const AssessmentResultScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard',
        name: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/paywall',
        name: AppRoutes.paywall,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/child',
        name: AppRoutes.childHome,
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: '/lesson',
        name: AppRoutes.lessonIntro,
        builder: (context, state) => const LessonIntroScreen(),
        routes: [
          GoRoute(
            path: 'tap',
            name: AppRoutes.activityTap,
            builder: (context, state) => const TapActivityScreen(),
          ),
          GoRoute(
            path: 'match',
            name: AppRoutes.activityMatch,
            builder: (context, state) => const MatchActivityScreen(),
          ),
          GoRoute(
            path: 'trace',
            name: AppRoutes.activityTrace,
            builder: (context, state) => const TraceActivityScreen(),
          ),
          GoRoute(
            path: 'listen',
            name: AppRoutes.activityListen,
            builder: (context, state) => const ListenActivityScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/reward',
        name: AppRoutes.reward,
        builder: (context, state) => const RewardScreen(),
      ),
      GoRoute(
        path: '/books',
        name: AppRoutes.books,
        builder: (context, state) => const BooksScreen(),
      ),
    ],
  );
});
