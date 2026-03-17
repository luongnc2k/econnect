import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
import 'package:client/features/tutor/view/widgets/income_dashboard_widget.dart';
import 'package:client/features/tutor/view/widgets/tutor_class_card_widget.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorHomeTab extends ConsumerWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onScheduleTap;

  const TutorHomeTab({super.key, this.onProfileTap, this.onScheduleTap});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng,';
    if (h < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  static const _maxHomeClasses = 3;

  List<ClassSession> _todayClasses(List<ClassSession> all) {
    final today = DateTime.now();
    return all.where((c) {
      final dt = c.startDateTime;
      if (dt == null) return false;
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(tutorHomeViewModelProvider);
    final hPad = responsiveHPad(context);

    final todayClasses = _todayClasses(state.upcomingClasses);
    final previewClasses = state.upcomingClasses
        .where((c) => !todayClasses.contains(c))
        .take(_maxHomeClasses)
        .toList();
    final hasMore = state.upcomingClasses.length - todayClasses.length > _maxHomeClasses;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(tutorHomeViewModelProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: HomeHeaderWidget(
                  greeting: _greeting(),
                  userName: user?.fullName ?? 'Giảng viên',
                  avatarUrl: user?.avatarUrl,
                  onAvatarTap: onProfileTap,
                  onNotificationTap: () {},
                ),
              ),
            ),

            // ── Lớp dạy hôm nay ─────────────────────────────────────
            if (!state.isLoading && todayClasses.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                  child: _TodayBanner(
                    classes: todayClasses,
                    onTap: onScheduleTap,
                  ),
                ),
              ),

            // ── Income dashboard ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: IncomeDashboardWidget(
                  income: state.income,
                  isLoading: state.isLoadingIncome,
                ),
              ),
            ),

            // ── Lớp học sắp dạy ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                child: SectionHeaderWidget(
                  title: 'Lớp học sắp dạy',
                  actionText: hasMore ? 'Xem tất cả' : null,
                  onActionTap: onScheduleTap,
                ),
              ),
            ),

            if (state.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                  child: const _ClassListSkeleton(),
                ),
              )
            else if (state.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                  child: _ErrorBanner(message: state.error!),
                ),
              )
            else if (previewClasses.isEmpty && todayClasses.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                  child: _EmptyClasses(
                    onCreateClass: () =>
                        context.push(AppRoutes.teacherCreateClass),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: previewClasses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                  child: TutorClassCardWidget(session: previewClasses[i]),
                ),
              ),

            // "Xem thêm X lớp" link
            if (hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                  child: _SeeMoreButton(
                    count: state.upcomingClasses.length -
                        todayClasses.length -
                        _maxHomeClasses,
                    onTap: onScheduleTap,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _ClassListSkeleton extends StatelessWidget {
  const _ClassListSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyClasses extends StatelessWidget {
  final VoidCallback onCreateClass;

  const _EmptyClasses({required this.onCreateClass});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Chưa có lớp học nào sắp dạy',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onCreateClass,
            child: const Text('Tạo lớp học ngay'),
          ),
        ],
      ),
    );
  }
}

// ─── Today banner ────────────────────────────────────────────────────────────

class _TodayBanner extends StatelessWidget {
  final List<ClassSession> classes;
  final VoidCallback? onTap;

  const _TodayBanner({required this.classes, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = classes.first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.tertiary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.today_rounded, size: 20, color: cs.tertiary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classes.length == 1
                        ? 'Hôm nay bạn có 1 lớp học'
                        : 'Hôm nay bạn có ${classes.length} lớp học',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${first.timeText} · ${first.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onTertiaryContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onTertiaryContainer),
          ],
        ),
      ),
    );
  }
}

// ─── See more button ──────────────────────────────────────────────────────────

class _SeeMoreButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _SeeMoreButton({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Xem thêm $count lớp khác',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Error ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Không thể tải dữ liệu: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
