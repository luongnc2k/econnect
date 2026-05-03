# Tính Năng Notifications

## Mục tiêu

Feature `notifications` quản lý hộp thư thông báo trong app để:

- hiển thị các thay đổi quan trọng của lớp học và payment
- đồng bộ trạng thái đã đọc/chưa đọc
- cho Tutor xác nhận dạy ngay từ notification
- hỗ trợ mở nhanh vào lớp học từ notification có `class_code`
- giảm độ trễ trải nghiệm bằng badge unread, cache cục bộ và polling khi app đang hoạt động

## Phạm vi file

- `model/app_notification.dart`
- `model/notifications_state.dart`
- `model/tutor_teaching_confirmation_result.dart`
- `repositories/notifications_remote_repository.dart`
- `repositories/notifications_local_repository.dart`
- `viewmodel/notifications_controller.dart`
- `view/screens/notifications_screen.dart`
- `view/widgets/notification_bell_button.dart`

## Những gì đã xử lý so với giới hạn ban đầu

Feature hiện tại đã xử lý được các giới hạn sau:

- không còn chỉ tải khi mở màn hình hoặc kéo refresh
  - `NotificationsController` poll định kỳ mỗi 45 giây
  - polling tự dừng khi app vào background và tự chạy lại khi app quay về foreground
- đã có đồng bộ gần realtime khi app đang mở
  - backend mở `WS /notifications/ws?token=...`
  - client giữ kênh WebSocket và tự reconnect khi app quay lại foreground
- đã có badge đếm số thông báo chưa đọc ở icon chuông
  - dùng `unreadNotificationsCountProvider`
  - đang gắn ở header của Student và Tutor
- đã có phân trang
  - backend giữ `offset` route cũ để tương thích
  - route mới dùng `cursor` cho client notifications hiện tại
  - client có nút `Tải thêm`
- deeplink không còn chỉ tối ưu cho học viên
  - học viên mở vào `ClassDetailScreen`
  - Tutor mở nhanh vào màn hình tóm tắt lớp và payout theo `class_code`
- đã có filter theo loại thông báo
  - `Tất cả`
  - `Chưa đọc`
  - `Đủ tối thiểu`
  - `Tutor xác nhận`
  - `Sắp diễn ra`
  - `Lớp bị hủy`
  - `Hoàn tiền`
  - `Payout`
  - `Khiếu nại`
- đã có grouping
  - nhóm theo ngày
  - nhóm theo loại
- đã có cache local
  - lưu inbox mặc định và unread count bằng `SharedPreferences`
  - giúp mở màn hình nhanh hơn khi mạng chậm hoặc tạm thời lỗi

## Các loại thông báo hiện có

### 1. `minimum_participants_reached`

Gửi cho Tutor khi lớp đã đạt `min_participants`.

Mục đích:

- báo lớp đã đủ điều kiện tối thiểu để diễn ra
- hiển thị nút `Xác nhận dạy`

### 2. `tutor_confirmed_teaching`

Gửi cho học viên khi Tutor đã xác nhận dạy.

Mục đích:

- báo buổi học sẽ diễn ra theo kế hoạch

### 3. `class_starting_soon`

Gửi cho Tutor và học viên khi lớp sắp bắt đầu trong khoảng 1 giờ tới.

Mục đích:

- nhắc lịch học sắp diễn ra

### 4. `class_cancelled`

Gửi khi lớp bị hủy bởi Tutor hoặc bị hệ thống hủy do không đủ điều kiện.

Mục đích:

- báo lớp không còn diễn ra
- giải thích lý do hủy

### 5. `refund_issued`

Gửi cho học viên khi hệ thống tạo hoàn tiền.

Mục đích:

- báo khoản học phí đã được đưa vào luồng hoàn tiền
- kèm lý do hoàn tiền

### 6. `payout_updated`

Gửi cho Tutor khi payout đổi trạng thái.

Mục đích:

- báo payout đang xử lý, đã hoàn tất hoặc thất bại

### 7. `dispute_resolved`

Gửi cho Tutor và học viên khi khiếu nại được admin xử lý xong.

Mục đích:

- báo kết quả hợp lệ hoặc bị từ chối
- kèm ghi chú xử lý nếu có

## Dữ liệu chính

### `AppNotification`

Model cho từng item inbox:

- `id`, `type`, `title`, `body`
- `data`
- `isRead`, `createdAt`, `readAt`

