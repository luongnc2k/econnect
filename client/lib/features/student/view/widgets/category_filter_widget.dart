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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  _FilterChip(
                    label: categories[i],
                    isSelected: categories[i] == selectedCategory,
                    onTap: () => onCategorySelected?.call(categories[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
        child: Text(
          label,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.0,
            color: isSelected ? Pallete.whiteColor : Pallete.textPrimary,
          ),
        ),
      ),
    );
  }
}
