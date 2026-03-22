# EConnect Server

Backend FastAPI cho EConnect. Xem hướng dẫn tổng quan tại [README gốc](../README.md).

## Khởi động nhanh

**Trên macOS/Linux:**

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Trên Windows (PowerShell):**

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Nếu local Chrome/web không gọi được backend hoặc bị treo loading do còn process `uvicorn` cũ, chạy từ thư mục repo:

```powershell
.\scripts\start-dev-backend.ps1
```

Swagger UI: http://localhost:8000/docs

## Thiết lập môi trường

- Copy `server/.env.example` thành `server/.env` trước khi chạy backend.
- `server/.env.example` là file mẫu để chia sẻ trong repo.
- `server/.env` chứa secret thực tế và đã được thêm vào `.gitignore`, không commit lên git.
- Trên production nên đổi `JWT_SECRET`, `ADMIN_CREATE_SECRET`, `JOB_SECRET`, tắt mock mode, và cấu hình `CORS_ALLOW_ORIGINS` rõ ràng.
- Đặt `APP_ENV=production` và `STRICT_STARTUP_VALIDATION=true` để backend tự chặn các cấu hình nguy hiểm lúc startup.
- Xem checklist chốt release tại [production-checklist.md](../docs/production-checklist.md).
- Trong `APP_ENV=development`, backend tự động cho phép CORS từ `localhost` và `127.0.0.1` mọi port để phù hợp với Flutter web dev server.

## Cổng thanh toán

Backend hiện tại chỉ sử dụng payOS cho payment flow:

- `POST /payments/class-creation/request` để tạo giao dịch phí tạo lớp
- `POST /payments/classes/{class_id}/join/request` để tạo giao dịch học phí
- `GET /payments/providers/payos/return` cho redirect sau khi người dùng thanh toán
- `POST /payments/providers/payos/webhook` cho webhook xác thực từ payOS
- `POST /payments/providers/payos/confirm-webhook` để admin đăng ký webhook URL với payOS
- `GET /payments/providers/payos/payout-account/balance` để admin kiểm tra số dư payout account
- `GET /notifications/cursor` để client lấy inbox theo cursor-based pagination
- `GET /notifications/unread-count` để badge unread cập nhật riêng
- `WS /notifications/ws?token=...` để app nhận tín hiệu inbox thay đổi theo thời gian thực
- `POST /notifications/push-tokens` để client đăng ký FCM device token
- `POST /notifications/push-tokens/unregister` để client hủy đăng ký token khi logout hoặc token đổi
- `POST /payments/jobs/notify-classes-starting-soon` để scheduler gửi thông báo nhắc lịch cho Tutor và học viên trước khoảng 1 giờ
- `POST /payments/jobs/release-eligible-payouts` để tạo lệnh payout cho tutor sau khi hết cửa sổ khiếu nại
- `POST /payments/jobs/sync-payout-statuses` để đồng bộ các lệnh payout đang xử lý
- `POST /payments/classes/{class_id}/retry-payout` để admin tạo lại payout nếu lần trước bị fail

Ba luồng chính của payment/payout:

```mermaid
flowchart TD
    A[APP: Tutor tạo lớp] --> B[Backend: POST /payments/class-creation/request]
    B --> C[Backend gọi payOS: tạo payment link phí tạo lớp]
    C --> D[APP mở checkout_url]
    D --> E[payOS xử lý thanh toán]
    E --> F[payOS gửi webhook và redirect return_url]
    F --> G[Backend xác minh và cập nhật payment = PAID]
    G --> H[Backend tạo và kích hoạt lớp học]

    I[APP: Student đăng ký lớp] --> J[Backend: POST /payments/classes/{class_id}/join/request]
    J --> K[Backend gọi payOS: tạo payment link học phí]
    K --> L[APP mở checkout_url]
    L --> M[payOS xử lý thanh toán]
    M --> N[payOS gửi webhook và redirect return_url]
    N --> O[Backend xác minh và xác nhận booking]
    O --> P[Backend giữ tiền trong escrow cho tutor]

    P --> Q{Sau 2 giờ kể từ khi lớp kết thúc\nvà không có dispute?}
    Q -->|Có| R[Backend job: release eligible payouts]
    R --> S[Backend gọi payOS: POST /v1/payouts]
    S --> T[Backend lưu payout = PROCESSING]
    T --> U[Backend job: sync payout status]
    U --> V[Backend gọi payOS: GET /v1/payouts/{id}]
    V --> W{Payout thành công?}
    W -->|Có| X[Backend release escrow và đánh dấu tutor = PAID]
    W -->|Không| Y[Backend đánh dấu payout = FAILED]
    Y --> Z[Admin: POST /payments/classes/{class_id}/retry-payout]
```

Cần cấu hình thêm trong `.env`:

```env
JWT_EXPIRE_MINUTES=10080
ALLOW_LEGACY_JWT_SECRET=false
JOB_SECRET=...
APP_ENV=development
STRICT_STARTUP_VALIDATION=false
AUTO_INIT_SCHEMA=true
ALLOW_DIRECT_CLASS_CREATION=false
CORS_ALLOW_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
CORS_ALLOW_ORIGIN_REGEX=
PAYMENT_PUBLIC_BASE_URL=http://127.0.0.1:8000
PAYMENT_GATEWAY_MODE=mock
PAYOS_CLIENT_ID=...
PAYOS_API_KEY=...
PAYOS_CHECKSUM_KEY=...
PAYOS_PARTNER_CODE=...
# tùy chọn
PAYOS_BASE_URL=https://api-merchant.payos.vn
PAYOS_TIMEOUT=60
PAYOS_MAX_RETRIES=2

# payout có thể dùng credential riêng; nếu bỏ trống sẽ fallback sang payment credential
PAYOS_PAYOUT_CLIENT_ID=...
PAYOS_PAYOUT_API_KEY=...
PAYOS_PAYOUT_CHECKSUM_KEY=...
PAYOS_PAYOUT_PARTNER_CODE=...
PAYOS_PAYOUT_BASE_URL=https://api-merchant.payos.vn
PAYOS_PAYOUT_TIMEOUT=60
PAYOS_PAYOUT_MAX_RETRIES=2

# optional: FCM push delivery from backend
FCM_SERVICE_ACCOUNT_PATH=
FCM_SERVICE_ACCOUNT_JSON=
```

### Mock mode

- Khi `PAYMENT_GATEWAY_MODE=mock`, backend sẽ trả `redirect_url` về trang mock checkout nội bộ.
- Trang mock có 2 nút thành công/thất bại và sẽ gọi lại backend như một PSP giả lập.
- Dùng để test end-to-end local cùng client polling mà không cần credential sandbox hay public callback URL.
- Các route mock/manual callback chỉ nên dùng trong mock mode, không mở cho production.

### Lưu ý cho payOS

- Backend đang dùng SDK `payos==1.1.0`.
- `POST /classes` đã bị tắt mặc định để tránh bypass creation fee. Nếu thật sự cần cho dev/test, bật `ALLOW_DIRECT_CLASS_CREATION=true`.
- payOS yêu cầu webhook URL public và cần xác nhận webhook. Có thể gọi `POST /payments/providers/payos/confirm-webhook` bằng token admin để đăng ký webhook URL mặc định (`{PAYMENT_PUBLIC_BASE_URL}/payments/providers/payos/webhook`) hoặc truyền `webhook_url` tùy chọn.
- `transaction_ref` nội bộ của EConnect được giữ nguyên để client poll trạng thái; `orderCode` của payOS được lưu trong `payments.provider_order_id`.
- Payout cho tutor dùng API `POST /v1/payouts` và `GET /v1/payouts/{id}` của payOS. Backend lưu `payout.id` vào `payments.provider_order_id` để job có thể đồng bộ trạng thái payout.
- Tutor cần cập nhật đầy đủ `bank_bin` và `bank_account_number` trong hồ sơ trước khi job payout chạy.
- Nếu payout fail vì thông tin ngân hàng hoặc lỗi tạm thời, admin có thể sửa dữ liệu rồi gọi `POST /payments/classes/{class_id}/retry-payout`.
- Các job endpoint nên được gọi bằng token admin hoặc header `x-job-secret` trùng với `JOB_SECRET`.
- Trong local dev, nên giữ `PAYMENT_GATEWAY_MODE=mock` nếu chưa có HTTPS/public callback URL.
- Khi cấu hình `FCM_SERVICE_ACCOUNT_*`, backend sẽ tự thử gửi FCM sau mỗi lần tạo notification và tự bỏ qua bước này nếu Firebase chưa sẵn sàng.

## Health endpoints

- `GET /health/live` để kiểm tra process và runtime mode
- `GET /health/ready` để kiểm tra database readiness

Khi `APP_ENV=production` và `STRICT_STARTUP_VALIDATION=true`, backend sẽ fail startup nếu:

- `JWT_SECRET`, `ADMIN_CREATE_SECRET`, hoặc `JOB_SECRET` vẫn là giá trị mẫu
- `PAYMENT_GATEWAY_MODE` vẫn là `mock`
- `CORS_ALLOW_ORIGINS=*`
- `PAYMENT_PUBLIC_BASE_URL` hoặc `SERVER_PUBLIC_URL` không phải HTTPS public URL
- `AUTO_INIT_SCHEMA=true`

## Các bước kiểm tra chất lượng

Backend local checks:

```bash
python -m compileall -q server
python scripts/check_backend_imports.py
pytest server/tests -q
```

Flutter local checks:

```bash
cd client
dart analyze
flutter test
```

CI đã được cấu hình tại `.github/workflows/ci.yml` để tự động chạy:

- backend compile
- backend route/module import
- backend integration tests với PostgreSQL
- Flutter analyze và Flutter test
