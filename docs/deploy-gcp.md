# Deploy EConnect Server lên Google Cloud

## Kiến trúc mục tiêu

```
Flutter Client
      | HTTPS
      v
[Cloud Run - FastAPI]  ←  GitHub Actions CI/CD
   (stateless, auto-scale)
      |           |
      v           v
[Cloud SQL    [Google Cloud
 PostgreSQL]   Storage (GCS)]

Secrets: Secret Manager
Logs: Cloud Logging
Monitoring: Cloud Monitoring
```

---

## Giai đoạn 1 — Nền tảng GCP

### 1.1 Tạo GCP Project

- [x] Tạo project `econnect-prod` trên Google Cloud Console
- [x] Enable các APIs:
  - Cloud Run API
  - Cloud SQL Admin API
  - Cloud Storage API
  - Secret Manager API
  - Artifact Registry API
  - IAM API

### 1.2 Tạo Service Account cho Cloud Run

- [x] Tạo service account: `econnect-server@econnect-prod.iam.gserviceaccount.com`
- [x] Gán roles:
  - `roles/cloudsql.client`
  - `roles/storage.objectAdmin`
  - `roles/secretmanager.secretAccessor`

### 1.3 Cloud SQL (PostgreSQL)

- [x] Tạo Cloud SQL instance:
  - Engine: PostgreSQL 16
  - Instance ID: `econnect-db`
  - Region: `asia-southeast1` (Singapore)
  - Machine type: `db-g1-small`, edition: ENTERPRISE
  - Storage: SSD, 10GB, bật auto-resize
- [x] Tạo database: `econnectdb`
- [x] Tạo user DB với strong password
- [ ] Test kết nối local qua Cloud SQL Auth Proxy:
  ```bash
  ./cloud-sql-proxy econnect-prod:asia-southeast1:econnect-db --port 5433
  ```

### 1.4 Google Cloud Storage

- [x] Tạo bucket `econnect-class-thumbnails` — public read
- [x] Tạo bucket `econnect-user-avatars` — public read
- [x] Tạo bucket `econnect-teacher-docs` — private (dùng Signed URLs)
- [ ] Tạo bucket `econnect-class-materials` — private hoặc signed/public theo chính sách tài liệu lớp
- [x] Set IAM cho 2 bucket public: thêm `allUsers` với role `Storage Object Viewer`

### 1.5 Secret Manager

- [x] Lưu các secrets:
  ```bash
  echo -n "..." | gcloud secrets create JWT_SECRET --data-file=-
  echo -n "..." | gcloud secrets create DATABASE_URL --data-file=-
  echo -n "..." | gcloud secrets create ADMIN_CREATE_SECRET --data-file=-
  ```
- [x] Format `DATABASE_URL` cho Cloud SQL Unix socket:
  ```
  postgresql+psycopg2://USER:PASS@/econnectdb?host=/cloudsql/econnect-prod:asia-southeast1:econnect-db
  ```

---

## Giai đoạn 2 — Code Changes

### 2.1 Tạo Dockerfile

**File**: `server/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**File**: `server/.dockerignore`

```
venv/
__pycache__/
*.pyc
*.pyo
uploads/
.env
.pytest_cache/
```

- [ ] Tạo `server/Dockerfile`
- [ ] Tạo `server/.dockerignore`
- [ ] Build thử local: `docker build -t econnect-server ./server`

### 2.2 Refactor MinIO → Google Cloud Storage

Vấn đề: `minio_client.py` có fallback `_local_upload()` lưu file vào disk — sẽ mất khi Cloud Run restart.

- [ ] Thêm `google-cloud-storage` vào `server/requirements.txt`
- [ ] Xóa `minio` khỏi `requirements.txt`
- [ ] Viết lại `server/minio_client.py` → `server/gcs_client.py`:
  - Thay `minio.Minio` bằng `google.cloud.storage.Client`
  - Xóa hoàn toàn `_local_upload()` fallback
  - Trả về public URL dạng `https://storage.googleapis.com/BUCKET/FILENAME`
- [ ] Cập nhật `server/routes/upload.py`: đổi import từ `minio_client` sang `gcs_client`

### 2.3 Cập nhật main.py

- [x] Không mount StaticFiles trong production:
  ```python
  if app_environment() != "production":
      app.mount("/static", StaticFiles(directory=uploads_dir), name="static")
  ```
- [ ] Thu hẹp CORS `allow_origins`:
  ```python
  allow_origins=[
      "https://econnect.vn",
      # thêm domain thực tế
  ]
  ```
  > Lưu ý: Flutter mobile app không bị ảnh hưởng bởi CORS, chỉ cần cấu hình cho web.

### 2.4 Kiểm tra Secrets

