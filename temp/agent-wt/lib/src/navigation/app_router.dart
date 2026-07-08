import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/discover/screens/discover_screen.dart';
import '../features/qbank/screens/qbank_screen.dart';
import '../features/progress/screens/progress_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/course/screens/course_detail_screen.dart';
import '../features/player/screens/video_player_screen.dart';
import '../features/quiz/screens/quiz_session_screen.dart';
import '../widgets/main_wrapper.dart';
import '../models/course.dart';
import '../models/quiz.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/auth/auth_cubit.dart';
import '../logic/auth/auth_state.dart';

import 'dart:async';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthCubit authCubit) => GoRouter(
    initialLocation: '/splash',
    navigatorKey: _rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final status = authCubit.state.status;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isSplashing = state.matchedLocation == '/splash';
      final isOtp = state.matchedLocation == '/otp';

      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isRegistering || isOnboarding || isSplashing || isOtp) {
          return '/home';
        }
      } else {
        if (!isLoggingIn && !isRegistering && !isOnboarding && !isSplashing && !isOtp) {
          return '/login';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/course-detail',
        builder: (context, state) {
          final course = state.extra as Course;
          return CourseDetailScreen(course: course);
        },
      ),
      GoRoute(
        path: '/video-player',
        builder: (context, state) {
          final params = state.extra as Map<String, dynamic>;
          return VideoPlayerScreen(
            lessonId: params['lessonId'] as String,
            userEmail: params['userEmail'] as String,
            studentId: params['studentId'] as String,
          );
        },
      ),
      GoRoute(
        path: '/quiz-session',
        builder: (context, state) {
          final params = state.extra as Map<String, dynamic>;
          return QuizSessionScreen(
            quiz: params['quiz'] as Quiz,
            isTutorMode: params['isTutorMode'] as bool? ?? true,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainWrapper(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/qbank',
                builder: (context, state) => const QBankScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
