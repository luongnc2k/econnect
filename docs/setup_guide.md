# Hướng Dẫn Setup Local Test EConnect Với payOS Thật

Tài liệu này mô tả cách chạy EConnect trên máy local nhưng vẫn tương tác thật với payOS để test end-to-end các luồng thanh toán.

## 1. Mục tiêu

Setup này được dùng khi bạn muốn:

- backend vẫn chạy trên máy local của bạn
- Flutter app vẫn gọi backend local bằng `SERVER_URL`
- chỉ riêng payOS mới đi qua một URL HTTPS public để webhook và return callback quay lại máy local

## 2. Điều kiện cần trước khi bắt đầu

Bạn nên chuẩn bị sẵn:

- backend local chạy được ở cổng `8000`
- PostgreSQL local hoặc Docker stack của repo đã sẵn sàng
- `ngrok` đã được cài
- tài khoản `ngrok` đã verify email
- `ngrok authtoken` đã được cài vào máy
- credential payOS thật cho payment gồm `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY`
- `PAYOS_PARTNER_CODE` chỉ khi merchant của bạn thật sự có partner code từ chương trình đối tác tích hợp payOS

Nếu bạn chỉ muốn test payment flow trước, nên giữ payout ở mock mode.
`ngrok` chỉ giúp webhook/return của payOS callback về local. Các API payout thật như verify tài khoản ngân hàng, payout balance, create payout, và sync payout vẫn dùng IP public outbound của backend.

## 3. Tạo file môi trường cho local + payOS thật

Khuyến nghị dùng file mẫu có sẵn của repo:

```powershell
Copy-Item server/.env.payos-ngrok.sample server/.env
```

Sau đó kiểm tra lại `server/.env`.

Các giá trị quan trọng:

```env
APP_ENV=development
PAYMENT_GATEWAY_MODE=payos
PAYOS_MOCK_MODE=false
PAYOS_PAYOUT_MOCK_MODE=true
ALLOW_DIRECT_CLASS_CREATION=false
SERVER_PUBLIC_URL=https://<NGROK_URL>
PAYMENT_PUBLIC_BASE_URL=https://<NGROK_URL>
STATIC_PUBLIC_URL=http://127.0.0.1:8000
PAYOS_CLIENT_ID=...
PAYOS_API_KEY=...
PAYOS_CHECKSUM_KEY=...
PAYOS_PARTNER_CODE=
```

Lưu ý:

- `DATABASE_URL` phải đúng với máy bạn. Với `docker/compose.dev.yml` mặc định của repo, PostgreSQL đang publish ở `localhost:5433`.
- `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` phải là URL HTTPS public thật.
- `STATIC_PUBLIC_URL` nên là địa chỉ mà client thực tế dùng để tải `/static/...`.
- nếu mới test payment flow, hãy giữ `PAYOS_PAYOUT_MOCK_MODE=true`.

## 4. Khởi động hạ tầng local

Nếu bạn dùng stack Docker của repo:

```powershell
docker compose -f docker/compose.dev.yml up -d
```

Nếu bạn đang dùng shell hỗ trợ script `.sh`, có thể dùng script có sẵn:

```powershell
bash ./scripts/dev-up.sh
```

Sau đó chạy backend:

```powershell
cd server
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Nếu backend local bị treo vì còn process `uvicorn` cũ, có thể chạy:

```powershell
.\scripts\start-dev-backend.ps1
```

Swagger UI nằm ở `http://localhost:8000/docs`.

## 5. Mở tunnel HTTPS cho backend local

Mở một terminal khác và chạy:

```powershell
ngrok http 8000
```

`ngrok` sẽ trả về một URL kiểu:

```text
https://abc123.ngrok-free.app
```

Copy URL này và gán cùng giá trị đó cho cả:

- `SERVER_PUBLIC_URL`
- `PAYMENT_PUBLIC_BASE_URL`

Riêng `STATIC_PUBLIC_URL`, hãy đặt theo đúng địa chỉ mà app thực tế dùng để tải file từ backend:

- `http://127.0.0.1:8000` khi Flutter web hoặc simulator chạy cùng máy
- `http://10.0.2.2:8000` với Android emulator
- `http://<LAN_IP_CUA_MAY_DEV>:8000` với máy thật cùng mạng

Sau khi sửa `.env`, restart backend.

## 6. Tạo admin và lấy token

Nếu chưa có admin, tạo tài khoản admin đầu tiên:

```powershell
$baseUrl = "http://127.0.0.1:8000"
$adminSecret = "<ADMIN_CREATE_SECRET_TRONG_ENV>"

$createAdminBody = @{
  full_name = "System Admin"
  email = "admin@example.com"
  password = "Admin12345"
  role = "teacher"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/auth/create-admin" `
  -Headers @{ "x-admin-secret" = $adminSecret } `
  -ContentType "application/json" `
  -Body $createAdminBody
