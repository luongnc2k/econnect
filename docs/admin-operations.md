# Hướng Dẫn Admin Vận Hành Hệ Thống EConnect

Tài liệu này hướng dẫn admin vận hành hệ thống EConnect theo cách thực tế: tạo tài khoản admin, đăng nhập, lấy token, gọi các API admin, và xử lý các tình huống vận hành thường gặp.

## 1. Admin dùng ở đâu

Hiện tại repo chưa có màn hình admin riêng trong Flutter app. Admin nên thao tác bằng một trong các cách sau:

- Swagger UI: `http://localhost:8000/docs`
- Postman
- PowerShell `Invoke-RestMethod`
- `curl`

Khuyến nghị khi dev local:

- dùng Swagger để xem schema nhanh
- dùng PowerShell hoặc Postman để lưu token và lặp lại request

## 2. Admin dùng để làm gì

Admin là role vận hành hệ thống, không phải role học/dạy thông thường như `teacher` và `student`.

Admin được dùng để:

- bootstrap tài khoản admin đầu tiên
- confirm webhook payOS thật
- kiểm tra payout balance
- retry payout cho tutor
- resolve complaint của học viên
- xem payment summary để support vận hành
- chạy tay job nhắc lịch, hủy lớp thiếu người, payout, sync payout
- quản lý topic
- quản lý địa điểm học

## 3. Điều kiện trước khi bắt đầu

Cần chuẩn bị:

- backend đang chạy ở `http://127.0.0.1:8000` hoặc URL backend của bạn
- file `server/.env` đã được cấu hình
- biết giá trị `ADMIN_CREATE_SECRET` nếu cần bootstrap admin
- có một tài khoản admin sẵn, hoặc có quyền tạo admin đầu tiên

Nếu test payOS thật local, cần thêm:

- `ngrok` hoặc tunnel HTTPS public tương đương
- `PAYMENT_GATEWAY_MODE=payos`
- `PAYOS_MOCK_MODE=false`
- `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` trỏ đến URL HTTPS public

## 4. Quy ước xác thực

Sau khi đăng nhập thành công, backend trả về JWT token.

Mọi API admin cần token đều dùng header:

```http
x-auth-token: <TOKEN>
```

Với các job endpoint, hệ thống chấp nhận một trong hai cách:

- token admin
- hoặc header `x-job-secret`

Trong tài liệu này, ưu tiên hướng dẫn bằng token admin để dễ thao tác bằng tay.

## 5. Bước 1: Tạo tài khoản admin đầu tiên

### Cách 1. Tạo bằng Swagger UI

1. Mở `http://localhost:8000/docs`
2. Tìm `POST /auth/create-admin`
3. Bấm `Try it out`
4. Điền header:
   - `x-admin-secret: <ADMIN_CREATE_SECRET>`
5. Điền request body
6. Bấm `Execute`

### Request body mẫu

Lưu ý quan trọng:

- route `create-admin` hiện đang tái sử dụng schema `UserCreate`
- schema này vẫn yêu cầu field `role`
- backend sẽ bỏ qua field này và tự set role thành `admin`

Vì vậy, khi bootstrap admin, bạn vẫn phải gửi `role`, ví dụ `"teacher"`.

```json
{
  "full_name": "System Admin",
  "email": "admin@example.com",
  "password": "Admin12345",
  "role": "teacher"
}
```

### Cách 2. Tạo bằng PowerShell

```powershell
$baseUrl = "http://127.0.0.1:8000"
$adminSecret = "change_this_admin_bootstrap_secret"

$body = @{
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
  -Body $body
```

### Kết quả mong đợi

Backend trả về thông tin user vừa tạo. Từ thời điểm này bạn đã có thể đăng nhập bằng email và mật khẩu vừa tạo.

## 6. Bước 2: Đăng nhập admin

### Request body

```json
{
  "email": "admin@example.com",
  "password": "Admin12345"
}
```

### PowerShell

```powershell
$baseUrl = "http://127.0.0.1:8000"

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
$token
```

### Response mẫu

```json
{
  "token": "<JWT_TOKEN>",
  "user": {
    "id": "...",
    "email": "admin@example.com",
    "full_name": "System Admin",
    "role": "admin",
    "is_active": true
  }
}
```

### Sau khi đăng nhập

Đặt header mặc định:

```powershell
$authHeader = @{ "x-auth-token" = $token }
```

Từ đây trở đi, các request admin đều có thể tái sử dụng `$authHeader`.

## 7. Bước 3: Kiểm tra admin đã đăng nhập đúng chưa

Có thể dùng một API chỉ admin để test nhanh.

### Cách dễ nhất

Gọi API xem số dư payout account:

```powershell
Invoke-RestMethod `
  -Method Get `
  -Uri "$baseUrl/payments/providers/payos/payout-account/balance" `
  -Headers $authHeader
