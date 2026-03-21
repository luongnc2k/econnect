# Tính Năng Tutor

## Mục tiêu

Cung cấp shell riêng cho giáo viên sau khi đăng nhập.

## Phạm vi

- `view/screens/tutor_home_screen.dart`

## Luồng chính

`HomePage`
-> nếu role là `tutor`
-> render `TutorNavShell`
-> shell hiện có 4 tab: home, teaching schedule, students, profile.

## Trạng thái hiện tại

- Tab `home` đã có UI cơ bản và lời chào theo người dùng hiện tại.
- Tab `profile` hiện tại cho phép đăng xuất nhanh.
- Tab `teaching schedule` và `students` đang là placeholder.

## Thiết kế

- Feature đang ở giai đoạn scaffold, chủ yếu để giữ cho routing theo role chạy thông suốt.
- `TutorNavShell` dùng `IndexedStack` giống student shell để giữ state tab.
- Đã kết nối sẵn với `currentUserProvider`, `themeModeProvider` và `AuthViewModel.logout`.

## Phụ thuộc

- `features/home`
- `features/auth`
- `core/providers/current_user_notifier.dart`
- `core/providers/theme_notifier.dart`

## Mở rộng

- Có thể tách từng tab thành feature con khi luồng giáo viên được xây dựng đầy đủ.
- Nếu profile tutor cần dùng chung với profile feature, nên thay `_ProfileTab` bằng `MyProfileView`.
