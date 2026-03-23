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
- tài khoản `ngrok` đã verify email
- `ngrok authtoken` đã được cài vào máy
- `PAYMENT_GATEWAY_MODE=payos`
- `PAYOS_MOCK_MODE=false`
- `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` trỏ đến URL HTTPS public
- `STATIC_PUBLIC_URL` trỏ đến địa chỉ backend mà app thực tế tải được ảnh/file `/static/...`

## 3.1. Chuẩn bị ngrok để test payOS thật trên local

Khi test payOS thật từ máy local, admin cần một URL HTTPS public để:

- payOS redirect người dùng quay lại trang kết quả thanh toán
- payOS gửi webhook về backend local

Trong tài liệu này, cách đơn giản nhất là dùng `ngrok`.

### 3.1.1. Cài ngrok

Sau khi tải và cài `ngrok`, hãy mở terminal mới và kiểm tra:

```powershell
ngrok version
```

Nếu terminal báo `ngrok is not recognized`, thường là do:

- terminal hiện tại chưa nạp lại `PATH`
- `ngrok` chưa được thêm vào `PATH`

Cách xử lý nhanh nhất là đóng terminal hiện tại, mở terminal mới, rồi chạy lại `ngrok version`.

### 3.1.2. Đăng ký tài khoản và cài authtoken

`ngrok` không cho mở tunnel nếu chưa có tài khoản đã xác thực và chưa cài `authtoken`.

Nếu bạn gặp lỗi:

```text
ERR_NGROK_4018
authentication failed: Usage of ngrok requires a verified account and authtoken.
```

hãy làm theo thứ tự sau:

1. Đăng ký hoặc đăng nhập tại `https://dashboard.ngrok.com/signup`
2. Verify email của tài khoản `ngrok`
3. Lấy `authtoken` tại `https://dashboard.ngrok.com/get-started/your-authtoken`
4. Cài `authtoken` vào máy:

```powershell
ngrok config add-authtoken <AUTHTOKEN_CUA_BAN>
```

5. Kiểm tra lại cấu hình:

```powershell
ngrok config check
```

Nếu thành công, `ngrok` sẽ tạo file config trong user profile của Windows.

### 3.1.2.a. Làm lần lượt theo thứ tự này

Admin có thể đi đúng chuỗi thao tác sau:

1. Tạo hoặc đăng nhập tài khoản:
   `https://dashboard.ngrok.com/signup`
2. Verify email nếu `ngrok` yêu cầu.
3. Lấy `authtoken` tại:
   `https://dashboard.ngrok.com/get-started/your-authtoken`
4. Cài token trên máy:

```powershell
ngrok config add-authtoken <AUTHTOKEN_CUA_BAN>
```

5. Kiểm tra config:

```powershell
ngrok config check
```

6. Mở tunnel cho backend:

```powershell
ngrok http 8000
```

Khi thành công, `ngrok` sẽ hiện URL dạng:

```text
https://xxxxx.ngrok-free.app
```

Sau đó admin cần:

- cập nhật `SERVER_PUBLIC_URL`
- cập nhật `PAYMENT_PUBLIC_BASE_URL`
- kiểm tra `STATIC_PUBLIC_URL` đã trỏ đúng về local/LAN theo `SERVER_URL` của app chưa

trong `server/.env`, rồi restart backend.

### 3.1.3. Mở tunnel cho backend local

Giả sử backend local đang chạy ở cổng `8000`:

```powershell
ngrok http 8000
```

Khi thành công, `ngrok` sẽ trả về một URL dạng:

```text
https://xxxxx.ngrok-free.app
```

Admin cần copy URL này để cập nhật:

- `SERVER_PUBLIC_URL`
- `PAYMENT_PUBLIC_BASE_URL`
- và nếu cần thì chỉnh `STATIC_PUBLIC_URL` về đúng địa chỉ local/LAN mà app truy cập được

trong file `server/.env`, sau đó restart backend rồi mới confirm webhook.

### 3.1.4. Khi nào phải confirm webhook lại

Admin không cần confirm webhook trước mỗi lần thanh toán.

Chỉ cần làm lại khi:

- lần đầu setup payOS thật
- URL `ngrok` thay đổi
- đổi merchant payOS
- đổi môi trường

Nếu dùng gói `ngrok` free, URL rất dễ thay đổi mỗi lần mở tunnel mới, nên gần như mỗi lần đổi URL bạn phải:

1. cập nhật `server/.env`
2. restart backend
3. đăng nhập admin
4. confirm webhook lại

## 3.2. Phân biệt URL local của app và URL public cho payOS

Khi test local nhưng tương tác thật với payOS, có 3 nhóm URL khác nhau và rất dễ bị nhầm:

- `SERVER_URL` của Flutter app:
  địa chỉ mà app gọi API hằng ngày. Giá trị này thường vẫn là địa chỉ local hoặc LAN của backend.
