# Checklist Production EConnect

Checklist này dùng để chốt release cho cả backend, mobile app, và luồng payment/payout.

## 1. Secret và môi trường

- [ ] `APP_ENV=production`
- [ ] `STRICT_STARTUP_VALIDATION=true`
- [ ] `JWT_SECRET` đã đổi khỏi giá trị mặc định và dài tối thiểu 32 ký tự
- [ ] `ADMIN_CREATE_SECRET` và `JOB_SECRET` đã đổi khỏi giá trị mẫu
- [ ] `DATABASE_URL` đang trỏ tới production database đúng
- [ ] `PAYMENT_GATEWAY_MODE=live` hoặc giá trị production tương đương, không còn mock
- [ ] `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY` đã được cấp đúng
- [ ] `PAYOS_PAYOUT_CLIENT_ID`, `PAYOS_PAYOUT_API_KEY`, `PAYOS_PAYOUT_CHECKSUM_KEY` đã được cấp đúng cho kênh payout
- [ ] `PAYMENT_PUBLIC_BASE_URL` là HTTPS public URL đúng
- [ ] `SERVER_PUBLIC_URL` là HTTPS public URL đúng
- [ ] `STATIC_PUBLIC_URL` đã được cấu hình đúng nếu backend còn fallback sang local `/static/...`
- [ ] `CORS_ALLOW_ORIGINS` chỉ chứa các domain frontend thực tế, không dùng `*`
- [ ] `AUTO_INIT_SCHEMA=false` trên production

## 2. Database và storage

- [ ] Đã chạy migration/schema update có kiểm soát trước khi rollout
- [ ] Backup database gần nhất đã sẵn sàng và đã test restore
- [ ] `MINIO_*` hoặc storage production đã cấu hình đúng
- [ ] Quy trình xóa/ghi avatar, teacher documents, và thumbnails đã test trên storage thật

## 3. Backend sẵn sàng vận hành

- [ ] `python -m compileall -q server`
- [ ] `python scripts/check_backend_imports.py`
- [ ] `pytest server/tests -q`
- [ ] `/health/live` trả `200`
- [ ] `/health/ready` trả `200`
- [ ] Login không lộ thông tin phân biệt email tồn tại hay sai mật khẩu
- [ ] Public profile/search không lộ email, số điện thoại, bank info, verification docs
- [ ] Job endpoint chỉ gọi được bằng admin token hoặc `x-job-secret`
- [ ] Mock payment routes không mở trên production

## 4. payOS payment và payout

- [ ] Đã gọi `POST /payments/providers/payos/confirm-webhook` cho public webhook URL
- [ ] Đã test creation fee payment end-to-end với payOS thật
- [ ] Đã test student tuition payment end-to-end với payOS thật
- [ ] Đã test poll status và webhook idempotency cho giao dịch thành công/thất bại
- [ ] Đã test payout balance endpoint với credential production
- [ ] Đã test release payout cho tutor có `bank_bin` và `bank_account_number`
- [ ] Đã test `sync-payout-statuses` và `retry-payout`
- [ ] IP public outbound của backend đã được thêm vào `my.payos.vn > Kênh chuyển tiền > Quản lý IP` cho các API payout thật và verify tài khoản ngân hàng
- [ ] Đã có quy trình đối soát `transaction_ref` và `provider_order_id`

## 5. Phát hành mobile app

- [ ] Release build truyền `--dart-define=SERVER_URL=https://api.your-domain.com`
- [ ] Release build không còn `ENABLE_MANUAL_TEST_MOCKS=true`
- [ ] `dart analyze`
- [ ] `flutter test`
- [ ] Đã test login, search, public profile, payment, profile edit trên build release/staging
- [ ] Đã test app trên Android/iOS với backend production-like

## 6. Quan sát hệ thống và vận hành

- [ ] Log aggregation/monitoring đã sẵn sàng
- [ ] Alert cho `/health/ready` và lỗi payment/payout đã được cấu hình
- [ ] Có dashboard hoặc query để theo dõi creation fee, tuition, escrow, payout
- [ ] Có runbook cho lỗi webhook, payout fail, và DB outage

## 7. Go/No-Go

- [ ] Có người chịu trách nhiệm rollout
- [ ] Có cửa sổ rollback và rollback plan
- [ ] Có người trực sau release cho payment/payout
- [ ] Đã chốt “go” sau khi hoàn thành tất cả mục bắt buộc bên trên
