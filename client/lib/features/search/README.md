# Tính Năng Search

## Mục tiêu

Tập trung toàn bộ hành vi tìm kiếm thành một module riêng: tìm người dùng, tìm lớp học và tái sử dụng search bar.

## Phạm vi

- `view/screens/user_search_screen.dart`
- `view/screens/class_search_screen.dart`
- `view/widgets/search_bar_widget.dart`
- `repositories/user_search_repository.dart`

## Luồng chính

### 1. Tìm người dùng

`UserSearchScreen`
-> người dùng nhập từ khóa
-> `_search`
-> nếu từ khóa giống mã lớp thì rẽ nhanh sang tìm lớp
-> ngược lại gọi `UserSearchRepository.searchUsers`
-> render danh sách người dùng
-> chạm vào item để mở `UserProfileScreen`.

### 2. Tìm lớp học

`ClassSearchScreen`
-> người dùng nhập tên lớp hoặc mã lớp
-> `_loadClasses`
-> nếu từ khóa giống class code thì gọi `getClassByCode`
-> ngược lại gọi `getUpcomingClasses`
-> render danh sách lớp
-> chạm vào item để mở `ClassDetailScreen`.

### 3. Điểm vào tìm kiếm từ trang chủ học viên

`StudentHomeScreen`
-> search bar ở chế độ read-only
-> `onSearchTap`
-> `StudentNavShell` chuyển tab sang `UserSearchScreen`.

## Thiết kế

- Gom `search` thành feature riêng để tránh để widget search nằm ở `student` còn logic user search nằm ở `profile`.
- `SearchBarWidget` là primitive dùng chung, không chứa logic domain.
- Search user và search class dùng chung UX nhập từ khóa, nhưng giữ màn hình riêng để đơn giản hóa state.
- Manual fallback từ `ManualTestMocks` được giữ trong flow search để dev/test offline.

## Phụ thuộc

- `features/student/repositories/student_remote_repository.dart`
- `features/student/view/widgets/upcoming_classlist_widget.dart`
- `features/profile` để mở user profile
- `core/router/app_router.dart`

## Mở rộng

- Có thể tách thêm `class_search_repository.dart` nếu logic tìm lớp tăng độ phức tạp.
- Có thể thêm debounce và search suggestions mà không cần đổi cấu trúc feature.
