import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class InternshipModel {
  final String id;
  final String title;
  final String companyName;
  final String? companyLogoUrl;
  final String? posterUrl;
  final String mode;
  final String? location;
  final String? stipendRange;
  final List<String> skills;
  final double? minCgpa;
  final String? deadline;
  final String description;

  const InternshipModel({
    required this.id,
    required this.title,
    required this.companyName,
    this.companyLogoUrl,
    this.posterUrl,
    required this.mode,
    this.location,
    this.stipendRange,
    this.skills = const [],
    this.minCgpa,
    this.deadline,
    required this.description,
  });

  factory InternshipModel.fromJson(Map<String, dynamic> j) {
    // Build a human-friendly stipend range from the two separate fields
    final sMin = j['stipend_min'] as int?;
    final sMax = j['stipend_max'] as int?;
    String? stipendRange;
    if (sMin != null && sMax != null) {
      stipendRange = '₹$sMin – ₹$sMax/mo';
    } else if (sMin != null) {
      stipendRange = '₹$sMin/mo';
    } else if (sMax != null) {
      stipendRange = '₹$sMax/mo';
    }

    return InternshipModel(
      id: j['id'] as String,
      title: j['title'] as String,
      companyName: j['company_name'] as String,
      companyLogoUrl: j['company_logo_url'] as String?,
      posterUrl: j['poster_url'] as String?,
      mode: (j['mode'] as String?) ?? 'remote',
      location: j['location'] as String?,
      stipendRange: stipendRange,
      skills: List<String>.from(j['required_skills'] as List? ?? []),
      minCgpa: (j['min_cgpa'] as num?)?.toDouble(),
      deadline: j['application_deadline'] != null
          ? j['application_deadline'].toString().split('T')[0]
          : null,
      description: j['description'] as String,
    );
  }
}

/// Adzuna-specific job model for live external listings.
class AdzunaJobModel {
  final String id;
  final String title;
  final String companyName;
  final String description;
  final String location;
  final String? category;
  final String redirectUrl;
  final String? created;

  const AdzunaJobModel({
    required this.id,
    required this.title,
    required this.companyName,
    required this.description,
    required this.location,
    this.category,
    required this.redirectUrl,
    this.created,
  });

  factory AdzunaJobModel.fromJson(Map<String, dynamic> j) {
    return AdzunaJobModel(
      id: j['id']?.toString() ?? '',
      title: j['title'] as String? ?? 'Internship',
      companyName: j['company_name'] as String? ?? 'Unknown Company',
      description: j['description'] as String? ?? '',
      location: j['location'] as String? ?? 'India',
      category: j['category'] as String?,
      redirectUrl: j['redirect_url'] as String? ?? '',
      created: j['created'] as String?,
    );
  }
}