```

Nếu bạn nhận `403`, khả năng cao là:

- token không phải của admin
- token hết hạn
- header `x-auth-token` chưa gửi đúng

## 8. Công việc admin thường gặp

### 8.1. Confirm webhook payOS thật

Chỉ cần làm khi:

- lần đầu setup payOS thật
- URL public đổi
- đổi merchant payOS
- đổi môi trường staging/production/local tunnel

Không cần làm trước mỗi lần thanh toán.

### Cách gọi nhanh

Nếu muốn backend tự lấy webhook URL mặc định từ `PAYMENT_PUBLIC_BASE_URL`:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/providers/payos/confirm-webhook" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body "{}"
```

Nếu muốn chỉ định rõ URL:

```powershell
$body = @{
  webhook_url = "https://your-ngrok-url.ngrok-free.app/payments/providers/payos/webhook"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/providers/payos/confirm-webhook" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body $body
```

### Kết quả mong đợi

Response thường gồm:

- `webhook_url`
- `account_name`
- `account_number`
- `name`
- `short_name`

Nếu thành công, payOS đã biết webhook URL đúng của backend.

### Lưu ý cho local + ngrok

Quy trình đúng:

1. Chạy backend local
2. Chạy `ngrok http 8000`
3. Cập nhật `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL`
4. Restart backend
5. Login admin
6. Confirm webhook
7. Sau đó mới test `teacher` và `student`

## 8.2. Kiểm tra payout balance

Dùng khi muốn xác nhận tài khoản payout payOS còn đủ tiền.

```powershell
Invoke-RestMethod `
  -Method Get `
  -Uri "$baseUrl/payments/providers/payos/payout-account/balance" `
  -Headers $authHeader
```

Admin nên kiểm tra endpoint này khi:

- trước khi test payout thật
- payout bị fail nhưng nghi ngờ do số dư
- cần đối soát tài khoản payout

## 8.3. Xem payment summary của lớp

Có hai cách xem:

- theo `class_id`
- theo `class_code`

### Theo `class_id`

```powershell
$classId = "<CLASS_ID>"

Invoke-RestMethod `
  -Method Get `
  -Uri "$baseUrl/payments/classes/$classId/summary" `
  -Headers $authHeader
```

### Theo `class_code`

```powershell
$classCode = "CLS-260322-ABCD"

Invoke-RestMethod `
  -Method Get `
  -Uri "$baseUrl/payments/classes/by-code/$classCode/summary" `
  -Headers $authHeader
