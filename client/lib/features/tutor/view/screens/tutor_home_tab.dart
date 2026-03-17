import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(tutorHomeViewModelProvider);
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

            // ── Income dashboard ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
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
                  actionText: 'Tất cả',
                  onActionTap: onScheduleTap,
                ),
              ),
            ),

            state.isLoading
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                      child: const _ClassListSkeleton(),
                    ),
                  )
                : state.error != null
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                          child: _ErrorBanner(message: state.error!),
                        ),
                      )
                    : state.upcomingClasses.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                              child: _EmptyClasses(
                                onCreateClass: () =>
                                    context.push(AppRoutes.teacherCreateClass),
                              ),
                            ),
                          )
                        : SliverList.separated(
                            itemCount: state.upcomingClasses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => Padding(
                              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                              child: TutorClassCardWidget(
                                session: state.upcomingClasses[i],
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