class InternshipFilters {
  final String query;
  final String mode;
  const InternshipFilters({this.query = '', this.mode = 'All'});
  InternshipFilters copyWith({String? query, String? mode}) {
    return InternshipFilters(
      query: query ?? this.query,
      mode: mode ?? this.mode,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final filtersProvider =
    StateProvider<InternshipFilters>((ref) => const InternshipFilters());

final internshipListProvider =
    FutureProvider.autoDispose<List<InternshipModel>>((ref) async {
  final filters = ref.watch(filtersProvider);
  final client = ref.watch(dioClientProvider);

  final queryParams = <String, dynamic>{};
  if (filters.query.trim().isNotEmpty) {
    queryParams['search'] = filters.query.trim();
  }
  if (filters.mode != 'All') queryParams['mode'] = filters.mode.toLowerCase();

  // NOTE: Dio baseUrl already ends at /api/v1, so paths start WITHOUT /api/v1
  final resp =
      await client.dio.get('/internships', queryParameters: queryParams);
  final items = List<Map<String, dynamic>>.from(resp.data['items'] as List);
  return items.map((j) => InternshipModel.fromJson(j)).toList();
});

final adzunaJobsProvider =
    FutureProvider.autoDispose<List<AdzunaJobModel>>((ref) async {
  final filters = ref.watch(filtersProvider);
  final client = ref.watch(dioClientProvider);

  try {
    final what = filters.query.trim().isNotEmpty
        ? '${filters.query.trim()} internship'
        : 'internship';
    final resp = await client.dio.get(
      ApiConstants.adzunaJobs,
      queryParameters: {'what': what, 'page_size': 20},
    );
    final items = List<Map<String, dynamic>>.from(resp.data['items'] as List);
    return items.map((j) => AdzunaJobModel.fromJson(j)).toList();
  } catch (_) {
    return [];
  }
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class InternshipListScreen extends ConsumerStatefulWidget {
  const InternshipListScreen({super.key});

  @override
  ConsumerState<InternshipListScreen> createState() =>
      _InternshipListScreenState();
}

class _InternshipListScreenState extends ConsumerState<InternshipListScreen>
    with SingleTickerProviderStateMixin {
  Timer? _debounce;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(filtersProvider.notifier).state =
          ref.read(filtersProvider).copyWith(query: val);
    });
  }

  @override
  Widget build(BuildContext context) {
    final internshipsAsync = ref.watch(internshipListProvider);
    final adzunaAsync = ref.watch(adzunaJobsProvider);
    final currentFilters = ref.watch(filtersProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            title: const Text('Internships',
                style: TextStyle(fontWeight: FontWeight.bold)),
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: AppColors.bgSurface,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(internshipListProvider);
                  ref.invalidate(adzunaJobsProvider);
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(104),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by title, company…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.bgElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: AppColors.border,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.school_rounded, size: 16),
                          text: 'Faculty Posted'),
                      Tab(
                          icon: Icon(Icons.public_rounded, size: 16),
                          text: 'Live Jobs'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: Faculty Posted ─────────────────────────────────────
            Column(
              children: [
                // Mode filter chips
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: ['All', 'Remote', 'Onsite', 'Hybrid']
                        .map((label) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(label),
                                selected: currentFilters.mode == label,
                                onSelected: (_) {
                                  ref.read(filtersProvider.notifier).state =
                                      currentFilters.copyWith(mode: label);
                                },
                                selectedColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: internshipsAsync.when(
                    data: (internships) => internships.isEmpty
                        ? _EmptyState(
                            icon: Icons.work_off_rounded,
                            message: 'No faculty-posted internships yet',
                            sub: 'Check back soon or browse Live Jobs →',
                            onRefresh: () =>
                                ref.invalidate(internshipListProvider),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: internships.length,
                            itemBuilder: (ctx, i) =>
                                _InternshipCard(internship: internships[i]),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _ErrorState(message: e.toString()),
                  ),
                ),
              ],
            ),

            // ── Tab 2: Adzuna Live Jobs ───────────────────────────────────
            adzunaAsync.when(
              data: (jobs) => jobs.isEmpty
                  ? _EmptyState(
                      icon: Icons.cloud_off_rounded,
                      message: 'No live jobs fetched',
                      sub: 'Try refreshing or a different search',
                      onRefresh: () => ref.invalidate(adzunaJobsProvider),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: jobs.length,
                      itemBuilder: (ctx, i) => _AdzunaJobCard(job: jobs[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internship Card (Faculty Posted) ────────────────────────────────────────

class _InternshipCard extends StatelessWidget {
  final InternshipModel internship;
  const _InternshipCard({required this.internship});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/internships/${internship.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CompanyAvatar(internship.companyName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(internship.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(internship.companyName,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  _ModeChip(internship.mode),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (internship.location != null) ...[
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(internship.location!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (internship.stipendRange != null) ...[
                    const Icon(Icons.payments_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(internship.stipendRange!,
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              if (internship.skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: internship.skills
                      .take(4)
                      .map((s) => _SkillChip(s))
                      .toList(),
                ),
              ],
              if (internship.deadline != null ||
                  internship.minCgpa != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (internship.deadline != null)
                      Row(children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Deadline: ${internship.deadline}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ])
                    else
                      const SizedBox.shrink(),
                    if (internship.minCgpa != null)
                      Text('Min CGPA: ${internship.minCgpa}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Adzuna Live Job Card ─────────────────────────────────────────────────────

class _AdzunaJobCard extends StatelessWidget {
  final AdzunaJobModel job;
  const _AdzunaJobCard({required this.job});

  Future<void> _openUrl() async {
    if (job.redirectUrl.isEmpty) return;
    final uri = Uri.parse(job.redirectUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Adzuna badge avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0066CC), Color(0xFF0099FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job.companyName.isNotEmpty
                          ? job.companyName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(job.companyName,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                // Live badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066CC).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(
                          color: Color(0xFF0066CC),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(job.location,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                if (job.category != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.category_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(job.category!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              job.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Apply on Adzuna'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066CC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _CompanyAvatar extends StatelessWidget {
  final String name;
  const _CompanyAvatar(this.name);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: AppColors.gradientPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String mode;
  const _ModeChip(this.mode);
  Color get _color => switch (mode.toLowerCase()) {
        'remote' => AppColors.success,
        'onsite' => AppColors.info,
        _ => AppColors.warning,
      };
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(mode.toUpperCase(),
          style: TextStyle(
              color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  const _SkillChip(this.skill);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(skill,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  final VoidCallback onRefresh;
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.sub,
      required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(sub,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Error: $message',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center),
      ),
    );
  }
}
