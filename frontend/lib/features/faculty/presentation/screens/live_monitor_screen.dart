import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:intl/intl.dart';

// ─── Provider for Polling ───────────────────────────────────────────────────
final liveMonitorProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>(
        (ref, internshipId) async* {
  final client = ref.watch(dioClientProvider);

  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  // Initial fetch immediately
  try {
    final resp =
        await client.dio.get(ApiConstants.facultyActiveSessions(internshipId));
    yield List<Map<String, dynamic>>.from(resp.data);
  } catch (_) {
    yield [];
  }

  // Poll every 5 seconds
  while (!isDisposed) {
    await Future.delayed(const Duration(seconds: 5));
    if (isDisposed) break;
    try {
      final resp = await client.dio
          .get(ApiConstants.facultyActiveSessions(internshipId));
      yield List<Map<String, dynamic>>.from(resp.data);
    } catch (_) {
      // Retain old state on error silently to avoid flashing UI
    }
  }
});

// ─── Screen ─────────────────────────────────────────────────────────────────
class LiveMonitorScreen extends ConsumerWidget {
  final String internshipId;
  const LiveMonitorScreen({super.key, required this.internshipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(liveMonitorProvider(internshipId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Exam Monitor'),
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppColors.error, size: 12),
                SizedBox(width: 6),
                Text('REC',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.error)),
              ],
            ),
          )
        ],
      ),
      body: streamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading monitor: $e')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No Active Sessions',
                      style: TextStyle(
                          fontSize: 18, color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final activeCount =
              sessions.where((s) => s['status'] == 'active').length;
          final flaggedCount =
              sessions.where((s) => s['is_flagged'] == true).length;

          return Column(
            children: [
              // Header Stats
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.bgElevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBlock(
                        title: 'Active Now',
                        value: '$activeCount',
                        color: AppColors.primary),
                    _StatBlock(
                        title: 'Flagged',
                        value: '$flaggedCount',
                        color: AppColors.error),
                    _StatBlock(
                        title: 'Total',
                        value: '${sessions.length}',
                        color: AppColors.textPrimary),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(liveMonitorProvider(internshipId));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      return _StudentSessionCard(session: sessions[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatBlock(
      {required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StudentSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _StudentSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isFlagged = session['is_flagged'] == true;
    final status = session['status'] as String? ?? 'unknown';
    final integrityScore = (session['integrity_score'] as num?)?.toInt() ?? 100;
    final sessionId = session['id'];

    String startedText = "Unknown";
    if (session['started_at'] != null) {
      try {
        final dt = DateTime.parse(session['started_at']).toLocal();
        startedText = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isFlagged ? AppColors.error : Colors.transparent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isFlagged
                      ? AppColors.error.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  child: Icon(Icons.person,
                      color: isFlagged ? AppColors.error : AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['student_email'] ?? 'Unknown Student',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Started: $startedText',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'active'
                        ? AppColors.success.withValues(alpha: 0.2)
                        : (status == 'completed' || status == 'submitted'
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.bgElevated),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: status == 'active'
                            ? AppColors.success
                            : AppColors.textPrimary),
                  ),
                )
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Integrity Score',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$integrityScore%',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isFlagged
                                ? AppColors.error
                                : AppColors.success)),
                  ],
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Warnings',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${session['warnings_count'] ?? 0}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                ElevatedButton(
                  onPressed: () {
                    context.push('/faculty/flags/$sessionId');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isFlagged ? AppColors.error : AppColors.bgElevated,
                    foregroundColor:
                        isFlagged ? Colors.white : AppColors.textPrimary,
                  ),
                  child: Text(isFlagged ? 'Review Flags' : 'View Session'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
