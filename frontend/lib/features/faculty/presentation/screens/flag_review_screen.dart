import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:intl/intl.dart';

// ─── Provider ───────────────────────────────────────────────────────────────
final flagEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, sessionId) async {
  final client = ref.watch(dioClientProvider);
  final resp =
      await client.dio.get(ApiConstants.facultySessionEvents(sessionId));
  return List<Map<String, dynamic>>.from(resp.data);
});

// ─── Screen ─────────────────────────────────────────────────────────────────
class FlagReviewScreen extends ConsumerWidget {
  final String sessionId;
  const FlagReviewScreen({super.key, required this.sessionId});

  Future<void> _submitOverride(
      BuildContext context, WidgetRef ref, bool isFlagged) async {
    try {
      final client = ref.read(dioClientProvider);
      await client.dio.patch(
        ApiConstants.facultyOverrideFlag(sessionId),
        data: {'is_flagged': isFlagged},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isFlagged
                  ? 'AI Decision Accepted'
                  : 'Session Approved & Flag Cleared')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(flagEventsProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Flag Review'),
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(flagEventsProvider(sessionId))),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading events: $e')),
        data: (events) {
          if (events.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: AppColors.error.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ FLAGGED SESSION',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${events.length} Proctoring Events Detected',
                        style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final e = events[index];
                    String timeText = "Unknown Time";
                    if (e['created_at'] != null) {
                      try {
                        final dt = DateTime.parse(e['created_at']).toLocal();
                        timeText = DateFormat('hh:mm:ss a').format(dt);
                      } catch (_) {}
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      e['event_type']
                                              ?.toString()
                                              .toUpperCase()
                                              .replaceAll('_', ' ') ??
                                          'UNKNOWN EVENT',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(timeText,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Severity: ${e['severity']}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              if (e['event_metadata'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppColors.bgElevated,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(e['event_metadata'].toString(),
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12)),
                                )
                              ]
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildActionBottomBar(context, ref),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 64, color: AppColors.success),
                const SizedBox(height: 16),
                const Text('No Proctor Events Recorded',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'The student maintained high integrity during this session.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        _buildActionBottomBar(context, ref),
      ],
    );
  }

  Widget _buildActionBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.bgCard, boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Faculty Action',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _submitOverride(context, ref, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Accept AI Decision'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _submitOverride(context, ref, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Override & Approve'),
                ),
              ),
            ],
          )
        ]));
  }
}
