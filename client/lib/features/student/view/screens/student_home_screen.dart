import 'package:client/core/localization/app_language.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/search/view/widgets/search_bar_widget.dart';
import 'package:client/features/student/view/widgets/category_filter_widget.dart';
import 'package:client/features/student/view/widgets/featured_teacher_list_widget.dart';
import 'package:client/features/student/view/widgets/home_header_widget.dart';
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

  String _greeting(AppStrings strings) {
    final hour = DateTime.now().hour;
    if (hour < 12) return strings.morningGreeting;
    if (hour < 18) return strings.afternoonGreeting;
    return strings.eveningGreeting;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(studentHomeViewModelProvider);
    final strings = ref.watch(appStringsProvider);
    final hPad = responsiveHPad(context);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
              child: HomeHeaderWidget(
                greeting: _greeting(strings),
                userName: user?.fullName ?? strings.defaultStudentName,
                avatarUrl: user?.avatarUrl,
                onAvatarTap: onAvatarTap,
                onNotificationTap: () => context.push(AppRoutes.notifications),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyFilterDelegate(
              scaffoldColor: Theme.of(context).scaffoldBackgroundColor,
              horizontalPadding: hPad,
              categories: state.categories,
              selectedCategory: state.selectedCategory,
              allCategoryLabel: strings.all,
              searchHint: strings.searchUsersOrClassCode,
              onSearchTap: onSearchTap,
              onCategorySelected: (value) => ref
                  .read(studentHomeViewModelProvider.notifier)
                  .selectCategory(value),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
              child: SectionHeaderWidget(
                title: strings.upcomingClassList,
                actionText: strings.all,
                onActionTap: onClassesTap,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
              child: state.isLoading
                  ? const _ClassListSkeleton()
                  : state.error != null
                  ? _ErrorBanner(message: strings.loadDataError(state.error!))
                  : state.classes.isEmpty
                  ? _EmptyClasses(message: strings.noUpcomingClasses)
                  : UpcomingClassListWidget(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      classes: state.classes,
                      onClassTap: (session) =>
                          context.go(AppRoutes.classDetail, extra: session),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, _sectionSpacing, hPad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeaderWidget(
                    title: strings.featuredTeachers,
                    actionText: strings.seeMore,
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
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 174,
          margin: const EdgeInsets.only(bottom: 12),
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
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  final String message;

  const _EmptyClasses({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message),
    );
  }
}

const double _stickyHeight = 12 + 50 + 12 + 36 + 12;

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Color scaffoldColor;
  final double horizontalPadding;
  final List<String> categories;
  final String selectedCategory;
  final String allCategoryLabel;
  final String searchHint;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback? onSearchTap;

  const _StickyFilterDelegate({
    required this.scaffoldColor,
    required this.horizontalPadding,
    required this.categories,
    required this.selectedCategory,
    required this.allCategoryLabel,
    required this.searchHint,
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
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchBarWidget(
              onTap: onSearchTap,
              readOnly: true,
              hintText: searchHint,
            ),
            const SizedBox(height: 12),
            CategoryFilterWidget(
              categories: categories,
              selectedCategory: selectedCategory,
              labelBuilder: (category) =>
                  categories.isNotEmpty && category == categories.first
                  ? allCategoryLabel
                  : category,
              onCategorySelected: onCategorySelected,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyFilterDelegate old) =>
      categories.length != old.categories.length ||
      !_sameCategories(categories, old.categories) ||
      selectedCategory != old.selectedCategory ||
      allCategoryLabel != old.allCategoryLabel ||
      searchHint != old.searchHint ||
      scaffoldColor != old.scaffoldColor ||
      horizontalPadding != old.horizontalPadding;

  bool _sameCategories(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