- [ ] Rà soát tất cả `os.getenv()` trong `server/`: đảm bảo không có hardcoded fallback password/secret
- [ ] Thêm validation khi startup — raise lỗi rõ ràng nếu thiếu biến bắt buộc:
  ```python
  import os, sys
  required_envs = ["JWT_SECRET", "DATABASE_URL"]
  for env in required_envs:
      if not os.getenv(env):
          sys.exit(f"ERROR: Missing required environment variable: {env}")
  ```

---

## Giai đoạn 3 — CI/CD

### Trạng thái deploy tự động

Repo hiện có workflow GitHub Actions `.github/workflows/deploy-server.yml` để tự động deploy backend lên Google Cloud Run.

- Workflow chỉ chạy khi `push` vào branch `main`.
- Workflow chỉ chạy nếu thay đổi nằm trong `server/**` hoặc `.github/workflows/deploy-server.yml`.
- Push lên branch khác, ví dụ `feature/payment`, hoặc chỉ mở pull request sẽ không tự deploy production.
- Target deploy:
  - Project: `econnect-prod`
  - Region: `asia-southeast1`
  - Cloud Run service: `econnect-server`
  - Artifact Registry image: `asia-southeast1-docker.pkg.dev/econnect-prod/econnect/server`
- Workflow cần GitHub Secrets `WIF_PROVIDER` và `WIF_SERVICE_ACCOUNT` để đăng nhập GCP bằng Workload Identity Federation.
- Lần deploy thành công gần nhất được ghi nhận: `2026-04-06 18:42 UTC`.
- Lần deploy mới nhất được kiểm tra: `2026-04-27 15:04 UTC`, fail tại step `Deploy to Cloud Run`.
- Nguyên nhân code đã phát hiện sau run fail: backend không import/startup được do `server/main.py` thiếu import `Path`/`StaticFiles`, và `server/routes/upload.py` import `upload_class_material` nhưng `server/gcs_client.py` chưa định nghĩa hàm này.
- Workflow hiện có bước `Validate backend startup imports` trước khi build/push image để bắt sớm nhóm lỗi import/startup tương tự.
- Workflow dùng `--update-env-vars` để đặt `APP_ENV=production`, `STRICT_STARTUP_VALIDATION=false`, `GCS_FORCE_REMOTE=true` cho Cloud Run mà không xóa các biến môi trường khác.
- Workflow dùng `--update-secrets` thay cho `--set-secrets` để không xóa các secret đã cấu hình ngoài workflow.
- Workflow thủ công `.github/workflows/configure-cloud-run-domain.yml` dùng cùng Workload Identity Federation để tạo/kiểm tra domain mapping `api.econnect.vn` và in ra DNS records cần cấu hình.

### 3.1 Artifact Registry

- [x] Tạo Artifact Registry repository:
  ```bash
  gcloud artifacts repositories create econnect \
    --repository-format=docker \
    --location=asia-southeast1
  ```

### 3.2 GitHub Actions Workflow

**File**: `.github/workflows/deploy-server.yml`

```yaml
name: Deploy Server

on:
  push:
    branches: [main]
    paths:
      - 'server/**'
      - '.github/workflows/deploy-server.yml'

env:
  PROJECT_ID: econnect-prod
  REGION: asia-southeast1
  SERVICE: econnect-server
  IMAGE: asia-southeast1-docker.pkg.dev/econnect-prod/econnect/server

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # cho Workload Identity Federation

    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2

      - run: gcloud auth configure-docker asia-southeast1-docker.pkg.dev

      - name: Build and push
        run: |
          docker build -t $IMAGE:$GITHUB_SHA ./server
          docker push $IMAGE:$GITHUB_SHA

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy $SERVICE \
            --image $IMAGE:$GITHUB_SHA \
            --region $REGION \
            --platform managed \
            --service-account econnect-server@$PROJECT_ID.iam.gserviceaccount.com \
            --add-cloudsql-instances $PROJECT_ID:$REGION:econnect-db \
            --update-env-vars="APP_ENV=production,STRICT_STARTUP_VALIDATION=false,GCS_FORCE_REMOTE=true,GCS_PROJECT=$PROJECT_ID,SERVER_PUBLIC_URL=https://api.econnect.vn,PAYMENT_PUBLIC_BASE_URL=https://api.econnect.vn" \
            --update-secrets="JWT_SECRET=JWT_SECRET:latest,DATABASE_URL=DATABASE_URL:latest,ADMIN_CREATE_SECRET=ADMIN_CREATE_SECRET:latest" \
            --allow-unauthenticated \
            --min-instances 0 \
            --max-instances 10
```

- [x] Tạo file workflow
- [x] Setup Workload Identity Federation (thay vì dùng service account JSON key):
  ```bash
  gcloud iam workload-identity-pools create github-pool \
    --location global \
    --display-name "GitHub Actions Pool"
  ```
