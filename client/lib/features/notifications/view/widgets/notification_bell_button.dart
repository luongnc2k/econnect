import 'package:flutter/material.dart';

class NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onPressed;
  final IconData icon;

  const NotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    this.icon = Icons.notifications_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';

    return IconButton(
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (hasUnread)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    badgeText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
