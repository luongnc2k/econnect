import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/student/view/widgets/category_filter_widget.dart';
import 'package:client/features/student/view/widgets/featured_teacher_list_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
import 'package:client/features/student/view/widgets/search_bar_widget.dart';
import 'package:client/features/student/view/widgets/section_header_widget.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _categories = ['Gần bạn', 'Hôm nay', 'Giao tiếp', 'IELTS', 'Cơ bản'];

// TODO: Replace with real data from repository
const _mockClasses = [
  ClassSession(
    title: 'Luyện nói Business English',
    location: 'HighLand Coffee Cầu Giấy',
    teacherName: 'Alexander Ng',
    timeText: '18:30 Hôm nay',
    priceText: '120.000đ',
    statusText: 'OPEN',
    countdownText: 'Còn 3 chỗ',
    tags: ['Kinh doanh', 'Lối sống'],
  ),
  ClassSession(
    title: 'Luyện nói Business English',
    location: 'HighLand Coffee Cầu Giấy',
    teacherName: 'Alexander Ng',
    timeText: '18:30 Hôm nay',
    priceText: '120.000đ',
    statusText: 'OPEN',
    countdownText: 'Còn 3 chỗ',
    tags: ['Kinh doanh', 'Lối sống'],
  ),
];

const _mockTeachers = [
  TeacherPreview(
    name: 'James Wilson',
    subtitle: 'Giảng viên giao tiếp và phát âm',
    rating: 4.9,
    reviewCount: 128,
    specialties: ['Pronunciation', 'Business English', 'IELTS'],
    badgeText: 'Expert',
  ),
  TeacherPreview(
    name: 'Anna Lee',
    subtitle: 'Chuyên luyện phản xạ giao tiếp cho người đi làm',
    rating: 4.8,
    reviewCount: 96,
    specialties: ['Speaking', 'Communication'],
    badgeText: 'Top Rated',
  ),
];

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  static const double _horizontalPadding = 16;
  static const double _sectionSpacing = 16;

  String _selectedCategory = _categories.first;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

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
                  onAvatarTap: () {},
                  onNotificationTap: () {},
                ),
              ),
            ),

            // Search + Category — sticky
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyFilterDelegate(
                scaffoldColor: Theme.of(context).scaffoldBackgroundColor,
                categories: _categories,
                selectedCategory: _selectedCategory,
                onCategorySelected: (val) =>
                    setState(() => _selectedCategory = val),
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
                  classes: _mockClasses,
                  onClassTap: (session) {},
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
                      teachers: _mockTeachers,
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

// height = top padding (12) + SearchBar (44) + gap (12) + CategoryFilter (36) + bottom padding (12)
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
