import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';

class ClassDetailLocationCard extends StatelessWidget {
  final ClassSession session;

  const ClassDetailLocationCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final hasAddress =
        session.locationAddress != null &&
        session.locationAddress!.trim().isNotEmpty;
    final hasNotes =
        session.locationNotes != null &&
        session.locationNotes!.trim().isNotEmpty;

    if (!hasAddress && !hasNotes) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Địa điểm học', style: titleStyle),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.storefront_outlined,
            label: 'Tên địa điểm',
            value: session.location,
          ),
          if (hasAddress) ...[
            const SizedBox(height: 10),
            _LocationRow(
              icon: Icons.place_outlined,
              label: 'Địa chỉ',
              value: session.locationAddress!,
            ),
          ],
          if (hasNotes) ...[
            const SizedBox(height: 10),
            _LocationRow(
              icon: Icons.info_outline_rounded,
              label: 'Ghi chú',
              value: session.locationNotes!,
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
