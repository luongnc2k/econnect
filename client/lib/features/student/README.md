# Tính Năng Student

## Mục tiêu

Phục vụ trải nghiệm chính cho học viên: home feed, danh mục chủ đề, danh sách lớp sắp diễn ra, chi tiết lớp và điều hướng đến các tab liên quan.

## Phạm vi

- `view/screens/student_nav_shell.dart`
- `view/screens/student_home_screen.dart`
- `view/screens/class_detail_screen.dart`
- `viewmodel/student_home_viewmodel.dart`
- `repositories/student_repository.dart`
- `repositories/student_remote_repository.dart`
- `model/class_session*.dart`
- `model/teacher_preview.dart`
- `view/widgets/*` liên quan đến class card, teacher card, header, filter

## Luồng chính

### 1. Student shell

`StudentNavShell`
-> giữ `IndexedStack`
-> 4 tab: home, user search, class search, profile
-> giữ state tab khi chuyển qua lại.

### 2. Tải home feed

`StudentHomeScreen`
-> watch `studentHomeViewModelProvider`
-> `StudentHomeViewModel.build`
-> nếu có current user thì trigger `_loadClasses`
-> lấy lớp sắp diễn ra
-> map teacher preview từ class list
-> render header, search entry, category filter, upcoming classes, featured teachers.

### 3. Filter theo category

Người dùng chọn category
-> `selectCategory`
-> map category sang topic slug
-> gọi lại `_loadClasses`
-> refresh danh sách lớp và danh sách giáo viên.

### 4. Xem chi tiết lớp

Chạm vào class item
-> route sang `class_detail_screen.dart`
-> hiển thị thông tin giáo viên, tags, mô tả, avatar học viên đã đăng ký và thông tin bổ sung.

## Thiết kế

- Student feature tập trung vào consumption flow của học viên.
- `StudentHomeViewModel` là orchestration point cho dữ liệu trang chủ.
- `student_remote_repository.dart` chứa call API, còn widget layer chỉ render state đã được xử lý.
- Teacher preview được suy ra từ class list, không cần endpoint riêng cho home.
- `IndexedStack` được chọn để giữ state của từng tab trong student shell.

## Phụ thuộc

- `currentUserProvider`
- `features/search`
- `features/profile`
- `go_router`
- `ManualTestMocks` cho local/manual testing

## Lưu ý

- Search đã được tách ra `features/search`, student chỉ còn đóng vai trò entry point và host navigation.
- Một số text hiện tại trong code có dấu hiệu encoding chưa đồng nhất, cần dọn riêng nếu muốn chỉnh sửa UI text.
