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
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/books/presentation/book_reader_screen.dart';
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
import '../../features/session/presentation/child_profile_gate.dart';

/// Route names — use these with `context.goNamed` so paths can change freely.
abstract final class AppRoutes {
  static const splash = 'splash';
  static const welcome = 'welcome';
  static const login = 'login';
  static const register = 'register';
  static const emailVerification = 'emailVerification';
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
  static const bookReader = 'bookReader';
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
  if (location == '/profile-setup' && _requiresEmailVerification(auth)) {
    final query = state.uri.queryParameters;
    final next = query['edit'] == 'true'
        ? 'edit-child'
        : query['new'] == 'true'
        ? 'add-child'
        : 'new-child';
    return Uri(
      path: '/verify-email',
      queryParameters: {'next': next},
    ).toString();
  }
  if (location == '/verify-email') {
    return null;
  }
  // Registration and login complete their own post-auth routing. In
  // particular, provider sign-in may need to ask a new Apple identity
  // whether the parent already has an account before onboarding starts.
  if (location == '/') return '/dashboard';
  return null;
}

bool _requiresEmailVerification(FirebaseAuth auth) {
  final user = auth.currentUser;
  return user != null &&
      user.providerData.any((provider) => provider.providerId == 'password') &&
      !user.emailVerified;
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
  final refresh = auth == null ? null : _AuthRefresh(auth.userChanges());
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
        path: '/verify-email',
        name: AppRoutes.emailVerification,
        builder: (context, state) => EmailVerificationScreen(
          nextStep: state.uri.queryParameters['next'] ?? 'dashboard',
          sendOnOpen: state.uri.queryParameters['send'] == 'true',
        ),
      ),
      GoRoute(
        path: '/profile-setup',
        name: AppRoutes.profileSetup,
        builder: (context, state) {
          final edit = state.uri.queryParameters['edit'] == 'true';
          final screen = ProfileSetupScreen(
            createNew: state.uri.queryParameters['new'] == 'true',
            editExisting: edit,
          );
          return edit ? ChildProfileGate(child: screen) : screen;
        },
      ),
      GoRoute(
        path: '/assessment',
        name: AppRoutes.assessmentIntro,
        builder: (context, state) =>
            const ChildProfileGate(child: AssessmentIntroScreen()),
        routes: [
          GoRoute(
            path: 'questions',
            name: AppRoutes.assessmentQuestions,
            builder: (context, state) =>
                const ChildProfileGate(child: AssessmentQuestionScreen()),
          ),
          GoRoute(
            path: 'result',
            name: AppRoutes.assessmentResult,
            builder: (context, state) =>
                const ChildProfileGate(child: AssessmentResultScreen()),
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
        builder: (context, state) =>
            const ChildProfileGate(child: ChildHomeScreen()),
      ),
      GoRoute(
        path: '/lesson',
        name: AppRoutes.lessonIntro,
        builder: (context, state) =>
            const ChildProfileGate(child: LessonIntroScreen()),
        routes: [
          GoRoute(
            path: 'tap',
            name: AppRoutes.activityTap,
            builder: (context, state) =>
                const ChildProfileGate(child: TapActivityScreen()),
          ),
          GoRoute(
            path: 'match',
            name: AppRoutes.activityMatch,
            builder: (context, state) =>
                const ChildProfileGate(child: MatchActivityScreen()),
          ),
          GoRoute(
            path: 'trace',
            name: AppRoutes.activityTrace,
            builder: (context, state) =>
                const ChildProfileGate(child: TraceActivityScreen()),
          ),
          GoRoute(
            path: 'listen',
            name: AppRoutes.activityListen,
            builder: (context, state) =>
                const ChildProfileGate(child: ListenActivityScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/reward',
        name: AppRoutes.reward,
        builder: (context, state) =>
            const ChildProfileGate(child: RewardScreen()),
      ),
      GoRoute(
        path: '/books',
        name: AppRoutes.books,
        builder: (context, state) => const BooksScreen(),
        routes: [
          GoRoute(
            path: ':bookId',
            name: AppRoutes.bookReader,
            builder: (context, state) => ChildProfileGate(
              child: BookReaderScreen(bookId: state.pathParameters['bookId']!),
            ),
          ),
        ],
      ),
    ],
  );
});
