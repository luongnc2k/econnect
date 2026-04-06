# Profile Feature

## Muc tieu

Quan ly viec xem, chinh sua va cap nhat ho so cho user hien tai va xem profile cua nguoi khac.

## Pham vi

- `view/screens/my_profile_screen.dart`
- `view/screens/edit_my_profile_screen.dart`
- `view/screens/user_profile_screen.dart`
- `view/widgets/my_profile_view.dart`
- `view/widgets/my_profile_header.dart`
- `view/widgets/profile_info_card.dart`
- `viewmodel/my_profile_viewmodel.dart`
- `repositories/my_profile_repository.dart`
- `repositories/user_profile_repository.dart`
- `model/student_my_profile_model.dart`
- `model/teacher_my_profile_model.dart`

## Luong chinh

### 1. Xem profile cua chinh minh

`MyProfileView`
-> `my_profile_viewmodel.fetchMyProfile`
-> `MyProfileRepository.getMyProfile`
-> map du lieu theo role
-> render thong tin ca nhan + block role-specific.

### 2. Chinh sua profile cua chinh minh

`EditMyProfileScreen`
-> do du lieu hien tai tu `myProfileViewModelProvider`
-> cho phep sua field phu hop theo role
-> submit qua `MyProfileRepository.updateMyProfile`
-> viewmodel cap nhat state
-> quay lai man hinh profile voi du lieu moi.

### 3. Xem profile nguoi khac

`UserProfileScreen`
-> `UserProfileRepository.getUserProfileById`
-> map profile theo role
-> render read-only thong tin public.

### 4. Upload avatar / tai lieu xac minh

`EditMyProfileScreen`
-> goi action upload trong `MyProfileViewModel`
-> repository lam viec voi upload endpoint
-> server tra URL moi
-> state profile duoc cap nhat de UI refresh.

## Thiet ke

- Phan tach ro 3 use case: `my profile`, `edit my profile`, `user profile`.
- Model student va teacher tach rieng de UI render dung field theo role.
- `MyProfileViewModel` giu state cua profile hien tai va cac trang thai nhu loading, saving, uploading.
- Widget layer duoc tach nho de tai su dung card/header giua cac man hinh profile.

## Phu thuoc

- `features/auth/model/user_model.dart`
- `core/router/app_router.dart`
- API `/profile/*` va upload endpoint

## Luu y

- Student profile hien tai khong con hien thi `average score` tren UI.
- Teacher profile co them certification, verification docs, rating, hourly rate.