- `SERVER_PUBLIC_URL` của backend:
  URL public tổng quát của backend, hiện được giữ làm fallback nếu `STATIC_PUBLIC_URL` chưa cấu hình.
- `PAYMENT_PUBLIC_BASE_URL` của backend:
  URL public để backend tạo `return_url` và `webhook_url` gửi sang payOS.
- `STATIC_PUBLIC_URL` của backend:
  URL backend dùng để sinh link `/static/...` khi local upload fallback, ví dụ avatar, ảnh bìa lớp, hay file chứng chỉ.

Quy tắc thực tế nên nhớ:

- app vẫn gọi backend local qua `SERVER_URL`
- payOS chỉ gọi lại backend qua `PAYMENT_PUBLIC_BASE_URL`
- file tĩnh local fallback sẽ được app tải qua `STATIC_PUBLIC_URL`
- không cần đổi toàn bộ client sang URL `ngrok` nếu mục tiêu chỉ là cho payOS callback được về local

Ví dụ thường dùng:

- Android emulator:
  `flutter run --dart-define=SERVER_URL=http://10.0.2.2:8000`
- iPhone simulator hoặc Flutter web chạy cùng máy:
  `flutter run --dart-define=SERVER_URL=http://127.0.0.1:8000`
- máy thật cùng mạng LAN:
  `flutter run --dart-define=SERVER_URL=http://<LAN_IP_CUA_MAY_DEV>:8000`

Trong khi đó, ở `server/.env`, `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` vẫn nên là URL HTTPS public kiểu:

```text
https://xxxxx.ngrok-free.app
```

Nhưng `STATIC_PUBLIC_URL` nên theo đúng địa chỉ mà app thật sự truy cập được, ví dụ:

```text
http://127.0.0.1:8000
http://10.0.2.2:8000
http://<LAN_IP_CUA_MAY_DEV>:8000
```

Nếu app mở được trang payOS nhưng quay về xong không cập nhật trạng thái, hãy kiểm tra lại cả hai phía:

- app có đang gọi đúng backend local bằng `SERVER_URL` hay không
- backend có đang public đúng URL `ngrok` trong `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` hay không
- `STATIC_PUBLIC_URL` có đang trỏ đúng về địa chỉ backend mà app tải được ảnh/file hay không

## 3.3. Chọn phạm vi test phù hợp

Không phải lúc nào cũng nên bật cả payment thật lẫn payout thật ngay từ đầu.

### Phương án khuyến nghị: payment thật, payout mock

Đây là cấu hình an toàn và đủ để test gần hết luồng người dùng:

- tạo payment link payOS thật
- thanh toán thật ở bước tạo lớp
- thanh toán thật ở bước học viên tham gia lớp
- nhận `return_url` thật
- nhận webhook thật
- app poll lại transaction thật

Biến môi trường nên đặt:

```env
PAYMENT_GATEWAY_MODE=payos
PAYOS_MOCK_MODE=false
PAYOS_PAYOUT_MOCK_MODE=true
```

### Khi nào mới bật payout thật

Chỉ nên chuyển sang payout thật khi bạn thật sự cần test:

- balance payout account
- release payout cho tutor
- sync payout status
- retry payout

Lúc đó mới đổi thêm:

```env
PAYOS_PAYOUT_MOCK_MODE=false
```

và điền riêng:

- `PAYOS_PAYOUT_CLIENT_ID`
- `PAYOS_PAYOUT_API_KEY`
- `PAYOS_PAYOUT_CHECKSUM_KEY`

Nếu payout dùng partner code riêng, điền thêm `PAYOS_PAYOUT_PARTNER_CODE`.

## 3.4. Checklist kỹ thuật trước khi mở app

Trước khi test bằng `teacher` hoặc `student`, nên kiểm tra nhanh:

1. backend local đang chạy được ở `http://127.0.0.1:8000` hoặc địa chỉ LAN tương ứng
2. tunnel `ngrok` vẫn đang sống và chưa đổi URL
3. `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` đang trùng đúng URL `ngrok` hiện tại
4. `STATIC_PUBLIC_URL` đang trỏ đúng về địa chỉ local/LAN mà app thực tế truy cập được
5. backend đã được restart sau lần sửa `.env` gần nhất
6. webhook đã được confirm lại nếu URL `ngrok` vừa thay đổi
6. nếu copy từ `server/.env.payos-ngrok.sample`, nhớ kiểm tra lại `DATABASE_URL` cho đúng máy bạn

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
4. Cập nhật `STATIC_PUBLIC_URL` theo đúng địa chỉ local/LAN mà app dùng
5. Restart backend
6. Login admin
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
2. Chạy `ngrok http 8000`
3. Copy URL `https://...ngrok-free.app` mà ngrok trả về.
4. Cập nhật `server/.env`:
   - `PAYMENT_GATEWAY_MODE=payos`
   - `PAYOS_MOCK_MODE=false`
   - `PAYOS_PAYOUT_MOCK_MODE=true` nếu mới test payment flow
   - `SERVER_PUBLIC_URL=https://...`
   - `PAYMENT_PUBLIC_BASE_URL=https://...`
   - `STATIC_PUBLIC_URL=http://127.0.0.1:8000` hoặc `http://10.0.2.2:8000` hoặc `http://<LAN_IP_CUA_MAY_DEV>:8000`