```

### Các field cần chú ý

- `class_status`
- `creation_payment_status`
- `creation_fee_amount`
- `current_participants`
- `minimum_participants_reached`
- `tutor_payout_status`
- `tutor_payout_amount`
- `total_escrow_held`
- `active_disputes`

Dùng summary khi:

- support lỗi thanh toán
- kiểm tra lớp đã được kích hoạt chưa
- kiểm tra escrow và payout
- kiểm tra dispute còn mở hay không

## 8.4. Resolve complaint của học viên

Học viên sẽ mở complaint bằng role `student`. Khi complaint đã mở, admin là người quyết định complaint hợp lệ hay không.

### Request body

```json
{
  "booking_id": "BOOKING_ID",
  "is_valid": true,
  "note": "Tutor vắng mặt, đồng ý hoàn tiền"
}
```

### PowerShell

```powershell
$body = @{
  booking_id = "BOOKING_ID"
  is_valid = $true
  note = "Tutor vắng mặt, đồng ý hoàn tiền"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/complaints/resolve" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body $body
```

### Cách đọc `is_valid`

- `true`: complaint hợp lệ, hệ thống sẽ hoàn tiền hoặc giữ payout
- `false`: complaint không hợp lệ, payout có thể tiếp tục

Sau khi resolve, nên gọi lại payment summary của lớp để kiểm tra kết quả.

## 8.5. Retry payout cho tutor

Dùng khi payout fail, tutor sửa thông tin ngân hàng, hoặc cần tạo lại payout.

```powershell
$classId = "<CLASS_ID>"

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/classes/$classId/retry-payout" `
  -Headers $authHeader
```

Trước khi retry, admin nên kiểm tra:

- lớp đã đến giai đoạn được payout chưa
- `tutor_payout_status` hiện tại là gì
- tutor đã có `bank_bin` và `bank_account_number` hợp lệ chưa
- `total_escrow_held` còn đủ hay không

## 8.6. Chạy tay các job vận hành

### Nhắc lịch sắp học

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/jobs/notify-classes-starting-soon" `
  -Headers $authHeader
```

### Hủy lớp thiếu người trước 4 giờ

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/jobs/cancel-underfilled-classes" `
  -Headers $authHeader
```

### Tạo payout cho các lớp đủ điều kiện

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/jobs/release-eligible-payouts" `
  -Headers $authHeader
```

### Đồng bộ payout đang xử lý

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/payments/jobs/sync-payout-statuses" `
  -Headers $authHeader
```

### Khi nào admin nên gọi tay job

- dev local
- staging test
- xử lý sự cố
- cần đối soát thủ công

Trong môi trường thật, scheduler nên gọi bằng `x-job-secret` thay vì dùng token admin nếu có thể.

## 8.7. Tạo topic mới

```powershell
$body = @{
  name = "Business English"
  slug = "business-english"
  description = "Tiếng Anh cho người đi làm"
  icon = "briefcase"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/topics" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body $body
```

Dùng khi cần mở rộng danh mục chủ đề học tập cho teacher và student.

## 8.8. Quản lý địa điểm học

### Tạo địa điểm học

```powershell
$body = @{
  name = "Highlands Coffee Ba Dinh"
  address = "12 Kim Ma, Ba Dinh, Ha Noi"
  latitude = 21.0307
  longitude = 105.8147
  notes = "Phù hợp lớp 4-6 học viên"
  is_active = $true
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/locations" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body $body
```

### Cập nhật địa điểm học

```powershell
$locationId = "<LOCATION_ID>"
$body = @{
  notes = "Cập nhật ghi chú cho địa điểm"
  is_active = $true
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Patch `
  -Uri "$baseUrl/locations/$locationId" `
  -Headers $authHeader `
  -ContentType "application/json" `
  -Body $body
```

Dùng khi:

- bổ sung địa điểm học mới
- tạm dừng địa điểm học
- chỉnh sửa địa chỉ, ghi chú, trạng thái active

## 9. Quy trình admin để test payOS thật trên local

Đây là quy trình gọn nhất cho local:

1. Chạy backend local.
2. Chạy `ngrok http 8000`.
3. Copy URL `https://...ngrok-free.app`.
4. Cập nhật `server/.env`:
   - `PAYMENT_GATEWAY_MODE=payos`
   - `PAYOS_MOCK_MODE=false`
   - `SERVER_PUBLIC_URL=https://...`
   - `PAYMENT_PUBLIC_BASE_URL=https://...`
5. Restart backend.
6. Tạo admin nếu chưa có.
7. Đăng nhập admin và lấy token.
8. Confirm webhook.
9. Đăng nhập bằng `teacher` để tạo lớp.
10. Đăng nhập bằng `student` để join và thanh toán.
11. Nếu cần, dùng admin để xem summary, balance, complaint, payout.

## 10. Lỗi thường gặp và cách xử lý

### 403 Forbidden khi gọi API admin

Nguyên nhân thường gặp:

- token không phải của admin
- quên gửi `x-auth-token`
- token hết hạn

Cách xử lý:

- đăng nhập lại admin
- in lại `$token`
- kiểm tra header request

### 400 khi gọi `create-admin`

Nguyên nhân thường gặp:

- sai `x-admin-secret`
- email đã tồn tại
- password quá ngắn
- quên field `role` trong body

Lưu ý:

- dù backend tạo role `admin`, request body vẫn phải có `role`

### Confirm webhook thành công nhưng payment không update

Nguyên nhân thường gặp:

- URL `ngrok` đã đổi nhưng chưa confirm lại
- backend chưa restart sau khi sửa `.env`
- `PAYMENT_PUBLIC_BASE_URL` không trùng URL public hiện tại
- payOS đang ở mock hoặc backend đang ở mock mode

Cách xử lý:

1. kiểm tra `.env`
2. restart backend
3. confirm webhook lại
4. test lại giao dịch mới

### Retry payout vẫn fail

Nguyên nhân thường gặp:

- tutor thiếu `bank_bin`
- tutor thiếu `bank_account_number`
- payout account không đủ số dư
- lớp chưa đến thời điểm được payout
- vẫn còn dispute mở

Cách xử lý:

- xem payment summary
- kiểm tra payout balance
- kiểm tra thông tin ngân hàng tutor
- sync payout nếu lệnh đang ở trạng thái processing

## 11. Bảo mật và quy tắc vận hành

- Không chia sẻ token admin cho client app.
- Không lưu token admin trong source code.
- Không dùng admin để test nghiệp vụ teacher/student thông thường nếu không cần.
- Không confirm webhook trước mỗi lần thanh toán.
- Ưu tiên dùng `x-job-secret` cho scheduler trong môi trường thật.
- Đổi `ADMIN_CREATE_SECRET` khỏi giá trị mẫu trước khi mở rộng môi trường.

## 12. Checklist nhanh cho admin mới

1. Biết backend đang chạy ở URL nào.
2. Biết `ADMIN_CREATE_SECRET` nếu cần bootstrap.
3. Tạo admin nếu chưa có.
4. Đăng nhập admin và lưu token.
5. Thử gọi một API admin để kiểm tra token.
6. Nếu test payOS thật, confirm webhook.
7. Biết cách xem payment summary.
8. Biết cách resolve complaint.
9. Biết cách retry payout.
10. Biết cách chạy tay job khi cần.

## 13. Tóm tắt ngắn

Admin trong EConnect là người vận hành hệ thống bằng API.

Với admin, 4 kỹ năng quan trọng nhất là:

- đăng nhập và quản lý token
- confirm webhook payOS khi cần
- đọc payment summary và xử lý complaint/payout
- chạy tay các job vận hành để support hệ thống

Nếu bạn chỉ cần nhớ một quy trình cơ bản, hãy nhớ chuỗi này:

`tạo admin -> đăng nhập -> lấy token -> confirm webhook nếu cần -> xem summary / xử lý vận hành`
