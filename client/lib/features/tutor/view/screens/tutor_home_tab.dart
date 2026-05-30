import 'package:client/core/localization/app_language.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/featured_teacher_list_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
import 'package:client/features/tutor/view/widgets/tutor_class_card_widget.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorHomeTab extends ConsumerWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onScheduleTap;

  const TutorHomeTab({super.key, this.onProfileTap, this.onScheduleTap});

  String _greeting(AppStrings strings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return strings.morningGreeting;
    if (hour < 18) return strings.afternoonGreeting;
    return strings.eveningGreeting;
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
    final strings = ref.watch(appStringsProvider);
    final hPad = responsiveHPad(context);

    final todayClasses = _todayClasses(state.upcomingClasses);
    final previewClasses = state.upcomingClasses.take(_maxHomeClasses).toList();
    final hasMore = state.upcomingClasses.length > _maxHomeClasses;
    final remainingCount = hasMore
        ? state.upcomingClasses.length - _maxHomeClasses
        : 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(tutorHomeViewModelProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                child: HomeHeaderWidget(
                  greeting: _greeting(strings),
                  userName: user?.fullName ?? strings.defaultTeacherName,
                  avatarUrl: user?.avatarUrl,
                  onAvatarTap: onProfileTap,
                  onNotificationTap: () =>
                      context.push(AppRoutes.notifications),
                ),
              ),
            ),

            if (!state.isLoading && todayClasses.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                  child: _TodayBanner(
                    classes: todayClasses,
                    title: strings.todayClassCount(todayClasses.length),
                    onTap: onScheduleTap,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                child: SectionHeaderWidget(
                  title: strings.upcomingTeachingClasses,
                  actionText: hasMore ? strings.seeAll : null,
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
                  child: _ErrorBanner(
                    message: strings.loadDataError(state.error!),
                  ),
                ),
              )
            else if (previewClasses.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                  child: _EmptyClasses(
                    message: strings.noTeachingClasses,
                    actionLabel: strings.createClassNow,
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
                  child: TutorClassCardWidget(
                    session: previewClasses[i],
                    onTap: () => context.push(
                      AppRoutes.teacherClassDetail,
                      extra: previewClasses[i],
                    ),
                  ),
                ),
              ),

            if (hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                  child: _SeeMoreButton(
                    label: strings.seeMoreClasses(remainingCount),
                    onTap: onScheduleTap,
                  ),
                ),
              ),

            if (state.featuredTeachers.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeaderWidget(title: strings.featuredTeachers),
                      const SizedBox(height: 12),
                      FeaturedTeacherListWidget(
                        teachers: state.featuredTeachers,
                        onTeacherTap: (teacher) => context.push(
                          AppRoutes.userProfile.replaceFirst(
                            ':userId',
                            teacher.id,
                          ),
                        ),
                      ),
                    ],
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

class _EmptyClasses extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onCreateClass;

  const _EmptyClasses({
    required this.message,
    required this.actionLabel,
    required this.onCreateClass,
  });

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
          Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onCreateClass,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TodayBanner extends StatelessWidget {
  final List<ClassSession> classes;
  final String title;
  final VoidCallback? onTap;

  const _TodayBanner({required this.classes, required this.title, this.onTap});

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
                    title,
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
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: cs.onTertiaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeMoreButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SeeMoreButton({required this.label, this.onTap});

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
          label,
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

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
