import 'package:client/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';

class CategoryFilterWidget extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const CategoryFilterWidget({
    super.key,
    required this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 0),
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return InkWell(
            onTap: () => onCategorySelected?.call(category),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Pallete.chipSelectedBg : Pallete.chipUnselectedBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? Pallete.chipSelectedBg : Pallete.borderFilter,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Pallete.whiteColor : Pallete.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
