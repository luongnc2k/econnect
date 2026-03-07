import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/view/screens/class_detail_screen.dart';
import 'package:client/features/student/view/widgets/category_filter_widget.dart';
import 'package:client/features/student/view/widgets/featured_teacher_list_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/student/view/widgets/search_bar_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:client/features/student/viewmodel/student_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentHomeScreen extends ConsumerWidget {
  final VoidCallback? onAvatarTap;

  const StudentHomeScreen({super.key, this.onAvatarTap});

  static const double _horizontalPadding = 16;
  static const double _sectionSpacing = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(studentHomeViewModelProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header — cuộn theo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                16,
                _horizontalPadding,
                0,
              ),
              child: HomeHeaderWidget(
                userName: user?.name ?? 'Bạn',
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
              categories: studentHomeCategories,
              selectedCategory: state.selectedCategory,
              onCategorySelected: (val) => ref
                  .read(studentHomeViewModelProvider.notifier)
                  .selectCategory(val),

            ),
          ),

          // Lớp học sắp diễn ra
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                0,
                _horizontalPadding,
                0,
              ),
              child: SectionHeaderWidget(
                title: 'Lớp học sắp diễn ra',
                actionText: 'Tất cả',
                onActionTap: () {},
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: _horizontalPadding),
              child: UpcomingClassListWidget(
                classes: state.classes,
                onClassTap: (session) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClassDetailScreen(session: session),
                  ),
                ),
              ),
            ),
          ),

          // Giảng viên nổi bật
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _horizontalPadding,
                _sectionSpacing,
                _horizontalPadding,
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
                    onTeacherTap: (teacher) {},
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

// height = top padding (12) + SearchBar (50) + gap (12) + CategoryFilter (36) + bottom padding (12)
const double _stickyHeight = 12 + 50 + 12 + 36 + 12;

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Color scaffoldColor;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _StickyFilterDelegate({
    required this.scaffoldColor,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchBarWidget(onTap: () {}),
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
      scaffoldColor != old.scaffoldColor;
}
