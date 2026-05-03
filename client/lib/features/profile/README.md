# Tính Năng Profile

## Mục tiêu

Quản lý việc xem, chỉnh sửa và cập nhật hồ sơ cho người dùng hiện tại, đồng thời xem profile của người khác.

## Phạm vi

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

## Luồng chính

### 1. Xem profile của chính mình

`MyProfileView`
-> `my_profile_viewmodel.fetchMyProfile`
-> `MyProfileRepository.getMyProfile`
-> map dữ liệu theo role
-> render thông tin cá nhân + block riêng theo role.

### 2. Chỉnh sửa profile của chính mình

`EditMyProfileScreen`
-> đổ dữ liệu hiện tại từ `myProfileViewModelProvider`
-> cho phép sửa các field phù hợp theo role
-> submit qua `MyProfileRepository.updateMyProfile`
-> viewmodel cập nhật state
-> quay lại màn hình profile với dữ liệu mới.

### 3. Xem profile người khác

`UserProfileScreen`
-> `UserProfileRepository.getUserProfileById`
-> map profile theo role
-> render read-only thông tin public.

### 4. Upload avatar / tài liệu xác minh

`EditMyProfileScreen`
-> gọi action upload trong `MyProfileViewModel`
-> repository làm việc với upload endpoint
-> server trả URL mới
-> state profile được cập nhật để UI refresh.

## Thiết kế

- Phân tách rõ 3 use case: `my profile`, `edit my profile`, `user profile`.
- Model student và teacher tách riêng để UI render đúng field theo role.
- `MyProfileViewModel` giữ state của profile hiện tại và các trạng thái như loading, saving, uploading.
- Widget layer được tách nhỏ để tái sử dụng card/header giữa các màn hình profile.

## Phụ thuộc

- `features/auth/model/user_model.dart`
- `core/router/app_router.dart`
- API `/profile/*` và upload endpoint

## Lưu ý

- Student profile hiện tại không còn hiển thị `average score` trên UI.
- Teacher profile có thêm certification, verification docs và rating.
