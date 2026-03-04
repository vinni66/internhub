import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final myApplicationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(dioClientProvider);
  final resp = await client.dio.get(ApiConstants.myApplications);
  // Backend may return either a bare list or a paginated { items: [...] }
  final raw = resp.data;
  if (raw is List) {
    return List<Map<String, dynamic>>.from(raw);
  } else if (raw is Map && raw['items'] is List) {
    return List<Map<String, dynamic>>.from(raw['items'] as List);
  }
  return [];
});

// ─── Screen ───────────────────────────────────────────────────────────────────
class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(myApplicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myApplicationsProvider),
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (apps) => apps.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.work_outline,
                        size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text("No applications yet",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Browse internships and apply',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go('/internships'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Browse Internships'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apps.length,
                itemBuilder: (ctx, i) => _ApplicationCard(data: apps[i]),
              ),
      ),
    );
  }
}

// ─── Application Card ─────────────────────────────────────────────────────────
class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ApplicationCard({required this.data});

  static const _statusConfig = {
    'submitted': (
      color: Color(0xFF7C83FD),
      icon: Icons.schedule,
      label: 'Applied'
    ),
    'shortlisted': (
      color: Color(0xFF00C9A7),
      icon: Icons.star,
      label: 'Shortlisted'
    ),
    'rejected': (
      color: Color(0xFFFF6B6B),
      icon: Icons.cancel,
      label: 'Rejected'
    ),
    'hired': (
      color: Color(0xFF00C9A7),
      icon: Icons.check_circle,
      label: 'Hired! 🎉'
    ),
    'withdrawn': (
      color: Color(0xFF9B9B9B),
      icon: Icons.undo,
      label: 'Withdrawn'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'submitted';
    final cfg = _statusConfig[status] ??
        (color: AppColors.textMuted, icon: Icons.help_outline, label: status);
    final internship = data['internship'] as Map<String, dynamic>? ?? {};
    final appliedAt = data['applied_at'] != null
        ? DateTime.tryParse(data['applied_at'] as String)
        : null;
    final decisionNote = data['decision_note'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(cfg.icon, color: cfg.color, size: 18),
                const SizedBox(width: 8),
                Text(cfg.label,
                    style: TextStyle(
                        color: cfg.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const Spacer(),
                if (appliedAt != null)
                  Text(
                    'Applied ${_daysAgo(appliedAt)} ago',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // ── Internship info ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(internship['title'] as String? ?? 'Internship',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.business,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(internship['company_name'] as String? ?? '',
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13)),
                    const SizedBox(width: 12),
                    const Icon(Icons.work_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      (internship['mode'] as String? ?? 'hybrid')[0]
                              .toUpperCase() +
                          (internship['mode'] as String? ?? 'hybrid')
                              .substring(1),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                if (decisionNote != null && decisionNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.comment,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(decisionNote,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _daysAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return '1 day';
    return '$diff days';
  }
}