Getter đáng chú ý:

- `classId`
- `classCode`
- `classStartTime`
- `refundAmount`
- `payoutStatus`
- `cancellationReason`
- `typeLabel`
- `canConfirmTeaching`

### `NotificationsState`

State chung của feature:

- `notifications`
- `isLoading`
- `isLoadingMore`
- `hasMore`
- `unreadCount`
- `error`
- `selectedFilterKey`
- `groupingMode`
- `actionNotificationId`
- `confirmedClassIds`
- `hydratedFromCache`

## API backend đang dùng

### Lấy inbox

```http
GET /notifications?limit=20&offset=0&type=...&unread_only=true|false
Header: x-auth-token
```

### Lấy inbox theo cursor

```http
GET /notifications/cursor?limit=20&cursor=...&type=...&unread_only=true|false
Header: x-auth-token
```

### Kênh realtime

```http
WS /notifications/ws?token=<jwt>
```

### Đếm unread

```http
GET /notifications/unread-count
Header: x-auth-token
```

### Đánh dấu đã đọc

```http
POST /notifications/{notification_id}/read
Header: x-auth-token
```

### Đăng ký FCM token

```http
POST /notifications/push-tokens
Header: x-auth-token
Body: { token, platform, device_label? }
```

### Hủy đăng ký FCM token

```http
POST /notifications/push-tokens/unregister
Header: x-auth-token
Body: { token }
```

### Tutor xác nhận dạy

```http
POST /payments/classes/{class_id}/confirm-teaching
Header: x-auth-token
```

### Job nhắc lịch trước 1 giờ

```http
POST /payments/jobs/notify-classes-starting-soon
Header: x-job-secret
```

## Luồng hoạt động chính

### 1. Khởi tạo hộp thư

1. Widget watch `notificationsControllerProvider`
2. Controller đọc `currentUserProvider`
3. Nếu có user, controller đọc cache local trước
4. UI hiển thị dữ liệu cache nếu có
5. Controller gọi refresh từ backend
6. Controller bật polling khi app đang ở foreground

### 2. Refresh và polling

1. Client gọi `GET /notifications/cursor`
2. Client gọi `GET /notifications/unread-count`
3. Nếu fetch thành công thì cập nhật danh sách + unread badge
4. Nếu đang ở filter mặc định thì lưu lại cache local
5. Nếu app vào background thì dừng polling
6. Nếu app quay lại foreground thì refresh lại ngay

### 2.1 Realtime khi app đang mở

1. Client mở `WS /notifications/ws?token=<jwt>`
2. Backend gửi `notifications_changed` khi inbox hoặc unread count thay đổi
3. Client nhận event rồi gọi `refresh(silent: true)`
4. Nếu socket đứt thì controller tự reconnect sau một khoảng ngắn

### 2.2 Push notification bằng FCM

1. Khi app bootstrap trên Android/iOS, `NotificationsPushService` đọc cấu hình `FCM_*`
2. Nếu đủ cấu hình, app khởi tạo Firebase Messaging và xin quyền thông báo
3. App lấy `device token` rồi gọi `POST /notifications/push-tokens`
4. Backend lưu token theo user hiện tại
5. Mỗi lần backend tạo `Notification`, sau khi transaction commit xong sẽ thử gửi FCM
6. Khi app đang foreground, client nhận `onMessage` và refresh inbox nhẹ
7. Khi user bấm notification từ background hoặc terminated, app refresh inbox rồi điều hướng:
8. Tutor có `class_code` sẽ mở nhanh `TutorClassSummaryScreen`
9. Các trường hợp còn lại sẽ mở `NotificationsScreen`

### 3. Tutor xác nhận dạy

1. Tutor nhận notification `minimum_participants_reached`
2. Tutor bấm `Xác nhận dạy`
3. Client gọi `POST /payments/classes/{class_id}/confirm-teaching`
4. Backend cập nhật trạng thái lớp
5. Backend tạo notification cho các học viên đã đăng ký

### 4. Deeplink vào lớp học

1. Học viên bấm `Mở lớp học`
2. Client đánh dấu notification đã đọc nếu cần
3. Client gọi `GET /classes/by-code/{class_code}`
4. App điều hướng sang `ClassDetailScreen`

### 4.1 Deeplink cho Tutor

