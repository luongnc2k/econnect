import 'package:client/core/theme/app_pallete.dart';
import 'package:flutter/material.dart';

class HomeHeaderWidget extends StatelessWidget {
  final String greeting;
  final String userName;
  final String? avatarUrl;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  const HomeHeaderWidget({
    super.key,
    this.greeting = 'Chào buổi sáng,',
    required this.userName,
    this.avatarUrl,
    this.onNotificationTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Pallete.surfaceMuted,
            backgroundImage:
                avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
            child:
                avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        color: Pallete.iconMedium,
                        size: 24,
                      )
                    : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Pallete.accentOrange,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Pallete.whiteColor,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotificationTap,
          icon: const Icon(Icons.notifications_rounded),
          splashRadius: 22,
        ),
      ],
    );
  }
}
