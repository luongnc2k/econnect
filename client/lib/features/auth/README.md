# Auth Feature

## Muc tieu

Quan ly dang ky, dang nhap, khoi phuc phien dang nhap va dong bo user hien tai vao app state.

## Pham vi

- `view/screens/login_screen.dart`
- `view/screens/signup_screen.dart`
- `viewmodel/auth_viewmodel.dart`
- `repositories/auth_remote_repository.dart`
- `repositories/auth_local_repository.dart`
- `model/user_model.dart`

## Luong chinh

### 1. Dang ky

`SignupScreen`
-> goi `AuthViewModel.signUpUser`
-> `AuthRemoteRepository.signup`
-> server tra ve `UserModel`
-> state `AsyncValue.data`
-> UI quyet dinh chuyen man hinh tiep theo.

### 2. Dang nhap

`LoginScreen`
-> goi `AuthViewModel.loginUser`
-> `AuthRemoteRepository.login`
-> `_loginSuccess`
-> luu token + user vao `AuthLocalRepository`
-> cap nhat `currentUserProvider`
-> UI rebuild theo trang thai da dang nhap.

### 3. Khoi phuc session khi mo app

App bootstrap
-> `AuthViewModel.initSharedPreferences`
-> `AuthViewModel.getData`
-> doc token/user cache tu local
-> cap nhat `currentUserProvider` ngay lap tuc
-> goi API `getCurrentUserData` de validate token
-> neu token invalid thi clear session, neu hop le thi ghi de cache.

### 4. Dang xuat

Bat ky UI nao goi `AuthViewModel.logout`
-> xoa token + user cache
-> reset `currentUserProvider`
-> app quay ve trang thai chua dang nhap.

## Thiet ke

- Dung `AuthViewModel` lam orchestration layer cho UI.
- Tach remote/local repository de tranh tron logic API va persistence.
- `currentUserProvider` la nguon state dung chung cho routing va feature khac.
- Uu tien restore cache truoc khi validate server de tranh flash logout khi app khoi dong cham.

## Phu thuoc

- `core/providers/current_user_notifier.dart`
- SharedPreferences qua `AuthLocalRepository`
- API auth ben backend

## Luu y

- `AuthViewModel` hien tai tra `AsyncValue<UserModel>?`, co the o `null` khi chua co session.
- Role tra ve tu auth anh huong truc tiep den `home` feature de chon shell phu hop.
