import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
final internshipApplicantsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, internshipId) async {
    final client = ref.watch(dioClientProvider);
    try {
      final resp =
          await client.dio.get(ApiConstants.facultyApplicants(internshipId));
      return List<Map<String, dynamic>>.from(resp.data as List);
    } catch (_) {
      return [];
    }
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────
class ApplicationsListScreen extends ConsumerWidget {
  final String internshipId;
  final String? internshipTitle;
  const ApplicationsListScreen({
    super.key,
    required this.internshipId,
    this.internshipTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(internshipApplicantsProvider(internshipId));

    return Scaffold(
      appBar: AppBar(
        title: Text(internshipTitle ?? 'Applicants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(internshipApplicantsProvider(internshipId)),
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (apps) => apps.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('No applicants yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('Share the internship to attract candidates',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apps.length,
                itemBuilder: (ctx, i) => _ApplicantCard(
                  data: apps[i],
                  onStatusChange: (appId, status, note) async {
                    try {
                      await ref.read(dioClientProvider).dio.patch(
                        ApiConstants.updateApplicationStatus(appId),
                        data: {
                          'new_status': status,
                          if (note != null) 'decision_note': note,
                        },
                      );
                      ref.invalidate(
                          internshipApplicantsProvider(internshipId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Application $status'),
                          backgroundColor: status == 'shortlisted'
                              ? AppColors.success
                              : AppColors.error,
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ));
                      }
                    }
                  },
                ),
              ),
      ),
    );
  }
}

// ─── Applicant Card ───────────────────────────────────────────────────────────
class _ApplicantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String appId, String status, String? note) onStatusChange;
  const _ApplicantCard({required this.data, required this.onStatusChange});

  static const _statusConfig = {
    'submitted': (color: Color(0xFF7C83FD), label: 'Pending'),
    'shortlisted': (color: Color(0xFF00C9A7), label: 'Shortlisted'),
    'rejected': (color: Color(0xFFFF6B6B), label: 'Rejected'),
    'hired': (color: Color(0xFF00C9A7), label: 'Hired'),
    'withdrawn': (color: Color(0xFF9B9B9B), label: 'Withdrawn'),
  };

  @override
  Widget build(BuildContext context) {
    final appId = data['id'] as String? ?? '';
    final status = data['status'] as String? ?? 'submitted';
    final student = data['student'] as Map<String, dynamic>? ?? {};
    final cfg =
        _statusConfig[status] ?? (color: AppColors.textMuted, label: status);
    final skills = List<String>.from(student['skills'] as List? ?? []);
    final cgpa = student['cgpa'];

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
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    (student['full_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['full_name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Row(children: [
                        if (student['usn'] != null) ...[
                          Text(student['usn'] as String,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(width: 8),
                        ],
                        if (cgpa != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('CGPA: $cgpa',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(cfg.label,
                      style: TextStyle(
                          color: cfg.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          // ── Skills ────────────────────────────────────────────────
          if (skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: skills
                    .take(5)
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.bgElevated,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
          // ── Cover Letter ─────────────────────────────────────────
          if (data['cover_letter'] != null &&
              (data['cover_letter'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${data['cover_letter']}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ),
          const Divider(height: 1),
          // ── Actions ───────────────────────────────────────────────
          if (status == 'submitted')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () =>
                          _confirmAction(context, appId, 'shortlisted', null),
                      icon: const Icon(Icons.star,
                          size: 16, color: AppColors.success),
                      label: const Text('Shortlist',
                          style: TextStyle(color: AppColors.success)),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showRejectDialog(context, appId),
                      icon: const Icon(Icons.cancel,
                          size: 16, color: AppColors.error),
                      label: const Text('Reject',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _confirmAction(context, appId, 'hired', null),
                    icon: const Icon(Icons.check_circle,
                        size: 16, color: AppColors.primary),
                    label: const Text('Hire',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            )
          else if (status == 'shortlisted')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _confirmAction(context, appId, 'hired', null),
                    icon: const Icon(Icons.check_circle,
                        size: 16, color: AppColors.success),
                    label: const Text('Mark Hired',
                        style: TextStyle(color: AppColors.success)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showRejectDialog(context, appId),
                    icon: const Icon(Icons.cancel,
                        size: 16, color: AppColors.error),
                    label: const Text('Reject',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmAction(
      BuildContext ctx, String appId, String status, String? note) {
    onStatusChange(appId, status, note);
  }

  void _showRejectDialog(BuildContext ctx, String appId) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Reject Application'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. Skills mismatch',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChange(appId, 'rejected',
                  ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Reject',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
