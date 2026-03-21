# Tính Năng Home

## Mục tiêu

Làm điểm vào sau khi đã đăng nhập và điều hướng người dùng đến shell đúng theo role.

## Phạm vi

- `view/pages/home_page.dart`

## Luồng chính

`HomePage`
-> đọc `currentUserProvider`
-> nếu role là `tutor` thì render `TutorNavShell`
-> ngược lại render `StudentNavShell`.

## Thiết kế

- Feature này có ý nghĩa là role gateway, không chứa business logic riêng.
- Quy tắc fallback hiện tại: role không phải `tutor` sẽ vào student shell.
- Routing ở tầng cao hơn chỉ cần đẩy user vào `HomePage`, còn phần rẽ nhánh role xử lý tại đây.

## Phụ thuộc

- `core/providers/current_user_notifier.dart`
- `features/student`
- `features/tutor`

## Mở rộng

- Nếu sau này có role mới như `admin`, file này là điểm đầu tiên cần cập nhật.
- Có thể đổi từ `if` đơn giản sang role-to-shell mapper khi số role tăng lên.
