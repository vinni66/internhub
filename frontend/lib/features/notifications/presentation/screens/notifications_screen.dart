import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(dioClientProvider);
  try {
    final resp = await client.dio.get(
        ApiConstants.adminStats.replaceAll('/admin/stats', '/notifications'));
    return List<Map<String, dynamic>>.from(resp.data as List);
  } catch (_) {
    // Demo notifications
    return [
      {
        'id': 'n1',
        'type': 'application_update',
        'title': 'Application Shortlisted! 🎉',
        'message':
            'Your application to ML Engineer Intern at AI Innovations has been shortlisted.',
        'is_read': false,
        'action_url': '/applications',
        'created_at':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': 'n2',
        'type': 'new_internship',
        'title': 'New Internship Match',
        'message':
            'A new Flutter Developer Intern position matching your skills was posted.',
        'is_read': true,
        'action_url': '/internships',
        'created_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(dioClientProvider).dio.post(ApiConstants
                    .adminStats
                    .replaceAll('/admin/stats', '/notifications/read-all'));
                ref.invalidate(notificationsProvider);
              } catch (_) {}
            },
            child: const Text('Mark all read',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) => notifications.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_rounded,
                        size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('No notifications yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('We\'ll notify you of updates here',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) =>
                    _NotificationCard(data: notifications[i]),
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationCard({required this.data});

  static const _typeIcons = {
    'application_update': Icons.description_rounded,
    'new_internship': Icons.work_rounded,
    'exam_reminder': Icons.quiz_rounded,
    'system': Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isRead = data['is_read'] as bool? ?? true;
    final type = data['type'] as String? ?? 'system';
    final icon = _typeIcons[type] ?? Icons.notifications_rounded;
    final createdAt = data['created_at'] != null
        ? DateTime.tryParse(data['created_at'] as String)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isRead
            ? AppColors.bgCard
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] as String? ?? '',
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['message'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
