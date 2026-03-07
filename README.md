# EConnect

Nền tảng kết nối gia sư và học viên — offline English classes.

## Monorepo structure

```
econnect/
├── client/      # Flutter mobile app (Android/iOS)
├── server/      # Python FastAPI backend
├── docker/      # Docker Compose (PostgreSQL, pgAdmin, MinIO)
├── scripts/     # Dev helper scripts
└── docs/        # ERD and design documents
```

---

## Yêu cầu

- Flutter SDK ≥ 3.x
- Python 3.11+
- Docker & Docker Compose

---

## Khởi động local

### 1. Infrastructure

```bash
# Khởi động PostgreSQL + pgAdmin + MinIO
./scripts/dev-up.sh

# Dừng
./scripts/dev-down.sh
```

| Service    | URL                          | Credentials                          |
|------------|------------------------------|--------------------------------------|
| PostgreSQL | `localhost:5433`             | `postgres` / `123456a@`              |
| pgAdmin    | http://localhost:5050        | `admin@example.com` / `admin123`     |
| MinIO API  | `localhost:9000`             | `minioadmin` / `minioadmin123`       |
| MinIO UI   | http://localhost:9001        | `minioadmin` / `minioadmin123`       |

### 2. Server

```bash
cd server

# Tạo và kích hoạt virtual environment
python3 -m venv venv
source venv/bin/activate          # Linux/macOS
# .\venv\Scripts\Activate         # Windows

# Cài dependencies
pip install -r requirements.txt

# Cấu hình môi trường
cp .env.example .env              # chỉnh sửa nếu cần

# Chạy server (hot reload)
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Server sẵn sàng tại `http://localhost:8000` — Swagger UI tại `http://localhost:8000/docs`.

**Seed dữ liệu mẫu** (chạy sau khi server đã khởi động lần đầu):

```bash
python seed.py
```

Seed tạo: 1 admin, 2 giáo viên, 5 topics, 4 lớp học sắp diễn ra.

### 3. Client

```bash
cd client

flutter pub get

# Sau khi sửa Riverpod providers hoặc models
flutter pub run build_runner build --delete-conflicting-outputs

flutter run
```

---

## API

### Auth — `/auth`

| Method | Endpoint              | Auth | Mô tả                          |
|--------|-----------------------|------|--------------------------------|
| POST   | `/auth/signup`        | —    | Đăng ký (student / teacher)    |
| POST   | `/auth/login`         | —    | Đăng nhập, trả về token        |
| GET    | `/auth/`              | ✓    | Lấy thông tin user hiện tại    |
| POST   | `/auth/create-admin`  | secret key | Tạo tài khoản admin    |

> `POST /auth/create-admin` yêu cầu header `x-admin-secret: <ADMIN_CREATE_SECRET>` từ `.env`.

### Classes — `/classes`

| Method | Endpoint              | Auth | Role    | Mô tả                         |
|--------|-----------------------|------|---------|-------------------------------|
| GET    | `/classes/upcoming`   | ✓    | any     | Lớp sắp diễn ra (filter theo `?topic=slug`) |
| POST   | `/classes`            | ✓    | teacher | Tạo lớp học mới               |

### Topics — `/topics`

| Method | Endpoint    | Auth | Role  | Mô tả                  |
|--------|-------------|------|-------|------------------------|
| GET    | `/topics`   | —    | —     | Danh sách topic active |
| POST   | `/topics`   | ✓    | admin | Tạo topic mới          |

### Upload — `/upload`

| Method | Endpoint            | Auth | Mô tả                         |
|--------|---------------------|------|-------------------------------|
| POST   | `/upload/thumbnail` | ✓    | Upload ảnh thumbnail (≤ 5MB)  |

---

## Architecture

### Client

Feature-first folder structure dưới `lib/`:

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
- **Error handling:** `fpdart` — `Either<AppFailure, T>`
- **Auth:** token lưu trong `SharedPreferences`, gửi qua header `x-auth-token`

### Server

```
server/
├── main.py               # app entry, router registration
├── database.py           # SQLAlchemy engine + session
├── seed.py               # seed data script
├── minio_client.py       # MinIO upload helper
├── models/               # SQLAlchemy ORM models
├── pydantic_schemas/     # request/response schemas
├── routes/               # API routers
└── middleware/           # JWT auth middleware
```

- **ORM:** SQLAlchemy + PostgreSQL
- **Auth:** JWT (HS256), bcrypt password hashing
- **File storage:** MinIO (S3-compatible)
