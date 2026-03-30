import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClassDetailInfoGrid extends StatelessWidget {
  final ClassSession session;

  const ClassDetailInfoGrid({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final hasLocationAddress =
        session.locationAddress != null &&
        session.locationAddress!.trim().isNotEmpty;

    final items = [
      if (session.classCode != null)
        _InfoItem(
          icon: Icons.qr_code_2_rounded,
          label: 'Mã lớp',
          value: session.classCode!,
          copyable: true,
        ),
      _InfoItem(
        icon: Icons.location_on_outlined,
        label: 'Địa điểm',
        value: session.location,
        supportingText: hasLocationAddress ? session.locationAddress! : null,
        valueMaxLines: 2,
        supportingTextMaxLines: 2,
      ),
      _InfoItem(
        icon: Icons.access_time_rounded,
        label: 'Thời gian',
        value: session.timeText,
      ),
      if (session.dateText != null)
        _InfoItem(
          icon: Icons.calendar_today_outlined,
          label: 'Ngày',
          value: session.dateText!,
        ),
      if (session.slotText != null)
        _InfoItem(
          icon: Icons.people_outline_rounded,
          label: 'Số lượng',
          value: session.slotText!,
        ),
      if (session.levelText != null)
        _InfoItem(
          icon: Icons.bar_chart_rounded,
          label: 'Trình độ',
          value: session.levelText!,
        ),
      _InfoItem(
        icon: Icons.payments_outlined,
        label: 'Phí',
        value: session.priceText,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 480 ? 3 : 2;
        final ratio = cols == 3 ? 2.25 : 1.9;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
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
  final String? supportingText;
  final int valueMaxLines;
  final int supportingTextMaxLines;
  final bool copyable;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.supportingText,
    this.valueMaxLines = 2,
    this.supportingTextMaxLines = 1,
    this.copyable = false,
  });
}

class _InfoCell extends StatelessWidget {
  final _InfoItem item;

  const _InfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (item.copyable)
                Icon(Icons.content_copy_rounded, size: 12, color: cs.primary),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            item.value,
            maxLines: item.valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
          if (item.supportingText != null) ...[
            const SizedBox(height: 2),
            Text(
              item.supportingText!,
              maxLines: item.supportingTextMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );

    if (!item.copyable) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: item.value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã copy mã lớp ${item.value}')),
        );
      },
      child: child,
    );
  }
}
