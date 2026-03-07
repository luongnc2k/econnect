# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EConnect is a tutor-student matching platform (Vietnamese: kết nối gia sư và học viên). It is a monorepo with:
- `client/` — Flutter mobile app
- `server/` — Python FastAPI backend
- `docker/` — Docker Compose for local infrastructure
- `scripts/` — Dev helper scripts

## Commands

### Infrastructure

```bash
# Start PostgreSQL + pgAdmin containers
./scripts/dev-up.sh

# Stop containers
./scripts/dev-down.sh
```

PostgreSQL runs on port `5433`, pgAdmin on port `5050` (credentials: `admin@example.com` / `admin123`).

### Server (Python FastAPI)

```bash
cd server
python3 -m venv venv
source ./venv/bin/activate
pip install -r requirements.txt

# Run with hot reload
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Client (Flutter)

```bash
cd client

# Install dependencies
flutter pub get

# Re-run code generation (after modifying Riverpod providers or models)
flutter pub run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Run tests
flutter test
# Run a single test file
flutter test test/path/to/test_file.dart
```

## Architecture

### Client

Feature-first folder structure under `lib/`:
- `core/` — shared infrastructure: theme, constants, failure model, global providers, utilities
- `features/<feature>/` — each feature has `model/`, `repositories/`, `viewmodel/`, `view/`

**State management:** Riverpod with code generation (`@riverpod` annotations). After modifying providers, run `build_runner build`.

**Error handling:** Functional style using `fpdart` — `Either<AppFailure, T>` returned from repositories and propagated through ViewModels.

**Auth flow:**
1. `main.dart` reads token from `SharedPreferences` on startup and calls `GET /auth/` to restore session
2. Token stored under key `'x-auth-token'`; sent as HTTP header `x-auth-token` on authenticated requests
3. Global user state held in `CurrentUserNotifier` (Riverpod)
4. `AuthLocalRepository` handles token persistence; `AuthRemoteRepository` handles API calls

**Server URL** is defined in `core/constants/server_constant.dart`.

### Server

FastAPI app with SQLAlchemy + PostgreSQL.

- `main.py` — app setup, CORS middleware, router registration
- `database.py` — SQLAlchemy engine + `get_db()` dependency
- `models/` — SQLAlchemy ORM models
- `pydantic_schemas/` — request/response validation schemas
- `routes/` — API routers (currently `auth.py`)
- `middleware/` — JWT verification middleware

**Auth endpoints** (`/auth` prefix):
- `POST /auth/signup` → creates user (role: student | teacher)
- `POST /auth/login` → returns `{token, user}`
- `GET /auth/` → returns current user (requires `x-auth-token` header)
- `POST /auth/create-admin` → creates admin user (requires `x-admin-secret` header)

**Classes endpoints** (`/classes` prefix):
- `GET /classes/upcoming` → upcoming scheduled classes (auth required, optional `?topic=slug`)
- `POST /classes` → create class (teacher only)

**Topics endpoints** (`/topics` prefix):
- `GET /topics` → list active topics (public)
- `POST /topics` → create topic (admin only)

**Upload endpoints** (`/upload` prefix):
- `POST /upload/thumbnail` → upload class thumbnail to MinIO, returns URL (≤ 5MB)
- `POST /upload/avatar` → upload user avatar to MinIO + update users.avatar_url in DB (≤ 2MB)

**File storage:** MinIO (S3-compatible). Buckets: `class-thumbnails`, `user-avatars`. Both public-read.

Passwords are bcrypt-hashed. JWT payload contains `{'id': user_id}`.
