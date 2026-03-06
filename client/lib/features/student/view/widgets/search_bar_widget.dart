import 'package:client/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final bool readOnly;

  const SearchBarWidget({
    super.key,
    this.controller,
    this.hintText = 'Tìm kiếm lớp học, giảng viên...',
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Pallete.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Pallete.textMuted),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            size: 20,
            color: Pallete.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              style: const TextStyle(
                fontSize: 14,
                color: Pallete.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Pallete.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (onFilterTap != null) ...[
            Container(
              width: 1,
              height: 20,
              color: Pallete.borderFilter,
            ),
            IconButton(
              onPressed: onFilterTap,
              icon: const Icon(Icons.tune_rounded),
              color: Pallete.iconMedium,
            ),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
