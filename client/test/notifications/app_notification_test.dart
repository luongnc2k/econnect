import 'package:client/features/notifications/model/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimum reached notification stays actionable after being read', () {
    const notification = AppNotification(
      id: 'noti-1',
      type: 'minimum_participants_reached',
      title: 'Lop da du so hoc vien toi thieu',
      body: 'Hay xac nhan day.',
      data: {'class_id': 'class-1'},
      isRead: true,
    );

    expect(notification.canConfirmTeaching, isTrue);
  });

  test('maps known notification types to readable labels', () {
    const notification = AppNotification(
      id: 'noti-2',
      type: 'refund_issued',
      title: 'Hoc phi da duoc hoan',
      body: 'Thong bao hoan tien.',
      data: {},
      isRead: false,
    );

    expect(notification.typeLabel, 'Hoàn tiền');
  });
}
