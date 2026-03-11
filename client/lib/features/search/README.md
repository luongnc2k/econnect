# Search Feature

## Muc tieu

Tap trung toan bo hanh vi tim kiem thanh mot module rieng: tim user, tim lop hoc va tai su dung search bar.

## Pham vi

- `view/screens/user_search_screen.dart`
- `view/screens/class_search_screen.dart`
- `view/widgets/search_bar_widget.dart`
- `repositories/user_search_repository.dart`

## Luong chinh

### 1. Tim user

`UserSearchScreen`
-> user nhap keyword
-> `_search`
-> neu keyword giong ma lop thi re nhanh sang tim lop
-> nguoc lai goi `UserSearchRepository.searchUsers`
-> render danh sach user
-> tap item de mo `UserProfileScreen`.

### 2. Tim lop hoc

`ClassSearchScreen`
-> user nhap ten lop hoac ma lop
-> `_loadClasses`
-> neu keyword giong class code thi goi `getClassByCode`
-> nguoc lai goi `getUpcomingClasses`
-> render danh sach lop
-> tap item de mo `ClassDetailScreen`.

### 3. Search entry point tu student home

`StudentHomeScreen`
-> search bar read-only
-> `onSearchTap`
-> `StudentNavShell` chuyen tab sang `UserSearchScreen`.

## Thiet ke

- Gom `search` thanh feature rieng de tranh de widget search nam o `student` va logic user search nam o `profile`.
- `SearchBarWidget` la primitive dung chung, khong chua logic domain.
- Search user va search class dung chung UX nhap keyword, nhung giu man hinh rieng de don gian hoa state.
- Manual fallback tu `ManualTestMocks` duoc giu trong flow search de dev/test offline.

## Phu thuoc

- `features/student/repositories/student_remote_repository.dart`
- `features/student/view/widgets/upcoming_classlist_widget.dart`
- `features/profile` de mo user profile
- `core/router/app_router.dart`

## Mo rong

- Co the tach them `class_search_repository.dart` neu logic tim lop tang do phuc tap.
- Co the them debounce va search suggestions ma khong can doi cau truc feature.
