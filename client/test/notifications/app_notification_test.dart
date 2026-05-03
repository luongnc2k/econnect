import 'package:client/features/notifications/model/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimum reached notification stays actionable after being read', () {
    const notification = AppNotification(
      id: 'noti-1',
      type: 'minimum_participants_reached',
      title: 'Lớp đã đủ số học viên tối thiểu',
      body: 'Hãy xác nhận dạy.',
      data: {'class_id': 'class-1'},
      isRead: true,
    );

    expect(notification.canConfirmTeaching, isTrue);
  });

  test('maps generic refunds to readable label', () {
    const notification = AppNotification(
      id: 'noti-2',
      type: 'refund_issued',
      title: 'Học phí đã được hoàn',
      body: 'Thông báo hoàn tiền.',
      data: {},
      isRead: false,
    );

    expect(notification.typeLabel, 'Hoàn tiền');
  });

  test('maps class creation fee refunds to dedicated label', () {
    const notification = AppNotification(
      id: 'noti-3',
      type: 'refund_issued',
      title: 'Refund',
      body: 'Refund in progress.',
      data: {'refund_scope': 'class_creation_fee'},
      isRead: false,
    );

    expect(notification.typeLabel, 'Hoàn phí tạo lớp');
  });

  test('normalizes legacy class creation fee refund content from API', () {
    final notification = AppNotification.fromMap({
      'id': 'noti-4',
      'type': 'refund_issued',
      'title': '?? ghi nh?n ho?n ph? t?o l?p',
      'body':
          "H? th?ng ?? ghi nh?n kho?n ho?n ph? t?o l?p 2.000 VND cho l?p 'z'. Kho?n n?y ch?a ??ng ngh?a ti?n ?? v? t?i kho?n ng?n h?ng c?a tutor.",
      'data': {
        'refund_scope': 'class_creation_fee',
        'refund_status': 'legacy_recorded',
        'refund_amount': '2000',
        'class_title': 'z',
      },
      'is_read': false,
    });

    expect(notification.title, 'Đã ghi nhận hoàn phí tạo lớp');
    expect(
      notification.body,
      "Hệ thống đã ghi nhận khoản hoàn phí tạo lớp 2.000 VND cho lớp 'z'. Khoản này chưa đồng nghĩa tiền đã về tài khoản ngân hàng của tutor.",
    );
  });

  test('normalizes legacy ASCII reasons inside notification content', () {
    final notification = AppNotification.fromMap({
      'id': 'noti-5',
      'type': 'class_cancelled',
      'title': 'Lớp học đã bị hủy',
      'body':
          "Lớp 'zzz' đã bị hủy. Lý do: Khong du hoc vien toi thieu truoc 4 gio.",
      'data': {
        'cancellation_reason': 'Khong du hoc vien toi thieu truoc 4 gio',
      },
      'is_read': false,
    });

    expect(
      notification.body,
      "Lớp 'zzz' đã bị hủy. Lý do: Không đủ học viên tối thiểu trước 4 giờ.",
    );
    expect(
      notification.cancellationReason,
      'Không đủ học viên tối thiểu trước 4 giờ',
    );
  });
}
