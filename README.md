# EConnect

Nền tảng kết nối gia sư và học viên cho các lớp tiếng Anh offline.

## Cấu trúc monorepo

```
econnect/
├── client/      # Ứng dụng Flutter (Android/iOS)
├── server/      # Backend FastAPI bằng Python
├── docker/      # Docker Compose (PostgreSQL, pgAdmin, MinIO)
├── scripts/     # Script hỗ trợ phát triển
└── docs/        # Tài liệu thiết kế và ERD
```

## Tài liệu

- [Tương tác admin với hệ thống](docs/admin-operations.md)
- [Checklist production](docs/production-checklist.md)
- [Điều hướng client](docs/routing.md)
- [ERD](docs/erd.md)

---

## Yêu cầu

- Flutter SDK ≥ 3.x
- Python 3.11+
- Docker và Docker Compose

---

## Khởi động local

### 1. Hạ tầng

```bash
# Khởi động PostgreSQL + pgAdmin + MinIO
./scripts/dev-up.sh

# Dừng
./scripts/dev-down.sh
```

| Dịch vụ | URL | Thông tin đăng nhập |
|---|---|---|
| PostgreSQL | `localhost:5433` | `postgres` / `123456a@` |
| pgAdmin | http://localhost:5050 | `admin@example.com` / `admin123` |
| MinIO API | `localhost:9000` | `minioadmin` / `minioadmin123` |
| MinIO UI | http://localhost:9001 | `minioadmin` / `minioadmin123` |

### 2. Server

```bash
cd server

# Tạo và kích hoạt virtual environment
python3 -m venv venv
source venv/bin/activate          # Linux/macOS
# .\venv\Scripts\Activate       # Windows

# Cài dependencies
pip install -r requirements.txt

# Cấu hình môi trường
cp .env.example .env

# Chạy server (hot reload)
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Trên Windows, nếu local web/Chrome bị treo vì còn `uvicorn` cũ chiếm cổng `8000`, dùng script clean start:

```powershell
.\scripts\start-dev-backend.ps1
```

Server sẵn sàng tại `http://localhost:8000`, Swagger UI tại `http://localhost:8000/docs`.

Một vài cấu hình backend quan trọng bạn sẽ hay chỉnh trong `server/.env`:

- `INTERNAL_JOB_RUNNER_ENABLED` và `INTERNAL_JOB_RUNNER_INTERVAL_SECONDS`: bật và điều chỉnh chu kỳ chạy các job nền.
- `CANCEL_UNDERFILLED_CLASSES_HOURS`: mốc hệ thống tự hủy lớp thiếu học viên trước giờ bắt đầu. Mặc định là `4`.
- `ALLOW_DIRECT_CLASS_CREATION`: mặc định `false` để tránh bypass luồng thu creation fee.

Chi tiết đầy đủ hơn xem ở [server/README.md](server/README.md) và [Hướng dẫn setup local với payOS](docs/setup_guide.md).

**Reset database** (xóa toàn bộ bảng và tạo lại schema):

```bash
# Kết nối vào PostgreSQL container
docker exec -it econnect-postgres psql -U postgres -d econnect

-- Xóa toàn bộ bảng trong schema public
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
\q

# Khởi động lại server để SQLAlchemy tự tạo lại các bảng
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Hoặc dùng Python**: bỏ comment dòng `drop_all` trong `server/main.py`:

```python
# server/main.py
Base.metadata.drop_all(bind=engine)   # ← bỏ comment dòng này
Base.metadata.create_all(bind=engine)
```

Khởi động server một lần để drop và recreate, sau đó **comment lại ngay** để tránh mất dữ liệu mỗi lần restart.

> **Cảnh báo:** Các cách trên sẽ xóa toàn bộ dữ liệu và không thể khôi phục. Chỉ dùng trong môi trường dev.

**Seed dữ liệu mẫu** (chạy sau khi server đã khởi động lần đầu):

```bash
python seed.py
```

Seed tạo: 1 admin, 2 giáo viên, 5 topic, 4 lớp học sắp diễn ra.

### 3. Client

```bash
cd client

