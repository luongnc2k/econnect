# Home Feature

## Muc tieu

Lam diem vao sau khi da dang nhap va dieu huong user den shell dung theo role.

## Pham vi

- `view/pages/home_page.dart`

## Luong chinh

`HomePage`
-> doc `currentUserProvider`
-> neu role la `tutor` thi render `TutorNavShell`
-> nguoc lai render `StudentNavShell`.

## Thiet ke

- Feature nay co y nghia la role gateway, khong chua business logic rieng.
- Quy tac fallback hien tai: role khong phai `tutor` se vao student shell.
- Routing o tang cao hon chi can day user vao `HomePage`, con phan nhanh role xu ly tai day.

## Phu thuoc

- `core/providers/current_user_notifier.dart`
- `features/student`
- `features/tutor`

## Mo rong

- Neu sau nay co role moi nhu `admin`, file nay la diem dau tien can cap nhat.
- Co the doi tu `if` don gian sang role-to-shell mapper khi so role tang len.
