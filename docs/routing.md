# Routing — EConnect Flutter Client

Sử dụng **go_router** (`^15.x`). Toàn bộ cấu hình nằm tại:

```
client/lib/core/router/app_router.dart
```

---

## Route table

| Constant (`AppRoutes`) | Path | Screen | Auth |
|---|---|---|---|
| `login` | `/login` | `LoginScreen` | Public |
| `signup` | `/signup` | `SignupScreen` | Public |
| `studentHome` | `/student` | `StudentNavShell` | ✓ |
| `classDetail` | `/student/class` | `ClassDetailScreen` | ✓ |
| `teacherHome` | `/teacher` | `TutorNavShell` | ✓ |

---

## Auth guard

Router tự động redirect dựa trên trạng thái `currentUserProvider`:

```
Chưa login  →  bất kỳ route nào  →  /login
Đã login    →  /login hoặc /signup  →  /student (student) hoặc /teacher (teacher)
```

Không cần xử lý auth thủ công trong từng màn hình.

---

## Cách điều hướng

### Không truyền data

```dart
context.go(AppRoutes.login);
context.go(AppRoutes.studentHome);
```

### Truyền data qua `extra`

Dùng khi cần pass object phức tạp (không serialize được trên URL):

```dart
context.go(AppRoutes.classDetail, extra: session);
```

Nhận ở màn hình đích (`app_router.dart` xử lý):

```dart
// Đã có sẵn trong router — không cần làm thêm
builder: (context, state) {
  final session = state.extra as ClassSession;
  return ClassDetailScreen(session: session);
}
```

### Push (giữ back stack) vs Go (xoá stack)

```dart
context.go('/student');   // Xoá toàn bộ stack → không có nút back
context.push('/student/class', extra: session); // Giữ stack → có nút back
```

> Dùng `go` khi chuyển tab hoặc sau login/logout.
> Dùng `push` khi mở màn hình detail từ list.

### Quay lại

```dart
context.pop();           // Quay lại màn hình trước
context.canPop();        // Kiểm tra trước khi pop
```

---

## Thêm màn hình mới

### 1. Khai báo constant

```dart
// app_router.dart
abstract class AppRoutes {
  // ... existing routes
  static const studentProfile = '/student/profile'; // thêm vào đây
}
```

### 2. Đăng ký route

**Route độc lập (top-level):**

```dart
GoRoute(
  path: AppRoutes.studentProfile,
  builder: (context, _) => const StudentProfileScreen(),
),
```

**Route con (sub-route, có back stack từ parent):**

```dart
GoRoute(
  path: AppRoutes.studentHome,       // /student
  builder: (context, _) => const StudentNavShell(),
  routes: [
    GoRoute(
      path: 'profile',               // → /student/profile
      builder: (context, _) => const StudentProfileScreen(),
    ),
  ],
),
```

**Route cần truyền data:**

```dart
GoRoute(
  path: 'profile',
  builder: (context, state) {
    final userId = state.extra as String;
    return StudentProfileScreen(userId: userId);
  },
),
```

### 3. Điều hướng đến

```dart
context.push(AppRoutes.studentProfile);
context.push(AppRoutes.studentProfile, extra: userId);
```

---

## Lưu ý

- **Không dùng `Navigator.push` / `MaterialPageRoute`** — dùng `context.go` hoặc `context.push` để auth guard và deep link hoạt động đúng.
- Khi logout, gọi `context.go(AppRoutes.login)` để clear toàn bộ stack.
- `extra` không tồn tại sau hot restart — nếu màn hình cần restore từ deep link, dùng `pathParameters` hoặc `queryParameters` thay thế.