- [x] Thêm `WIF_PROVIDER` và `WIF_SERVICE_ACCOUNT` vào GitHub Secrets

### 3.3 Deploy Lần Đầu (Thủ công)

- [ ] Build và push image thủ công:
  ```bash
  cd server
  docker build -t asia-southeast1-docker.pkg.dev/econnect-prod/econnect/server:v1 .
  docker push asia-southeast1-docker.pkg.dev/econnect-prod/econnect/server:v1
  ```
- [ ] Deploy:
  ```bash
  gcloud run deploy econnect-server \
    --image asia-southeast1-docker.pkg.dev/econnect-prod/econnect/server:v1 \
    --region asia-southeast1 \
    --add-cloudsql-instances econnect-prod:asia-southeast1:econnect-db \
    --update-env-vars="APP_ENV=production,STRICT_STARTUP_VALIDATION=false,GCS_FORCE_REMOTE=true,GCS_PROJECT=econnect-prod,SERVER_PUBLIC_URL=https://api.econnect.vn,PAYMENT_PUBLIC_BASE_URL=https://api.econnect.vn" \
    --update-secrets="JWT_SECRET=JWT_SECRET:latest,DATABASE_URL=DATABASE_URL:latest,ADMIN_CREATE_SECRET=ADMIN_CREATE_SECRET:latest" \
    --service-account econnect-server@econnect-prod.iam.gserviceaccount.com \
    --allow-unauthenticated
  ```
- [ ] Smoke test:
  - `GET /docs` → FastAPI Swagger UI
  - `POST /auth/signup` → tạo user mới
  - `POST /auth/login` → đăng nhập
  - `POST /upload/thumbnail` → upload file lên GCS

---

## Giai đoạn 4 — Hardening

### 4.1 Custom Domain

- [ ] Chạy workflow thủ công **Configure Cloud Run Domain** trên GitHub Actions để tạo domain mapping `api.econnect.vn` và in DNS records cần cấu hình.
- [ ] Hoặc map domain bằng local `gcloud` đã đăng nhập:
  ```bash
  gcloud components install beta
  gcloud beta run domain-mappings create \
    --project econnect-prod \
    --service econnect-server \
    --domain api.econnect.vn \
    --region asia-southeast1 \
    --platform managed

  gcloud beta run domain-mappings describe api.econnect.vn \
    --project econnect-prod \
    --region asia-southeast1 \
    --platform managed \
    --format="yaml(status.conditions,status.resourceRecords)"
  ```
- [ ] Trong DNS provider của `econnect.vn`, xóa record hiện tại `api.econnect.vn A 103.75.187.242`.
- [ ] Thêm đúng DNS record được in trong `status.resourceRecords` của workflow/lệnh `describe`. Với subdomain, Cloud Run thường yêu cầu CNAME tới Google host, nhưng ưu tiên tuyệt đối record được Google trả về.
- [ ] Chờ DNS/certificate được provision rồi smoke test:
  ```bash
  curl -I https://api.econnect.vn/health/live
  curl https://api.econnect.vn/health/live
  ```
- [ ] Cập nhật `SERVER_URL` trong Flutter client (`client/lib/core/constants/server_constant.dart`)

### 4.2 Monitoring & Alerting

- [ ] Tạo Alerting Policy: error rate > 5% trong 5 phút
- [ ] Tạo Alerting Policy: Cloud SQL disk usage > 80%
- [ ] Tạo Uptime Check cho endpoint `/docs`
- [ ] (Tùy chọn) Tạo Cloud Monitoring Dashboard

### 4.3 Security Review

- [ ] Kiểm tra `LEGACY_JWT_SECRET` trong `middleware/auth_middleware.py` — xem xét xóa sau khi tất cả users đã re-login
- [ ] Đảm bảo bucket `econnect-teacher-docs` không public
- [ ] Bật Cloud Armor nếu cần rate limiting / DDoS protection
- [ ] Review Cloud Run `--min-instances` và `--max-instances` theo traffic thực tế

---

## Ước tính Chi phí (asia-southeast1)

| Dịch vụ | Cấu hình | Chi phí/tháng |
|---|---|---|
| Cloud Run | ~100K requests | ~0-5 USD |
| Cloud SQL | db-f1-micro, 10GB SSD | ~10-15 USD |
| Cloud Storage | 10GB storage + egress | ~1-2 USD |
| Secret Manager | <10 secrets | <1 USD |
| **Tổng** | | **~12-23 USD** |

---

## Tham khảo

- [Cloud Run docs](https://cloud.google.com/run/docs)
- [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Workload Identity Federation cho GitHub](https://cloud.google.com/blog/products/identity-security/enabling-keyless-authentication-from-github-actions)
- [GCS Python client](https://cloud.google.com/storage/docs/reference/libraries#client-libraries-usage-python)
