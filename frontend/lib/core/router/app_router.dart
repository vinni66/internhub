import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:internhub_app/features/admin/presentation/screens/admin_users_list_screen.dart';
import 'package:internhub_app/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:internhub_app/features/auth/presentation/screens/login_screen.dart';
import 'package:internhub_app/features/auth/presentation/screens/register_screen.dart';
import 'package:internhub_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:internhub_app/features/dashboard/presentation/screens/student_dashboard_screen.dart';
import 'package:internhub_app/features/dashboard/presentation/screens/student_home_screen.dart';
import 'package:internhub_app/features/exam/presentation/screens/exam_result_screen.dart';
import 'package:internhub_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:internhub_app/features/faculty/presentation/screens/create_internship_screen.dart';
import 'package:internhub_app/features/faculty/presentation/screens/faculty_dashboard_screen.dart';
import 'package:internhub_app/features/internship/presentation/screens/internship_detail_screen.dart';
import 'package:internhub_app/features/internship/presentation/screens/internship_list_screen.dart';
import 'package:internhub_app/features/internship/presentation/screens/my_applications_screen.dart';
import 'package:internhub_app/features/faculty/presentation/screens/applications_list_screen.dart';
import 'package:internhub_app/features/faculty/presentation/screens/live_monitor_screen.dart';
import 'package:internhub_app/features/faculty/presentation/screens/flag_review_screen.dart';
import 'package:internhub_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:internhub_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:internhub_app/features/recommendations/presentation/screens/recommendations_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String internships = '/internships';
  static const String myApplications = '/applications';
  static const String recommendations = '/recommendations';
  static const String analytics = '/analytics';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String adminDashboard = '/admin';
  static const String facultyDashboard = '/faculty';
  static const String createInternship = '/faculty/create-internship';
  static const String exam = '/exam';
  static const String examResult = '/exam-result';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final isInitial = authState is AuthStateInitial;
      final isLoading = authState is AuthStateLoading;
      final isAuthenticated = authState is AuthStateAuthenticated;
      final loc = state.matchedLocation;

      final isAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;

      if (isInitial || isLoading) return AppRoutes.splash;
      if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;
      if (authState is AuthStateAuthenticated &&
          (isAuthRoute || loc == AppRoutes.splash)) {
        final user = authState.user;
        if (user.isAdmin) return AppRoutes.adminDashboard;
        if (user.role == 'faculty') return AppRoutes.facultyDashboard;
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      // ─── Public ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (ctx, anim, sec, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (ctx, anim, sec, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ─── Exam (full-screen, no shell) ─────────────────────────────────
      GoRoute(
        path: '${AppRoutes.exam}/:internshipId',
        builder: (context, state) => ExamScreen(
          internshipId: state.pathParameters['internshipId']!,
          internshipTitle:
              state.uri.queryParameters['title'] ?? 'Internship Exam',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.examResult}/:sessionId',
        builder: (context, state) => ExamResultScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),

      // ─── Admin (standalone) ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUsersListScreen(),
      ),

      // ─── Faculty shell ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.facultyDashboard,
        builder: (context, state) => const FacultyDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.createInternship,
        builder: (context, state) => const CreateInternshipScreen(),
      ),
      GoRoute(
        path: '/faculty/internship/:id/applications',
        builder: (context, state) => ApplicationsListScreen(
          internshipId: state.pathParameters['id']!,
          internshipTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/faculty/internship/:id/monitor',
        builder: (context, state) => LiveMonitorScreen(
          internshipId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/faculty/flags/:sessionId',
        builder: (context, state) => FlagReviewScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),

      // ─── Notifications ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ─── Student shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            StudentDashboardScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const StudentHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.internships,
            builder: (context, state) => const InternshipListScreen(),
          ),
          GoRoute(
            path: '/internships/:id',
            builder: (context, state) => InternshipDetailScreen(
              internshipId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.myApplications,
            builder: (context, state) => const MyApplicationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.recommendations,
            builder: (context, state) => const RecommendationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

// ─── Helper screens ───────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
