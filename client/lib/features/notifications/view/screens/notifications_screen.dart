import 'package:client/core/failure/failure.dart';
import 'package:client/core/localization/app_language.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/notifications/model/app_notification.dart';
import 'package:client/features/notifications/model/notifications_state.dart';
import 'package:client/features/notifications/viewmodel/notifications_controller.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _filters = [
    _NotificationOption(
      NotificationFilterKeys.all,
      'All',
      'Tất cả',
      Icons.inbox_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.unread,
      'Unread',
      'Chưa đọc',
      Icons.markunread_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.minimumReached,
      'Minimum reached',
      'Đủ tối thiểu',
      Icons.groups_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.tutorConfirmed,
      'Tutor confirmed',
      'Tutor xác nhận',
      Icons.verified_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.classStartingSoon,
      'Starting soon',
      'Sắp diễn ra',
      Icons.schedule_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.classCancelled,
      'Class cancelled',
      'Lớp bị hủy',
      Icons.event_busy_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.refundIssued,
      'Refund',
      'Hoàn tiền',
      Icons.replay_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.payoutUpdated,
      'Payout',
      'Payout',
      Icons.payments_rounded,
    ),
    _NotificationOption(
      NotificationFilterKeys.disputeResolved,
      'Dispute',
      'Khiếu nại',
      Icons.gavel_rounded,
    ),
  ];

  static const _groupings = [
    _NotificationOption(
      NotificationGroupingModes.byDate,
      'By date',
      'Theo ngày',
      Icons.calendar_today_rounded,
    ),
    _NotificationOption(
      NotificationGroupingModes.byType,
      'By type',
      'Theo loại',
      Icons.category_rounded,
    ),
  ];

  Future<void> _handleNotificationTap(
    WidgetRef ref,
    AppNotification notification,
  ) async {
    await ref
        .read(notificationsControllerProvider.notifier)
        .markAsRead(notification);
  }

  Future<void> _handleConfirmTeaching(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final result = await ref
        .read(notificationsControllerProvider.notifier)
        .confirmTeaching(notification);
    if (!context.mounted) {
      return;
    }

    if (result is Left<AppFailure, String>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.value.message)));
      return;
    }

    if (result is Right<AppFailure, String>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.value)));
    }
  }

  Future<void> _openLinkedClass(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final user = ref.read(currentUserProvider);
    final classCode = notification.classCode;
    if (user == null || classCode == null || classCode.isEmpty) {
      return;
    }

    await ref
        .read(notificationsControllerProvider.notifier)
        .markAsRead(notification);

    if (user.role == 'teacher') {
      if (!context.mounted) {
        return;
      }
      context.push('/teacher/class-summary/$classCode');
      return;
    }

    if (user.role != 'student') {
      return;
    }

    final result = await ref
        .read(studentRemoteRepositoryProvider)
        .getClassByCode(user.token, classCode, includePast: true);

    if (!context.mounted) {
      return;
    }

    if (result is Left<AppFailure, ClassSession>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.value.message)));
      return;
    }

    if (result is Right<AppFailure, ClassSession>) {
      context.push(AppRoutes.classDetail, extra: result.value);
    }
  }

  String _optionLabel(
    List<_NotificationOption> options,
    String key,
    AppStrings strings,
  ) {
    for (final option in options) {
      if (option.key == key) {
        return option.label(strings);
      }
    }
    return key;
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

    final local = dateTime.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$minute';
  }

  String _formatRelativeTime(DateTime? dateTime, AppStrings strings) {
    if (dateTime == null) {
      return '';
    }

    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.inMinutes < 1) {
      return strings.text(en: 'Just now', vi: 'Vừa xong');
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return strings.text(
        en: minutes == 1 ? '1 minute ago' : '$minutes minutes ago',
        vi: '$minutes phút trước',
      );
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return strings.text(
        en: hours == 1 ? '1 hour ago' : '$hours hours ago',
        vi: '$hours giờ trước',
      );
    }
    if (difference.inDays == 1) {
      return strings.text(en: 'Yesterday', vi: 'Hôm qua');
    }
    return _formatDate(dateTime);
  }

  String _groupLabel(DateTime? dateTime, AppStrings strings) {
    if (dateTime == null) {
      return strings.text(en: 'Other', vi: 'Khác');
    }

    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return strings.text(en: 'Today', vi: 'Hôm nay');
    }
    if (difference == 1) {
      return strings.text(en: 'Yesterday', vi: 'Hôm qua');
    }
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  Map<String, List<AppNotification>> _groupNotifications(
    List<AppNotification> notifications,
    String groupingMode,
    AppStrings strings,
  ) {
    final grouped = <String, List<AppNotification>>{};
    for (final notification in notifications) {
      final label = groupingMode == NotificationGroupingModes.byType
          ? _notificationTypeLabel(notification, strings)
          : _groupLabel(notification.createdAt, strings);
      grouped.putIfAbsent(label, () => <AppNotification>[]).add(notification);
    }
    return grouped;
  }

  String _notificationTypeLabel(
    AppNotification notification,
    AppStrings strings,
  ) {
    switch (notification.type) {
      case NotificationFilterKeys.minimumReached:
        return strings.text(en: 'Minimum reached', vi: 'Đủ tối thiểu');
      case NotificationFilterKeys.tutorConfirmed:
        return strings.text(en: 'Tutor confirmed', vi: 'Tutor xác nhận');
      case NotificationFilterKeys.classStartingSoon:
        return strings.text(en: 'Starting soon', vi: 'Sắp diễn ra');
      case NotificationFilterKeys.classCancelled:
        return strings.text(en: 'Class cancelled', vi: 'Lớp bị hủy');
      case NotificationFilterKeys.refundIssued:
        return notification.refundScope == 'class_creation_fee'
            ? strings.text(en: 'Creation fee refund', vi: 'Hoàn phí tạo lớp')
            : strings.text(en: 'Refund', vi: 'Hoàn tiền');
      case NotificationFilterKeys.payoutUpdated:
        return 'Payout';
      case NotificationFilterKeys.disputeResolved:
        return strings.text(en: 'Dispute', vi: 'Khiếu nại');
      default:
        return notification.type;
    }
  }

  String _notificationTitle(AppNotification notification, AppStrings strings) {
    return switch (notification.type) {
      NotificationFilterKeys.minimumReached => strings.text(
        en: 'Class reached the minimum number of students',
        vi: 'Lớp đã đủ số học viên tối thiểu',
      ),
      NotificationFilterKeys.tutorConfirmed => strings.text(
        en: 'Tutor confirmed teaching',
        vi: 'Tutor đã xác nhận dạy',
      ),
      NotificationFilterKeys.classStartingSoon => strings.text(
        en: 'Class starts within 1 hour',
        vi: 'Lớp học sắp diễn ra trong 1 giờ',
      ),
      NotificationFilterKeys.classCancelled => strings.text(
        en: 'Class cancelled',
        vi: 'Lớp học đã bị hủy',
      ),
      NotificationFilterKeys.refundIssued =>
        notification.refundScope == 'class_creation_fee'
            ? strings.text(
                en: 'Class creation fee refund updated',
                vi: 'Cập nhật hoàn phí tạo lớp',
              )
            : strings.text(
                en: 'Tuition refund updated',
                vi: 'Cập nhật hoàn tiền học phí',
              ),
      NotificationFilterKeys.payoutUpdated => strings.text(
        en: 'Payout status updated',
        vi: 'Trạng thái payout đã thay đổi',
      ),
      NotificationFilterKeys.disputeResolved => strings.text(
        en: 'Dispute resolved',
        vi: 'Khiếu nại đã được xử lý',
      ),
      _ => notification.title,
    };
  }

  String _notificationBody(AppNotification notification, AppStrings strings) {
    final classTitle = notification.data['class_title']?.toString().trim();
    final classSegment = classTitle == null || classTitle.isEmpty
        ? strings.text(en: 'this class', vi: 'lớp này')
        : "'$classTitle'";
    final reason =
        notification.data['refund_reason']?.toString().trim().isNotEmpty == true
        ? notification.data['refund_reason'].toString().trim()
        : notification.cancellationReason?.trim();
    final amount =
        notification.refundAmount ??
        notification.data['payout_amount']?.toString() ??
        '';

    return switch (notification.type) {
      NotificationFilterKeys.minimumReached => strings.text(
        en: 'Class $classSegment has reached the minimum student threshold. Confirm teaching so students can be notified.',
        vi: 'Lớp $classSegment đã đạt ngưỡng học viên tối thiểu. Hãy xác nhận dạy để hệ thống thông báo buổi học sẽ diễn ra.',
      ),
      NotificationFilterKeys.tutorConfirmed => strings.text(
        en: 'The tutor confirmed teaching class $classSegment. The class will take place as planned.',
        vi: 'Tutor đã xác nhận dạy lớp $classSegment. Buổi học sẽ được diễn ra như kế hoạch.',
      ),
      NotificationFilterKeys.classStartingSoon => strings.text(
        en: 'Class $classSegment will start in about 1 hour. Please get ready.',
        vi: 'Lớp $classSegment sắp bắt đầu trong khoảng 1 giờ nữa. Hãy chuẩn bị cho buổi học.',
      ),
      NotificationFilterKeys.classCancelled => strings.text(
        en: 'Class $classSegment was cancelled.${reason == null || reason.isEmpty ? '' : ' Reason: $reason.'}',
        vi: 'Lớp $classSegment đã bị hủy.${reason == null || reason.isEmpty ? '' : ' Lý do: $reason.'}',
      ),
      NotificationFilterKeys.refundIssued =>
        notification.refundScope == 'class_creation_fee'
            ? strings.text(
                en: 'The system updated the class creation fee refund${amount.isEmpty ? '' : ' of $amount'} for class $classSegment.',
                vi: 'Hệ thống đã cập nhật hoàn phí tạo lớp${amount.isEmpty ? '' : ' $amount'} cho lớp $classSegment.',
              )
            : strings.text(
                en: 'The system updated the tuition refund${amount.isEmpty ? '' : ' of $amount'} for class $classSegment.',
                vi: 'Hệ thống đã cập nhật hoàn tiền học phí${amount.isEmpty ? '' : ' $amount'} cho lớp $classSegment.',
              ),
      NotificationFilterKeys.payoutUpdated => strings.text(
        en: 'Payout status for class $classSegment has been updated${amount.isEmpty ? '' : ' with amount $amount'}.',
        vi: 'Trạng thái payout của lớp $classSegment đã được cập nhật${amount.isEmpty ? '' : ' với số tiền $amount'}.',
      ),
      NotificationFilterKeys.disputeResolved => strings.text(
        en: 'The dispute for class $classSegment has been resolved.',
        vi: 'Khiếu nại của lớp $classSegment đã được xử lý.',
      ),
      _ => notification.body,
    };
  }

  Future<void> _showControlsSheet(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
  ) async {
    final controller = ref.read(notificationsControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final strings = AppStrings(
          Localizations.localeOf(sheetContext).languageCode,
        );

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            shrinkWrap: true,
            children: [
              Text(
                strings.text(en: 'Inbox controls', vi: 'Tùy chỉnh hộp thư'),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                strings.text(
                  en: 'Choose filters and grouping to scan notifications faster.',
                  vi: 'Chọn bộ lọc và cách nhóm để quét thông báo nhanh hơn.',
                ),
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Text(
                strings.text(en: 'Filters', vi: 'Bộ lọc'),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ..._filters.map(
                (filter) => _ControlTile(
                  label: filter.label(strings),
                  icon: filter.icon,
                  selected: state.selectedFilterKey == filter.key,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await controller.setFilter(filter.key);
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                strings.text(en: 'Group list', vi: 'Nhóm danh sách'),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _groupings.map((grouping) {
                  return ChoiceChip(
                    avatar: Icon(
                      grouping.icon,
                      size: 18,
                      color: state.groupingMode == grouping.key
                          ? cs.onPrimary
                          : cs.onSurfaceVariant,
                    ),
                    label: Text(grouping.label(strings)),
                    selected: state.groupingMode == grouping.key,
                    onSelected: (_) => controller.setGroupingMode(grouping.key),
                  );
                }).toList(),
              ),
              if (state.selectedFilterKey != NotificationFilterKeys.all) ...[
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await controller.setFilter(NotificationFilterKeys.all);
                  },
                  icon: const Icon(Icons.clear_rounded),
                  label: Text(
                    strings.text(
                      en: 'Clear current filter',
                      vi: 'Bỏ lọc hiện tại',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
  ) async {
    if (state.isDeletingAll) {
      return;
    }
    final strings = ref.read(appStringsProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(
            strings.text(
              en: 'Delete all notifications?',
              vi: 'Xóa tất cả thông báo?',
            ),
          ),
          content: Text(
            strings.text(
              en: 'All notifications in your inbox will be deleted.',
              vi: 'Toàn bộ thông báo trong hộp thư của bạn sẽ bị xóa.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.text(en: 'Cancel', vi: 'Hủy')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: Text(strings.text(en: 'Delete all', vi: 'Xóa tất cả')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final failure = await ref
        .read(notificationsControllerProvider.notifier)
        .deleteAllNotifications();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure?.message ??
              strings.text(
                en: 'All notifications deleted.',
                vi: 'Đã xóa tất cả thông báo.',
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(notificationsControllerProvider);
    final strings = ref.watch(appStringsProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final groupedNotifications = _groupNotifications(
      state.notifications,
      state.groupingMode,
      strings,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text(en: 'Notifications', vi: 'Thông báo')),
        actions: [
          IconButton(
            onPressed: () => controller.refresh(),
            tooltip: strings.text(en: 'Refresh', vi: 'Làm mới'),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: state.isDeletingAll
                ? null
                : () => _confirmDeleteAll(context, ref, state),
            tooltip: strings.text(
              en: 'Delete all notifications',
              vi: 'Xóa tất cả thông báo',
            ),
            icon: state.isDeletingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_rounded),
          ),
          IconButton(
            onPressed: () => _showControlsSheet(context, ref, state),
            tooltip: strings.text(
              en: 'Filters and grouping',
              vi: 'Bộ lọc và nhóm',
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _InboxSummaryCard(
                unreadCount: state.unreadCount,
                activeFilterLabel: _optionLabel(
                  _filters,
                  state.selectedFilterKey,
                  strings,
                ),
                groupingLabel: _optionLabel(
                  _groupings,
                  state.groupingMode,
                  strings,
                ),
                hydratedFromCache: state.hydratedFromCache,
                liveConnected: state.liveConnected,
                hasActiveFilter:
                    state.selectedFilterKey != NotificationFilterKeys.all,
                onClearFilter:
                    state.selectedFilterKey == NotificationFilterKeys.all
                    ? null
                    : () => controller.setFilter(NotificationFilterKeys.all),
                onOpenControls: () => _showControlsSheet(context, ref, state),
              ),
              if (state.error != null && state.notifications.isNotEmpty) ...[
                const SizedBox(height: 12),
                _InlineMessage(
                  icon: Icons.error_outline_rounded,
                  message: state.error!,
                  error: true,
                ),
              ],
              if (state.isLoading && state.notifications.isEmpty) ...[
                const SizedBox(height: 56),
                const Center(child: CircularProgressIndicator()),
              ] else if (state.error != null &&
                  state.notifications.isEmpty) ...[
                const SizedBox(height: 56),
                _EmptyState(
                  message: state.error!,
                  actionLabel: strings.text(en: 'Try again', vi: 'Thử tải lại'),
                  onPressed: controller.refresh,
                ),
              ] else if (state.notifications.isEmpty) ...[
                const SizedBox(height: 56),
                _EmptyState(
                  message: strings.text(
                    en: 'No notifications for the current filter.',
                    vi: 'Chưa có thông báo nào cho bộ lọc hiện tại.',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                for (final entry in groupedNotifications.entries) ...[
                  _SectionHeader(label: entry.key, count: entry.value.length),
                  const SizedBox(height: 10),
                  for (final notification in entry.value) ...[
                    _NotificationCard(
                      notification: notification,
                      typeLabel: _notificationTypeLabel(notification, strings),
                      displayTitle: _notificationTitle(notification, strings),
                      displayBody: _notificationBody(notification, strings),
                      createdAt: _formatRelativeTime(
                        notification.createdAt,
                        strings,
                      ),
                      classStartAt: _formatDate(notification.classStartTime),
                      canConfirmTeaching:
                          user?.role == 'teacher' &&
                          notification.canConfirmTeaching &&
                          !controller.isClassConfirmedLocally(
                            notification.classId,
                          ),
                      canOpenClassDetail:
                          (user?.role == 'student' ||
                              user?.role == 'teacher') &&
                          (notification.classCode?.isNotEmpty ?? false),
                      openClassLabel: user?.role == 'teacher'
                          ? strings.text(
                              en: 'Open class details',
                              vi: 'Mở chi tiết lớp',
                            )
                          : strings.text(en: 'Open class', vi: 'Mở lớp học'),
                      isBusy: state.actionNotificationId == notification.id,
                      onTap: () => _handleNotificationTap(ref, notification),
                      onConfirmTeaching: () =>
                          _handleConfirmTeaching(context, ref, notification),
                      onOpenClassDetail: () =>
                          _openLinkedClass(context, ref, notification),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (state.isLoadingMore) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ] else if (state.hasMore) ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: controller.loadMore,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(strings.text(en: 'Load more', vi: 'Tải thêm')),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationOption {
  final String key;
  final String enLabel;
  final String viLabel;
  final IconData icon;

  const _NotificationOption(this.key, this.enLabel, this.viLabel, this.icon);

  String label(AppStrings strings) => strings.text(en: enLabel, vi: viLabel);
}

class _InboxSummaryCard extends StatelessWidget {
  final int unreadCount;
  final String activeFilterLabel;
  final String groupingLabel;
  final bool hydratedFromCache;
  final bool liveConnected;
  final bool hasActiveFilter;
  final VoidCallback? onClearFilter;
  final VoidCallback onOpenControls;

  const _InboxSummaryCard({
    required this.unreadCount,
    required this.activeFilterLabel,
    required this.groupingLabel,
    required this.hydratedFromCache,
    required this.liveConnected,
    required this.hasActiveFilter,
    required this.onClearFilter,
    required this.onOpenControls,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text(en: 'Your inbox', vi: 'Hộp thư của bạn'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.text(
                        en: unreadCount == 1
                            ? '1 unread notification'
                            : '$unreadCount unread notifications',
                        vi: '$unreadCount thông báo chưa đọc',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenControls,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                ),
                icon: const Icon(Icons.tune_rounded),
                label: Text(strings.text(en: 'Customize', vi: 'Tùy chỉnh')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryTag(
                label: strings.text(
                  en: 'Filter: $activeFilterLabel',
                  vi: 'Lọc: $activeFilterLabel',
                ),
                icon: Icons.filter_alt_rounded,
              ),
              _SummaryTag(
                label: strings.text(
                  en: 'Group: $groupingLabel',
                  vi: 'Nhóm: $groupingLabel',
                ),
                icon: Icons.view_stream_rounded,
              ),
              if (liveConnected)
                _SummaryTag(
                  label: strings.text(en: 'Live sync', vi: 'Đồng bộ trực tiếp'),
                  icon: Icons.wifi_tethering_rounded,
                ),
              if (hydratedFromCache)
                _SummaryTag(
                  label: strings.text(
                    en: 'Showing cache',
                    vi: 'Đang hiển thị cache',
                  ),
                  icon: Icons.offline_bolt_rounded,
                ),
            ],
          ),
          if (hasActiveFilter && onClearFilter != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.clear_rounded),
              label: Text(
                strings.text(
                  en: 'Back to all notifications',
                  vi: 'Quay về tất cả thông báo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SummaryTag({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ControlTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool error;

  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final backgroundColor = error ? cs.errorContainer : cs.secondaryContainer;
    final foregroundColor = error
        ? cs.onErrorContainer
        : cs.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: foregroundColor)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onPressed;

  const _EmptyState({required this.message, this.actionLabel, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: cs.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => onPressed!.call(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String typeLabel;
  final String displayTitle;
  final String displayBody;
  final String createdAt;
  final String classStartAt;
  final bool canConfirmTeaching;
  final bool canOpenClassDetail;
  final String openClassLabel;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onConfirmTeaching;
  final VoidCallback onOpenClassDetail;

  const _NotificationCard({
    required this.notification,
    required this.typeLabel,
    required this.displayTitle,
    required this.displayBody,
    required this.createdAt,
    required this.classStartAt,
    required this.canConfirmTeaching,
    required this.canOpenClassDetail,
    required this.openClassLabel,
    required this.isBusy,
    required this.onTap,
    required this.onConfirmTeaching,
    required this.onOpenClassDetail,
  });

  _NotificationVisualStyle _resolveStyle(ColorScheme cs) {
    switch (notification.type) {
      case NotificationFilterKeys.minimumReached:
        return _NotificationVisualStyle(Icons.groups_rounded, cs.primary);
      case NotificationFilterKeys.tutorConfirmed:
        return _NotificationVisualStyle(
          Icons.verified_rounded,
          Colors.green.shade700,
        );
      case NotificationFilterKeys.classStartingSoon:
        return _NotificationVisualStyle(
          Icons.schedule_rounded,
          Colors.orange.shade700,
        );
      case NotificationFilterKeys.classCancelled:
        return _NotificationVisualStyle(Icons.event_busy_rounded, cs.error);
      case NotificationFilterKeys.refundIssued:
        return _NotificationVisualStyle(
          Icons.replay_rounded,
          Colors.teal.shade700,
        );
      case NotificationFilterKeys.payoutUpdated:
        return _NotificationVisualStyle(
          Icons.payments_rounded,
          Colors.indigo.shade700,
        );
      case NotificationFilterKeys.disputeResolved:
        return _NotificationVisualStyle(
          Icons.gavel_rounded,
          Colors.deepPurple.shade700,
        );
      default:
        return _NotificationVisualStyle(
          Icons.notifications_rounded,
          cs.primary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final visual = _resolveStyle(cs);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread ? visual.color.withValues(alpha: 0.09) : cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isUnread
                  ? visual.color.withValues(alpha: 0.22)
                  : cs.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(visual.icon, color: visual.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: visual.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TypePill(label: typeLabel, color: visual.color),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      displayBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    if ((notification.classCode?.isNotEmpty ?? false) ||
                        classStartAt.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          if (notification.classCode?.isNotEmpty ?? false)
                            _MetaLine(
                              icon: Icons.confirmation_number_outlined,
                              text: strings.text(
                                en: 'Class code ${notification.classCode}',
                                vi: 'Mã lớp ${notification.classCode}',
                              ),
                            ),
                          if (classStartAt.isNotEmpty)
                            _MetaLine(
                              icon: Icons.schedule_outlined,
                              text: strings.text(
                                en: 'Starts at $classStartAt',
                                vi: 'Bắt đầu lúc $classStartAt',
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (canConfirmTeaching || canOpenClassDetail) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (canConfirmTeaching)
                            FilledButton.icon(
                              onPressed: isBusy ? null : onConfirmTeaching,
                              icon: Icon(
                                isBusy
                                    ? Icons.hourglass_top_rounded
                                    : Icons.check_circle_rounded,
                              ),
                              label: Text(
                                isBusy
                                    ? strings.text(
                                        en: 'Processing',
                                        vi: 'Đang xử lý',
                                      )
                                    : strings.text(
                                        en: 'Confirm teaching',
                                        vi: 'Xác nhận dạy',
                                      ),
                              ),
                            ),
                          if (canOpenClassDetail)
                            OutlinedButton.icon(
                              onPressed: onOpenClassDetail,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(openClassLabel),
                            ),
                        ],
                      ),
                    ],
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

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;

  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationVisualStyle {
  final IconData icon;
  final Color color;

  const _NotificationVisualStyle(this.icon, this.color);
}
