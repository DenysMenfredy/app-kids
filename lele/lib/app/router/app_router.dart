import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/firebase/firebase_providers.dart';

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

/// Screens a signed-out visitor is allowed to see.
const _publicRoutes = {'/', '/welcome', '/login', '/register'};

/// Keeps the parent on the right side of the sign-in boundary.
///
/// Reaching a protected screen without an account used to leave the app
/// showing generic failures, because every Firestore read behind it was
/// denied. Demo mode has no accounts, so no gating applies there.
String? _authRedirect(FirebaseAuth auth, GoRouterState state) {
  final signedIn = auth.currentUser != null;
  final location = state.matchedLocation;

  if (!signedIn) {
    return _publicRoutes.contains(location) ? null : '/login';
  }
  // A signed-in parent has no use for the splash or the sign-in form.
  // Registration is deliberately left alone: it sends itself on to profile
  // setup, and redirecting here would race that.
  if (location == '/' || location == '/login') return '/dashboard';
  return null;
}

/// Bridges the auth stream to something GoRouter can listen to, so the
/// redirect re-runs the moment someone signs in or out.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = AppConfig.useFirebase ? ref.watch(firebaseAuthProvider) : null;
  final refresh = auth == null ? null : _AuthRefresh(auth.authStateChanges());
  ref.onDispose(() => refresh?.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: auth == null
        ? null
        : (context, state) => _authRedirect(auth, state),
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
        builder: (context, state) => ProfileSetupScreen(
          createNew: state.uri.queryParameters['new'] == 'true',
          editExisting: state.uri.queryParameters['edit'] == 'true',
        ),
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