5. Nếu bạn lấy file nền từ `server/.env.payos-ngrok.sample`, nhớ kiểm tra lại `DATABASE_URL`.
   Với stack Docker mặc định của repo, PostgreSQL đang publish ở `localhost:5433`.
6. Restart backend.
7. Tạo admin nếu chưa có.
8. Đăng nhập admin và lấy token.
9. Confirm webhook.
10. Chạy client nhưng vẫn trỏ `SERVER_URL` về backend local hoặc LAN của bạn, ví dụ:

```powershell
# Android emulator
flutter run --dart-define=SERVER_URL=http://10.0.2.2:8000

# Flutter web hoặc simulator chạy cùng máy
flutter run --dart-define=SERVER_URL=http://127.0.0.1:8000

# Máy thật cùng mạng LAN
flutter run --dart-define=SERVER_URL=http://<LAN_IP_CUA_MAY_DEV>:8000
```

11. Đăng nhập bằng `teacher` để tạo lớp và thanh toán phí tạo lớp.
12. Đăng nhập bằng `student` để join lớp và thanh toán học phí.
13. Nếu cần, dùng admin để xem summary, balance, complaint, payout.

### Cách hiểu đúng quy trình trên

- `SERVER_URL` của app vẫn là địa chỉ local hoặc LAN của backend
- `SERVER_PUBLIC_URL` và `PAYMENT_PUBLIC_BASE_URL` là URL public cho backend/payOS
- `STATIC_PUBLIC_URL` là URL mà app dùng để tải avatar, ảnh bìa lớp, và file local fallback
- `confirm webhook` chỉ cần làm lại khi URL public đổi hoặc đổi merchant/môi trường

### Khi nào nên đổi từ payout mock sang payout thật

Chỉ đổi `PAYOS_PAYOUT_MOCK_MODE=false` khi bạn chuẩn bị test một trong các luồng sau:

- `GET /payments/providers/payos/payout-account/balance`
- `POST /payments/jobs/release-eligible-payouts`
- `POST /payments/jobs/sync-payout-statuses`
- `POST /payments/classes/{class_id}/retry-payout`

Khi đổi sang payout thật, cần điền bộ `PAYOS_PAYOUT_CLIENT_ID`, `PAYOS_PAYOUT_API_KEY`, `PAYOS_PAYOUT_CHECKSUM_KEY` riêng cho kênh payout.

Nếu chưa test các luồng này, nên để payout mock để tránh phát sinh lỗi ngoài ý muốn.

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
- `ngrok` chưa được login bằng `authtoken`
- tài khoản `ngrok` chưa verify email nên tunnel không mở được
- backend chưa restart sau khi sửa `.env`
- `PAYMENT_PUBLIC_BASE_URL` không trùng URL public hiện tại
- payOS đang ở mock hoặc backend đang ở mock mode
- app đang gọi sai `SERVER_URL`, nên poll transaction vào nhầm backend
- tab `ngrok` đã tắt hoặc tunnel hết hiệu lực giữa chừng

Cách xử lý:

1. kiểm tra `.env`
2. kiểm tra `ngrok config check`
3. restart backend
4. kiểm tra lại `flutter run --dart-define=SERVER_URL=...`
5. confirm webhook lại
6. test lại giao dịch mới

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
6. Nếu test payOS thật, kiểm tra `ngrok` đã verify tài khoản và cài `authtoken`.
7. Nếu test payOS thật, mở `ngrok http 8000` và copy URL public.
8. Cập nhật `SERVER_PUBLIC_URL`, `PAYMENT_PUBLIC_BASE_URL`, và `STATIC_PUBLIC_URL`, rồi restart backend.
9. Confirm webhook khi cần.
10. Biết cách xem payment summary.
11. Biết cách resolve complaint.
12. Biết cách retry payout.
13. Biết cách chạy tay job khi cần.

## 13. Tóm tắt ngắn

Admin trong EConnect là người vận hành hệ thống bằng API.

Với admin, 4 kỹ năng quan trọng nhất là:

- đăng nhập và quản lý token
- confirm webhook payOS khi cần
- đọc payment summary và xử lý complaint/payout
- chạy tay các job vận hành để support hệ thống

Nếu bạn chỉ cần nhớ một quy trình cơ bản, hãy nhớ chuỗi này:

`tạo admin -> đăng nhập -> lấy token -> confirm webhook nếu cần -> xem summary / xử lý vận hành`
