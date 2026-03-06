import 'package:client/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';

class ClassCardWidget extends StatelessWidget {
  final String title;
  final String location;
  final String teacherName;
  final String timeText;
  final String priceText;
  final String? imageUrl;
  final String statusText;
  final String? countdownText;
  final List<String> tags;
  final VoidCallback? onTap;

  const ClassCardWidget({
    super.key,
    required this.title,
    required this.location,
    required this.teacherName,
    required this.timeText,
    required this.priceText,
    this.imageUrl,
    this.statusText = 'OPEN',
    this.countdownText,
    this.tags = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Pallete.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pallete.borderStrong, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) => _TagChip(label: tag)).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Pallete.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Pallete.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 16,
                        color: Pallete.iconMedium,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          teacherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Pallete.textEmphasis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InfoColumn(label: 'Thời gian', value: timeText),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoColumn(label: 'Phí tham gia', value: priceText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 150,
        width: double.infinity,
        color: Pallete.surfaceMuted,
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const _PlaceholderImage(),
                    )
                  : const _PlaceholderImage(),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _StatusBadge(label: statusText),
            ),
            if (countdownText != null && countdownText!.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: _OutlineBadge(label: countdownText!),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Pallete.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Pallete.textPrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Pallete.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pallete.borderStrong),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Pallete.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Pallete.accentGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Pallete.whiteColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _OutlineBadge extends StatelessWidget {
  final String label;

  const _OutlineBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Pallete.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Pallete.borderStrong),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Pallete.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_outlined, size: 56, color: Pallete.textMuted),
    );
  }
}
