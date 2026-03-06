import 'package:client/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';

class TeacherCardWidget extends StatelessWidget {
  final String name;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final List<String> specialties;
  final String? avatarUrl;
  final String? badgeText;
  final VoidCallback? onTap;

  const TeacherCardWidget({
    super.key,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.reviewCount,
    required this.specialties,
    this.avatarUrl,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Pallete.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeacherAvatar(avatarUrl: avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Pallete.textPrimary,
                          ),
                        ),
                      ),
                      if (badgeText != null && badgeText!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _BadgeChip(label: badgeText!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Pallete.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Pallete.accentAmber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Pallete.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($reviewCount đánh giá)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Pallete.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (specialties.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: specialties
                          .map((item) => _SpecialtyChip(label: item))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _TeacherAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Pallete.surfaceMuted,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? Image.network(avatarUrl!, fit: BoxFit.cover)
          : const Icon(Icons.person, size: 28, color: Pallete.textMuted),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;

  const _BadgeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Pallete.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Pallete.whiteColor,
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final String label;

  const _SpecialtyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Pallete.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Pallete.textEmphasis,
        ),
      ),
    );
  }
}
