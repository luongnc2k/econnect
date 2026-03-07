import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';

class ClassDetailInfoGrid extends StatelessWidget {
  final ClassSession session;

  const ClassDetailInfoGrid({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoItem(icon: Icons.location_on_outlined, label: 'Địa điểm', value: session.location),
      _InfoItem(icon: Icons.access_time_rounded, label: 'Thời gian', value: session.timeText),
      if (session.dateText != null)
        _InfoItem(icon: Icons.calendar_today_outlined, label: 'Ngày', value: session.dateText!),
      if (session.slotText != null)
        _InfoItem(icon: Icons.people_outline_rounded, label: 'Số lượng', value: session.slotText!),
      if (session.levelText != null)
        _InfoItem(icon: Icons.bar_chart_rounded, label: 'Trình độ', value: session.levelText!),
      _InfoItem(icon: Icons.payments_outlined, label: 'Phí', value: session.priceText),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 480 ? 3 : 2;
        final ratio = cols == 3 ? 2.2 : 1.9;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _InfoCell(item: items[i]),
        );
      },
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({required this.icon, required this.label, required this.value});
}

class _InfoCell extends StatelessWidget {
  final _InfoItem item;

  const _InfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
