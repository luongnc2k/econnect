# Student Feature

## Muc tieu

Phuc vu trai nghiem chinh cho hoc vien: home feed, danh muc chu de, danh sach lop sap dien ra, chi tiet lop va dieu huong den cac tab lien quan.

## Pham vi

- `view/screens/student_nav_shell.dart`
- `view/screens/student_home_screen.dart`
- `view/screens/class_detail_screen.dart`
- `viewmodel/student_home_viewmodel.dart`
- `repositories/student_repository.dart`
- `repositories/student_remote_repository.dart`
- `model/class_session*.dart`
- `model/teacher_preview.dart`
- `view/widgets/*` lien quan den class card, teacher card, header, filter

## Luong chinh

### 1. Student shell

`StudentNavShell`
-> giu `IndexedStack`
-> 4 tab: home, user search, class search, profile
-> giu state tab khi chuyen qua lai.

### 2. Tai home feed

`StudentHomeScreen`
-> watch `studentHomeViewModelProvider`
-> `StudentHomeViewModel.build`
-> neu co current user thi trigger `_loadClasses`
-> lay lop sap dien ra
-> map teacher preview tu class list
-> render header, search entry, category filter, upcoming classes, featured teachers.

### 3. Filter theo category

User chon category
-> `selectCategory`
-> map category sang topic slug
-> goi lai `_loadClasses`
-> refresh danh sach lop va danh sach teacher.

### 4. Xem chi tiet lop

Tap class item
-> route sang `class_detail_screen.dart`
-> hien thong tin giao vien, tags, mo ta, avatar hoc vien da dang ky va thong tin bo sung.

## Thiet ke

- Student feature tap trung vao consumption flow cua hoc vien.
- `StudentHomeViewModel` la orchestration point cho home data.
- `student_remote_repository.dart` chua call API, con widget layer chi render state da duoc xu ly.
- Teacher preview duoc suy ra tu class list, khong can endpoint rieng cho home.
- `IndexedStack` duoc chon de giu state cua tung tab trong student shell.

## Phu thuoc

- `currentUserProvider`
- `features/search`
- `features/profile`
- `go_router`
- `ManualTestMocks` cho local/manual testing

## Luu y

- Search da duoc tach ra `features/search`, student chi con dong vai tro entry point va host navigation.
- Mot so text hien tai trong code co dau hieu encoding chua dong nhat, can don dep rieng neu muon chinh sua UI text.
