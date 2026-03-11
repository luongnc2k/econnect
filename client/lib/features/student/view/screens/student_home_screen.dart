import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/student/view/widgets/category_filter_widget.dart';
import 'package:client/features/student/view/widgets/featured_teacher_list_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/search/view/widgets/search_bar_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:client/features/student/viewmodel/student_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StudentHomeScreen extends ConsumerWidget {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onClassesTap;

  const StudentHomeScreen({
    super.key,
    this.onAvatarTap,
    this.onSearchTap,
    this.onClassesTap,
  });

  static const double _sectionSpacing = 16;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng,';
    if (hour < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(studentHomeViewModelProvider);
    final hPad = responsiveHPad(context);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header — cuộn theo
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
              child: HomeHeaderWidget(
                greeting: _greeting(),
                userName: user?.fullName ?? 'Bạn',
                avatarUrl: user?.avatarUrl,
                onAvatarTap: onAvatarTap,
                onNotificationTap: () {},
              ),
            ),
          ),

          // Search + Category — sticky
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyFilterDelegate(
              scaffoldColor: Theme.of(context).scaffoldBackgroundColor,
              horizontalPadding: hPad,
              categories: studentHomeCategories,
              selectedCategory: state.selectedCategory,
              onSearchTap: onSearchTap,
              onCategorySelected: (val) => ref
                  .read(studentHomeViewModelProvider.notifier)
                  .selectCategory(val),
            ),
          ),

          // Lớp học sắp diễn ra
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                0,
                hPad,
                0,
              ),
              child: SectionHeaderWidget(
                title: 'Lớp học sắp diễn ra',
                actionText: 'Tất cả',
                onActionTap: onClassesTap,
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
                      : state.classes.isEmpty
                          ? const _EmptyClasses()
                          : UpcomingClassListWidget(
                              classes: state.classes,
                              onClassTap: (session) => context.go(
                                AppRoutes.classDetail,
                                extra: session,
                              ),
                            ),
            ),
          ),

          // Giảng viên nổi bật
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hPad,
                _sectionSpacing,
                hPad,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeaderWidget(
                    title: 'Giảng viên nổi bật',
                    actionText: 'Xem thêm',
                    onActionTap: () {},
                  ),
                  const SizedBox(height: 12),
                  FeaturedTeacherListWidget(
                    teachers: state.teachers,
                    onTeacherTap: (teacher) => context.push(
                      AppRoutes.userProfile.replaceFirst(':userId', teacher.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, _) => Container(
          width: 240,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.only(right: 16, top: 8),
      child: Text(
        'Không thể tải dữ liệu: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  const _EmptyClasses();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text('Chưa có lớp học sắp diễn ra.'),
    );
  }
}

// height = top padding (12) + SearchBar (50) + gap (12) + CategoryFilter (36) + bottom padding (12)
const double _stickyHeight = 12 + 50 + 12 + 36 + 12;

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Color scaffoldColor;
  final double horizontalPadding;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback? onSearchTap;

  const _StickyFilterDelegate({
    required this.scaffoldColor,
    required this.horizontalPadding,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.onSearchTap,
  });

  @override
  double get minExtent => _stickyHeight;

  @override
  double get maxExtent => _stickyHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: scaffoldColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchBarWidget(
              onTap: onSearchTap,
              readOnly: true,
              hintText: 'Tim user theo ten hoac so dien thoai',
            ),
            const SizedBox(height: 12),
            CategoryFilterWidget(
              categories: categories,
              selectedCategory: selectedCategory,
              onCategorySelected: onCategorySelected,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyFilterDelegate old) =>
      selectedCategory != old.selectedCategory ||
      scaffoldColor != old.scaffoldColor ||
      horizontalPadding != old.horizontalPadding;
}
