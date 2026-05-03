# Tính Năng Auth

## Mục tiêu

Quản lý đăng ký, đăng nhập, khôi phục phiên đăng nhập và đồng bộ người dùng hiện tại vào app state.

## Phạm vi

- `view/screens/login_screen.dart`
- `view/screens/signup_screen.dart`
- `viewmodel/auth_viewmodel.dart`
- `repositories/auth_remote_repository.dart`
- `repositories/auth_local_repository.dart`
- `model/user_model.dart`

## Luồng chính

### 1. Đăng ký

`SignupScreen`
-> gọi `AuthViewModel.signUpUser`
-> `AuthRemoteRepository.signup`
-> server trả về `UserModel`
-> state `AsyncValue.data`
-> UI quyết định chuyển màn hình tiếp theo.

### 2. Đăng nhập

`LoginScreen`
-> gọi `AuthViewModel.loginUser`
-> `AuthRemoteRepository.login`
-> `_loginSuccess`
-> lưu token + user vào `AuthLocalRepository`
-> cập nhật `currentUserProvider`
-> UI rebuild theo trạng thái đã đăng nhập.

### 3. Khôi phục session khi mở app

App bootstrap
-> `AuthViewModel.initSharedPreferences`
-> `AuthViewModel.getData`
-> đọc token/user cache từ local
-> cập nhật `currentUserProvider` ngay lập tức
-> gọi API `getCurrentUserData` để validate token
-> nếu token invalid thì clear session, nếu hợp lệ thì ghi đè cache.

### 4. Đăng xuất

Bất kỳ UI nào gọi `AuthViewModel.logout`
-> xóa token + user cache
-> reset `currentUserProvider`
-> app quay về trạng thái chưa đăng nhập.

## Thiết kế

- Dùng `AuthViewModel` làm orchestration layer cho UI.
- Tách remote/local repository để tránh trộn logic API và persistence.
- `currentUserProvider` là nguồn state dùng chung cho routing và các feature khác.
- Ưu tiên restore cache trước khi validate server để tránh flash logout khi app khởi động chậm.

## Phụ thuộc

- `core/providers/current_user_notifier.dart`
- SharedPreferences qua `AuthLocalRepository`
- API auth bên backend

## Lưu ý

- `AuthViewModel` hiện tại trả `AsyncValue<UserModel>?`, có thể ở `null` khi chưa có session.
- Role trả về từ auth ảnh hưởng trực tiếp đến `home` feature để chọn shell phù hợp.
