import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/class_card_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(tutorHomeViewModelProvider);
    final teacher = user is TeacherMyProfileModel ? user : null;
    final hPad = responsiveHPad(context);

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

            // ── Stats row ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                child: _StatsRow(teacher: teacher),
              ),
            ),

            // ── Lớp học sắp dạy ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                child: SectionHeaderWidget(
                  title: 'Lớp học sắp dạy',
                  actionText: 'Tất cả',
                  onActionTap: onScheduleTap,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(left: hPad),
                child: state.isLoading
                    ? const _ClassListSkeleton()
                    : state.error != null
                        ? _ErrorBanner(message: state.error!)
                        : state.upcomingClasses.isEmpty
                            ? const _EmptyClasses()
                            : _UpcomingClassList(
                                classes: state.upcomingClasses,
                              ),
              ),
            ),

            // ── Thao tác nhanh ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                child: _QuickActions(
                  onCreateClass: () =>
                      context.push(AppRoutes.teacherCreateClass),
                  onSchedule: onScheduleTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final TeacherMyProfileModel? teacher;

  const _StatsRow({this.teacher});

  @override
  Widget build(BuildContext context) {
    final totalSessions = teacher?.totalStudents ?? 0; // reuse as proxy
    final rating = teacher?.rating ?? 0.0;
    final years = teacher?.yearsOfExperience ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_rounded,
            value: teacher != null ? '$totalSessions' : '--',
            label: 'Học viên',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            value: teacher != null
                ? rating > 0
                    ? rating.toStringAsFixed(1)
                    : '--'
                : '--',
            label: 'Đánh giá',
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            value: teacher != null ? '${years}y' : '--',
            label: 'Kinh nghiệm',
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming classes list ──────────────────────────────────────────────────

class _UpcomingClassList extends StatelessWidget {
  final List<ClassSession> classes;

  const _UpcomingClassList({required this.classes});

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.42).clamp(320.0, 460.0);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: classes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = classes[i];
          return ClassCardWidget(
            classCode: s.classCode,
            title: s.title,
            location: s.location,
            teacherName: s.teacherName,
            timeText: s.timeText,
            priceText: s.priceText,
            imageUrl: s.imageUrl,
            statusText: s.statusText,
            countdownText: s.countdownText,
            tags: s.tags,
          );
        },
      ),
    );
  }
}

class _ClassListSkeleton extends StatelessWidget {
  const _ClassListSkeleton();

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.42).clamp(320.0, 460.0);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 280,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 36, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'Chưa có lớp học nào sắp dạy',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
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
      padding: const EdgeInsets.only(right: 16, top: 8),
      child: Text(
        'Không thể tải dữ liệu: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

// ─── Quick actions ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onCreateClass;
  final VoidCallback? onSchedule;

  const _QuickActions({required this.onCreateClass, this.onSchedule});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thao tác nhanh',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.add_circle_rounded,
                label: 'Tạo lớp học',
                color: cs.primary,
                onTap: onCreateClass,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.calendar_month_rounded,
                label: 'Lịch dạy',
                color: Colors.indigo,
                onTap: onSchedule ?? () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.people_rounded,
                label: 'Học viên',
                color: Colors.teal,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