```

Đăng nhập để lấy token:

```powershell
$loginBody = @{
  email = "admin@example.com"
  password = "Admin12345"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/auth/login" `
  -ContentType "application/json" `
  -Body $loginBody

$token = $loginResponse.token
$authHeader = @{ "x-auth-token" = $token }
```

## 7. Confirm webhook với payOS

Sau khi backend đã có URL public từ `ngrok`, admin cần confirm webhook:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/providers/payos/confirm-webhook" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body "{}"
```

Bạn chỉ cần confirm lại khi:

- lần đầu setup payOS thật
- URL `ngrok` thay đổi
- đổi merchant payOS

## 8. Chạy client nhưng vẫn trỏ về backend local

Flutter app không nên gọi API qua `ngrok`. App vẫn gọi backend local bằng `SERVER_URL`.

Ví dụ:

```powershell
# Android emulator
flutter run --dart-define=SERVER_URL=http://10.0.2.2:8000

# Flutter web hoặc simulator chạy cùng máy
flutter run --dart-define=SERVER_URL=http://127.0.0.1:8000

# Máy thật cùng mạng LAN
flutter run --dart-define=SERVER_URL=http://<LAN_IP_CUA_MAY_DEV>:8000
```

Điểm quan trọng:

- `SERVER_URL` là địa chỉ local hoặc LAN để app nói chuyện với backend
- `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` là URL public để payOS callback về
- `STATIC_PUBLIC_URL` là base URL backend dùng để sinh link `/static/...` khi upload local fallback, và nên trùng với `SERVER_URL` mà client truy cập được
- nếu URL `ngrok` đổi, bạn phải restart backend và confirm webhook lại

## 9. Seed dữ liệu mẫu nếu cần

Nếu bạn cần dữ liệu nền như topic, location, teacher mẫu:

```powershell
cd server
python seed.py
```

`seed.py` hiện tạo sẵn 2 teacher mẫu có thông tin payout:

- `alexander@example.com` / `password123`
- `sarah@example.com` / `password123`

`seed.py` không tạo sẵn student. Để test luồng học viên, bạn có thể đăng ký mới trên app hoặc gọi `POST /auth/signup` với `role=student`.

## 10. Checklist test các tính năng chính của EConnect

Quy trình test gợi ý:

1. Đăng nhập bằng `teacher` và tạo một lớp mới trong app.
2. App sẽ gọi `POST /payments/class-creation/request`, nhận `redirect_url`, rồi mở checkout payOS.
3. Thanh toán thành công trên payOS thật và chờ payOS gọi webhook về backend local qua `ngrok`.
4. Kiểm tra giao dịch bằng `GET /payments/transactions/{transaction_ref}` hoặc kiểm tra lớp đã chuyển sang trạng thái hoạt động trong app.
5. Đăng nhập bằng `student`, mở chi tiết lớp và thanh toán học phí qua `POST /payments/classes/{class_id}/join/request`.
6. Sau khi payOS callback thành công, kiểm tra booking đã được xác nhận và summary bằng `GET /payments/classes/{class_id}/summary`.
7. Nếu muốn test vận hành sau thanh toán, dùng admin để xem payout balance, payment summary, complaint, hoặc retry payout.

## 11. Khi nào mới bật payout thật

Chỉ chuyển `PAYOS_PAYOUT_MOCK_MODE=false` khi bạn thật sự cần test các luồng:

- `GET /payments/providers/payos/payout-account/balance`
- `POST /payments/jobs/release-eligible-payouts`
- `POST /payments/jobs/sync-payout-statuses`
- `POST /payments/classes/{class_id}/retry-payout`

Khi bật payout thật:

- điền thêm `PAYOS_PAYOUT_CLIENT_ID`, `PAYOS_PAYOUT_API_KEY`, `PAYOS_PAYOUT_CHECKSUM_KEY`
- thêm IP public outbound của backend vào `my.payos.vn > Kênh chuyển tiền > Quản lý IP`
- tutor phải có đủ `bank_bin` và `bank_account_number`
- nên dùng teacher đã có hồ sơ payout sẵn hoặc cập nhật profile trước khi chạy job payout

## 12. Lỗi thường gặp

### Confirm webhook thành công nhưng payment không update

Kiểm tra lần lượt:

1. `PAYOS_MOCK_MODE=false`
2. `PAYMENT_GATEWAY_MODE=payos`
3. `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` đang đúng URL `ngrok` hiện tại
4. `STATIC_PUBLIC_URL` đang trỏ đúng về địa chỉ backend mà app thật sự tải ảnh/file được
5. backend đã restart sau khi sửa `.env`
6. app đang gọi đúng `SERVER_URL`
7. tunnel `ngrok` vẫn đang sống
8. webhook đã được confirm lại nếu URL `ngrok` vừa thay đổi

### App mở được payOS nhưng quay lại không thấy cập nhật trạng thái

Nguyên nhân thường là:

- app đang poll sang sai backend
- webhook đang callback về URL public cũ
- tunnel `ngrok` đã đổi hoặc đã tắt

### Retry payout vẫn fail

Kiểm tra:

- tutor có `bank_bin`
- tutor có `bank_account_number`
- payout account còn đủ số dư
- lớp đã qua thời điểm được payout

### Verify tài khoản ngân hàng báo `Địa chỉ IP không được phép truy cập hệ thống`

Nguyên nhân:

- backend đang gọi payout thật (`PAYOS_PAYOUT_MOCK_MODE=false`)
- IP public outbound hiện tại của backend chưa được thêm vào `my.payos.vn > Kênh chuyển tiền > Quản lý IP`
- `ngrok` không giải quyết lỗi này vì `ngrok` chỉ hỗ trợ callback đi vào local

Cách xử lý:

- nếu đang dev local/ngrok, đổi lại `PAYOS_PAYOUT_MOCK_MODE=true` rồi restart backend
- nếu muốn verify/payout thật, xác định IP public outbound của backend rồi thêm IP đó vào allowlist của kênh chuyển tiền
- nếu bạn đã allowlist IPv4 nhưng máy local vẫn bị chặn, rất có thể backend đang ưu tiên đi ra bằng IPv6; khi đó hãy bật `PAYOS_PAYOUT_FORCE_IPV4=true` rồi restart backend
- không còn dispute mở

## 13. Tài liệu liên quan

- [README gốc](../README.md)
- [README server](../server/README.md)
- [Admin operations](./admin-operations.md)
- [Production checklist](./production-checklist.md)
