# Tutor Feature

## Muc tieu

Cung cap shell rieng cho giao vien sau khi dang nhap.

## Pham vi

- `view/screens/tutor_home_screen.dart`

## Luong chinh

`HomePage`
-> neu role la `tutor`
-> render `TutorNavShell`
-> shell hien co 4 tab: home, teaching schedule, students, profile.

## Trang thai hien tai

- Tab `home` da co UI co ban va greeting theo user hien tai.
- Tab `profile` hien tai cho phep dang xuat nhanh.
- Tab `teaching schedule` va `students` dang la placeholder.

## Thiet ke

- Feature dang o giai doan scaffold, chu yeu de giu cho routing theo role chay thong suot.
- `TutorNavShell` dung `IndexedStack` giong student shell de giu state tab.
- Da ket noi san voi `currentUserProvider`, `themeModeProvider` va `AuthViewModel.logout`.

## Phu thuoc

- `features/home`
- `features/auth`
- `core/providers/current_user_notifier.dart`
- `core/providers/theme_notifier.dart`

## Mo rong

- Co the tach tung tab thanh feature con khi luong giao vien duoc xay dung day du.
- Neu profile tutor can dung chung voi profile feature, nen thay `_ProfileTab` bang `MyProfileView`.