flutter pub get

# Sau khi sửa Riverpod providers hoặc models
flutter pub run build_runner build --delete-conflicting-outputs

flutter run

# Bật mock test thủ công khi cần
flutter run --dart-define=ENABLE_MANUAL_TEST_MOCKS=true

# Android emulator local server
# App se mac dinh dung 10.0.2.2 neu khong truyen SERVER_URL,
# nhung ban van co the set ro rang nhu ben duoi
flutter run --dart-define=SERVER_URL=http://10.0.2.2:8000

# May that / thiet bi khac cung mang LAN
flutter run --dart-define=SERVER_URL=http://<LAN_IP_CUA_MAY_DEV>:8000

# Ví dụ chạy client có bật FCM trên Android/iOS
flutter run \
  --dart-define=FCM_API_KEY=... \
  --dart-define=FCM_PROJECT_ID=... \
  --dart-define=FCM_MESSAGING_SENDER_ID=... \
  --dart-define=FCM_ANDROID_APP_ID=... \
  --dart-define=FCM_IOS_APP_ID=... \
  --dart-define=FCM_IOS_BUNDLE_ID=com.example.client
```

---

## API

### Auth — `/auth`

| Method | Endpoint | Xác thực | Mô tả |
|---|---|---|---|
| POST | `/auth/signup` | — | Đăng ký (`student` / `teacher`) |
| POST | `/auth/login` | — | Đăng nhập, trả về token |
| GET | `/auth/` | ✓ | Lấy thông tin user hiện tại |
| POST | `/auth/create-admin` | secret key | Tạo tài khoản admin |

> `POST /auth/create-admin` yêu cầu header `x-admin-secret: <ADMIN_CREATE_SECRET>` từ `.env`.

### Classes — `/classes`

| Method | Endpoint | Xác thực | Role | Mô tả |
|---|---|---|---|---|
| GET | `/classes/upcoming` | ✓ | any | Buổi học sắp diễn ra, hỗ trợ filter theo `?topic=slug` |
| POST | `/classes` | ✓ | teacher | Tạo buổi học mới |

### Topics — `/topics`

| Method | Endpoint | Xác thực | Role | Mô tả |
|---|---|---|---|---|
| GET | `/topics` | — | — | Danh sách topic đang active |
| POST | `/topics` | ✓ | admin | Tạo topic mới |

### Upload — `/upload`

| Method | Endpoint | Xác thực | Mô tả |
|---|---|---|---|
| POST | `/upload/thumbnail` | ✓ | Upload thumbnail buổi học (≤ 5MB) và trả về URL |
| POST | `/upload/avatar` | ✓ | Upload avatar người dùng (≤ 2MB) và lưu vào DB |

---

## Kiến trúc

### Client

Cấu trúc feature-first dưới `lib/`:

```
lib/
├── core/                  # theme, constants, providers, utils
└── features/
    └── <feature>/
        ├── model/         # data models + mappers
        ├── repositories/  # remote/local data sources
        ├── viewmodel/     # Riverpod notifiers
        └── view/          # screens + widgets
```

- **State management:** Riverpod (`NotifierProvider`, `@riverpod` code-gen)
- **Xử lý lỗi:** `fpdart` với `Either<AppFailure, T>`
- **Auth:** token lưu trong `SharedPreferences`, gửi qua header `x-auth-token`

### Server

```
server/
├── main.py               # app entry, router registration
├── database.py           # SQLAlchemy engine + session
├── seed.py               # script seed dữ liệu
├── minio_client.py       # helper upload MinIO
├── models/               # SQLAlchemy ORM models
├── pydantic_schemas/     # schema request/response
├── routes/               # API routers
└── middleware/           # JWT auth middleware
```

- **ORM:** SQLAlchemy + PostgreSQL
- **Auth:** JWT (HS256), bcrypt password hashing
- **Lưu trữ file:** MinIO (tương thích S3)
