import 'package:client/core/widgets/app_tag_chip.dart';
import 'package:client/core/widgets/status_badge.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TutorClassCardWidget extends StatelessWidget {
  final ClassSession session;
  final VoidCallback? onTap;

  const TutorClassCardWidget({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    session.imageUrl != null && session.imageUrl!.isNotEmpty
                        ? Image.network(
                            session.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _PlaceholderThumb(cs: cs),
                          )
                        : _PlaceholderThumb(cs: cs),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: StatusBadge(label: session.statusText),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic
                    if (session.tags.isNotEmpty)
                      AppTagChip(label: session.tags.first),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Time row
                    _IconRow(
                      icon: Icons.schedule_rounded,
                      text: '${session.dateText ?? ''} · ${session.timeText}',
                      cs: cs,
                    ),
                    const SizedBox(height: 4),

                    // Location row
                    _IconRow(
                      icon: Icons.location_on_outlined,
                      text: session.location,
                      cs: cs,
                    ),
                    const SizedBox(height: 8),

                    // Bottom row: slot + class code
                    Row(
                      children: [
                        // Enrollment pill
                        _EnrollmentPill(
                          slotText: session.slotText,
                          countdownText: session.countdownText,
                          cs: cs,
                        ),
                        const Spacer(),

                        // Class code copy
                        if (session.classCode != null)
                          _ClassCodeCopy(
                            code: session.classCode!,
                            cs: cs,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _PlaceholderThumb extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderThumb({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: cs.onSurfaceVariant),
      ),
    );
  }
}


class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;

  const _IconRow({required this.icon, required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _EnrollmentPill extends StatelessWidget {
  final String? slotText;
  final String? countdownText;
  final ColorScheme cs;

  const _EnrollmentPill({
    required this.slotText,
    required this.countdownText,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final text = slotText ?? countdownText ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    // Highlight if full ("Hết chỗ")
    final isFull = countdownText?.contains('Hết') ?? false;
    final color = isFull ? cs.error : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassCodeCopy extends StatelessWidget {
  final String code;
  final ColorScheme cs;

  const _ClassCodeCopy({required this.code, required this.cs});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã copy mã lớp $code')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.content_copy_rounded, size: 12, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
