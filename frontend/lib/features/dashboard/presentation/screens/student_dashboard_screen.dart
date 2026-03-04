import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/router/app_router.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Unread count provider ─────────────────────────────────────────────────────
final unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(ApiConstants.adminStats
        .replaceAll('/admin/stats', '/notifications/unread-count'));
    return (resp.data as Map<String, dynamic>)['unread_count'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});

class StudentDashboardScreen extends ConsumerWidget {
  final Widget child;
  const StudentDashboardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;
    final unreadAsync = ref.watch(unreadNotifCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.gradientPrimary,
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.work_outline_rounded,
                color: AppColors.secondary, size: 28),
            const SizedBox(width: 8),
            const Text('Internship',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // ── Notification bell ──────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.secondary),
                onPressed: () => context.push('/notifications'),
              ),
              if (unread > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // ── Avatar ────────────────────────────────────────────────
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                (user?.email.substring(0, 1) ?? 'U').toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            onPressed: () => context.go(AppRoutes.profile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();

    final routes = [
      AppRoutes.dashboard,
      AppRoutes.internships,
      AppRoutes
          .myApplications, // Currently mapping Tests to my applications temporarily
      AppRoutes.profile,
    ];

    final currentIndex = routes.indexWhere((r) => location.startsWith(r));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex < 0 ? 0 : currentIndex,
          onTap: (i) => context.go(routes[i]),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.secondary,
          unselectedItemColor: AppColors.textOnPrimary.withValues(alpha: 0.7),
          backgroundColor: AppColors.primary,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.home_filled),
                ),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.work_rounded),
                ),
                label: 'Internships'),
            BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.description_rounded),
                ),
                label: 'Tests'),
            BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.person),
                ),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