1. Tutor bấm `Mở chi tiết lớp`
2. Client đánh dấu notification đã đọc nếu cần
3. App điều hướng sang `TutorClassSummaryScreen`
4. Màn hình này gọi `GET /payments/classes/by-code/{class_code}/summary`

### 5. Reminder 1 giờ trước giờ học

1. Scheduler gọi `POST /payments/jobs/notify-classes-starting-soon`
2. Backend quét các lớp `scheduled` sắp diễn ra
3. Nếu lớp đủ điều kiện thì tạo notification cho Tutor và học viên
4. Backend đánh dấu `starting_soon_notified_at` để tránh gửi lặp
5. Nếu job bị chậm, các route notification/class/summary vẫn có thể kích hoạt fallback để phát reminder còn thiếu

### 6. Payment lifecycle notifications

Các nhánh payment hiện đã nối notification như sau:

- học phí bị hoàn -> `refund_issued`
- lớp bị hủy -> `class_cancelled`
- payout đổi trạng thái -> `payout_updated`
- khiếu nại xử lý xong -> `dispute_resolved`

## Cấu hình FCM

### Backend

Backend cần một trong hai cấu hình sau để gửi push thật:

```env
FCM_SERVICE_ACCOUNT_PATH=/absolute/path/to/service-account.json
```

hoặc:

```env
FCM_SERVICE_ACCOUNT_JSON={"type":"service_account", ...}
```

Nếu chưa có service account, backend vẫn tạo notification trong inbox như bình thường, chỉ bỏ qua bước gửi FCM.

### Client

Client hiện đọc Firebase config qua `--dart-define`. Tối thiểu cần:

```bash
flutter run \
  --dart-define=FCM_API_KEY=... \
  --dart-define=FCM_PROJECT_ID=... \
  --dart-define=FCM_MESSAGING_SENDER_ID=... \
  --dart-define=FCM_ANDROID_APP_ID=... \
  --dart-define=FCM_IOS_APP_ID=... \
  --dart-define=FCM_IOS_BUNDLE_ID=com.example.client
```

Ghi chú:

- Android đã thêm sẵn `POST_NOTIFICATIONS` và sẽ tự apply `com.google.gms.google-services` nếu project có `android/app/google-services.json`
- iOS đã bật `remote-notification` trong `Info.plist`, nhưng production vẫn cần cấu hình APNs key/capability ở Apple Developer và Firebase
- Web push chưa bật trong turn này vì chưa có `firebase-messaging-sw.js`

## UI hiện tại

`NotificationsScreen` hiện gồm:

- dải filter ngang theo loại thông báo
- dải chọn cách nhóm theo `ngày` hoặc `loại`
- info strip cho unread count và trạng thái cache
- info strip cho trạng thái đồng bộ trực tiếp qua WebSocket
- danh sách notification với chip loại thông báo
- action inline cho Tutor xác nhận dạy
- action inline cho học viên mở nhanh lớp học
- action inline cho Tutor mở nhanh màn hình tóm tắt lớp
- phân trang bằng nút `Tải thêm`

Badge unread được render bằng `NotificationBellButton` và đang gắn ở:

- `HomeHeaderWidget`
- `TutorHomeScreen`

## Giới hạn còn lại

- FCM chỉ bật thật khi cả backend và client đều được cấu hình credential phù hợp
- realtime foreground hiện đi qua cả `WebSocket` lẫn refresh sau `onMessage`, nhưng background/terminated phụ thuộc FCM đã được cấu hình đúng
- reminder trước giờ học đã có fallback khi client đọc inbox/lớp, nhưng để chính xác nhất vẫn nên giữ scheduler/job backend
- deeplink của Tutor từ FCM hiện đang mở nhanh vào màn hình tóm tắt lớp và payment, chưa phải màn hình quản lý lớp đầy đủ
- web push chưa có service worker riêng nên Chrome/web chưa nhận được FCM background
- iOS production vẫn cần APNs key/certificate và entitlement đúng ở dự án Apple

## Hướng mở rộng tiếp theo

- thêm web push bằng `firebase-messaging-sw.js` nếu cần hỗ trợ Chrome/PWA
- thêm deeplink sâu hơn cho Tutor sang màn hình quản lý lớp chi tiết thay vì chỉ summary
- thêm local notification bridge để hiển thị banner tùy biến khi app đang foreground
- thêm local queue hoặc worker riêng nếu cần SLA nhắc lịch chặt hơn nữa
- thêm analytics cho notification open rate, confirm rate và refresh latency
