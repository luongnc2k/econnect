import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/core/widgets/app_tag_chip.dart';
import 'package:client/core/widgets/status_badge.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/class_detail_enrolled_avatars.dart';
import 'package:client/features/student/view/widgets/class_detail_info_grid.dart';
import 'package:client/features/student/view/widgets/class_detail_teacher_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassDetailScreen extends StatelessWidget {
  final ClassSession session;

  const ClassDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = responsiveHPad(context);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Đăng ký tham gia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: EdgeInsets.fromLTRB(hPad - 8, 8, hPad, 0),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.chevron_left, color: cs.primary),
                  label: Text(
                    'Quay lại',
                    style: TextStyle(color: cs.primary, fontSize: 16),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ),

              // Hero image
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                child: _HeroCard(
                  imageUrl: session.imageUrl,
                  statusText: session.statusText,
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags
                    if (session.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: session.tags
                            .map((t) => AppTagChip(
                                  label: t,
                                  fontSize: 13,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Title
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),

                    // Description
                    if (session.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ClassDetailInfoGrid(session: session),

                    const SizedBox(height: 24),

                    Text(
                      'Giảng viên',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClassDetailTeacherCard(
                      name: session.teacherName,
                      avatarUrl: session.teacherAvatarUrl,
                      rating: session.teacherRating,
                      sessionCount: session.teacherSessionCount,
                      onTap: session.teacherId == null
                          ? null
                          : () => context.push(
                                AppRoutes.userProfile.replaceFirst(
                                  ':userId',
                                  session.teacherId!,
                                ),
                              ),
                    ),

                    if (session.enrolledInitials.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Học viên đã đăng ký (${session.slotText?.split(' ').first ?? ''})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClassDetailEnrolledAvatars(
                        students: session.enrolledStudents,
                        initials: session.enrolledInitials,
                        extra: session.extraEnrolled ?? 0,
                        onAvatarTap: (student) => context.push(
                          AppRoutes.userProfile.replaceFirst(
                            ':userId',
                            student.id,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String? imageUrl;
  final String statusText;

  const _HeroCard({this.imageUrl, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _GradientPlaceholder(),
                  )
                : const _GradientPlaceholder(),
            Positioned(
              top: 12,
              left: 12,
              child: StatusBadge(label: statusText),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B5BDB), Color(0xFF5C7CFA)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 56, color: Colors.white54),
      ),
    );
  }
}

