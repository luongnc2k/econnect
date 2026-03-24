# 1. Bối cảnh và luồng nghiệp vụ tổng quát

```mermaid
flowchart TD
    A[Người dùng khởi tạo giao dịch] --> B{Loại giao dịch?}

    B -->|Phí tạo nhóm| C[Tutor tạo payment request]
    B -->|Học phí học viên| D[Student đăng ký nhóm và tạo payment request]

    C --> E[Chuyển sang PSP<br/>payOS]
    D --> E

    E --> F[PSP xử lý thanh toán]
    F --> G[PSP gửi callback / webhook]

    G --> H{Thanh toán thành công?}

    H -->|Không| I[Cập nhật giao dịch thất bại]
    I --> J[Không tạo nhóm / Không ghi nhận đăng ký]

    H -->|Có - Phí tạo nhóm| K[Cập nhật giao dịch thành công]
    K --> L[Tạo nhóm học]

    H -->|Có - Học phí học viên| M[Cập nhật giao dịch thành công]
    M --> N[Ghi nhận học viên chính thức]
    N --> O[Giữ tiền trong escrow]

    N --> X{Bị oversell slot?}
    X -->|Có| Y[Giữ slot cho giao dịch sớm nhất]
    Y --> Z[Hoàn tiền tự động các giao dịch còn lại]
    X -->|Không| BA{Đã đủ số lượng học viên tối thiểu?}

    BA -->|Có| BB[Xác nhận buổi học sẽ diễn ra]
    BB --> BC[Thông báo cho Tutor và các học viên đã đăng ký]

    BA -->|Không| AA{Còn 4 giờ trước buổi học?}
    AA -->|Không| BD[Tiếp tục chờ thêm học viên đăng ký]
    BD --> BA

    AA -->|Có| AE{Đủ số lượng học viên tối thiểu?}
    AE -->|Có| BB
    AE -->|Không| AB[Hủy lớp tự động]

    AB --> AC[Hoàn 100% học phí học viên]
    AC --> AF[Hoàn phí tạo nhóm cho Tutor]

    BC --> P[Buổi học kết thúc]
    O --> P

    P --> P1[Tutor xác nhận kết thúc buổi học]
    P1 --> Q[Hệ thống chờ 2 giờ để nhận phản hồi từ học viên]

    Q --> R{Có học viên xác nhận Tutor không đến dạy?}
    R -->|Không| S[Chuyển tiền cho Tutor]
    R -->|Có| T[Tạm giữ tiền, chưa chuyển cho Tutor]

    T --> U[Admin kiểm tra và xử lý khiếu nại]
    U --> V{Khiếu nại đúng?}
    V -->|Có| W[Hủy chuyển tiền cho Tutor]
    V -->|Không| S

    L --> AH[Tutor có thể chủ động hủy lớp]
    AH --> AI[Hoàn 100% học phí học viên]
    AI --> AJ[Không hoàn phí tạo nhóm]
```

# 2. Sơ đồ tuần tự: luồng payment với PSP

```mermaid
sequenceDiagram
    actor User
    participant E as EConnect
    participant PSP as payOS

    User->>E: Yêu cầu thanh toán
    E->>E: Tạo payment request
    E-->>User: Redirect sang PSP

    User->>PSP: Thực hiện thanh toán
    PSP-->>User: Hiển thị kết quả thanh toán
    PSP->>E: Callback/Webhook kết quả giao dịch

    E->>E: Xác thực callback và kiểm tra chữ ký
    E->>E: Kiểm tra idempotency / chống trùng lặp

    alt Thanh toán thành công
        E->>E: Cập nhật transaction = SUCCESS
        alt Thanh toán phí tạo nhóm
            E->>E: Tạo nhóm học
            E-->>User: Nhóm được tạo thành công
        else Thanh toán học phí
            E->>E: Ghi nhận học viên chính thức
            E->>E: Tạo bản ghi escrow
            E-->>User: Đăng ký thành công
        end
    else Thanh toán thất bại
        E->>E: Cập nhật transaction = FAILED
        E-->>User: Thông báo thất bại
    end
```

# 3. Sơ đồ tuần tự: kết thúc buổi học, escrow, khiếu nại, payout/refund

```mermaid
sequenceDiagram
    participant Scheduler as Scheduler/System Job
    participant E as EConnect
    actor Student
    actor Admin
    actor Tutor

    Scheduler->>E: Kiểm tra buổi học đã kết thúc
    E->>E: Chờ 2 giờ khiếu nại

    alt Không có khiếu nại
        E->>E: Giải phóng escrow
        E->>Tutor: Chuyển tiền học phí
        E->>E: Lưu lịch sử payout
    else Có khiếu nại
        Student->>E: Gửi khiếu nại
        E->>E: Tạm giữ tiền
        E->>Admin: Tạo case xử lý tranh chấp

        Admin->>E: Xác minh khiếu nại
        alt Khiếu nại đúng
            E->>Student: Hoàn tiền học phí
            E->>E: Không payout cho Tutor
            E->>E: Lưu lịch sử refund/dispute
        else Khiếu nại không đúng
            E->>Tutor: Chuyển tiền học phí
            E->>E: Lưu lịch sử payout/dispute
        end
    end
```

# 4. Sơ đồ trạng thái: giao dịch học phí và escrow

```mermaid
stateDiagram-v2
    [*] --> INIT

    INIT --> PENDING_PSP: Tạo payment request
    PENDING_PSP --> FAILED: PSP thanh toán thất bại
    PENDING_PSP --> SUCCESS: PSP callback thành công

    SUCCESS --> REGISTERED: Ghi nhận đăng ký
    REGISTERED --> ESCROW_HELD: Giữ tiền trong escrow

    ESCROW_HELD --> AUTO_REFUND: Oversell slot
    ESCROW_HELD --> AUTO_REFUND: Lớp bị hủy do không đủ học viên
    ESCROW_HELD --> AUTO_REFUND: Tutor chủ động hủy lớp

    ESCROW_HELD --> WAIT_COMPLAINT: Buổi học kết thúc
    WAIT_COMPLAINT --> PAYOUT: Hết 2 giờ, không có khiếu nại
    WAIT_COMPLAINT --> DISPUTED: Có khiếu nại

    DISPUTED --> REFUNDED: Admin xác nhận khiếu nại đúng
    DISPUTED --> PAYOUT: Admin bác khiếu nại

    AUTO_REFUND --> REFUNDED

    FAILED --> [*]
    REFUNDED --> [*]
    PAYOUT --> [*]
```

# 5. ERD: mô hình dữ liệu gợi ý cho tính năng thanh toán

```mermaid
erDiagram
    USER ||--o{ STUDY_GROUP : creates_or_joins
    USER ||--o{ PAYMENT_TRANSACTION : makes
    USER ||--o{ COMPLAINT : submits
    USER ||--o{ PAYOUT : receives

    STUDY_GROUP ||--o{ GROUP_ENROLLMENT : has
    STUDY_GROUP ||--o{ SESSION : has
    STUDY_GROUP ||--o{ PAYMENT_TRANSACTION : relates_to
    STUDY_GROUP ||--o{ ESCROW : owns

    SESSION ||--o{ COMPLAINT : may_generate
    SESSION ||--o{ PAYOUT : triggers

    PAYMENT_TRANSACTION ||--o| ESCROW : creates
    PAYMENT_TRANSACTION ||--o{ REFUND : may_generate

    USER {
        bigint user_id PK
        string role
        string full_name
        string email
    }

    STUDY_GROUP {
        bigint group_id PK
        bigint tutor_id FK
        decimal tutor_session_price
        int min_students
        int max_students
        string status
        datetime created_at
    }

    GROUP_ENROLLMENT {
        bigint enrollment_id PK
        bigint group_id FK
        bigint student_id FK
        string status
        datetime joined_at
    }

    SESSION {
        bigint session_id PK
        bigint group_id FK
        datetime start_time
        datetime end_time
        string status
    }

    PAYMENT_TRANSACTION {
        bigint transaction_id PK
        bigint payer_id FK
        bigint group_id FK
        bigint session_id FK
        string payment_type
        decimal amount
        string psp_provider
        string psp_transaction_code
        string status
        string idempotency_key
        datetime created_at
    }

    ESCROW {
        bigint escrow_id PK
        bigint transaction_id FK
        bigint group_id FK
        decimal amount
        string status
        datetime held_at
        datetime released_at
    }

    REFUND {
        bigint refund_id PK
        bigint transaction_id FK
        decimal amount
        string reason
        string status
        datetime refunded_at
    }

    PAYOUT {
        bigint payout_id PK
        bigint tutor_id FK
        bigint session_id FK
        decimal amount
        string status
        datetime paid_at
    }

    COMPLAINT {
        bigint complaint_id PK
        bigint session_id FK
        bigint student_id FK
        string reason
        string status
        datetime created_at
        datetime resolved_at
    }
```

# 6. Ghi chú tích hợp backend với PayOS

- Backend `server/` hiện tại chỉ sử dụng `payOS` cho 2 API tạo giao dịch:
  - `POST /payments/class-creation/request`
  - `POST /payments/classes/{class_id}/join/request`
- Redirect URL trả về cho client sẽ là `checkout_url` do payOS cung cấp.
- Backend nhận redirect người dùng qua `/payments/providers/payos/return` và nhận webhook xác thực qua `/payments/providers/payos/webhook`.
- `transaction_ref` của EConnect vẫn được giữ để app poll trạng thái; `orderCode` của payOS được map vào `payments.provider_order_id`.
- Để bật webhook thật, admin có thể gọi `POST /payments/providers/payos/confirm-webhook` sau khi deploy backend lên URL public.

# 7. Payout cho Tutor qua PayOS

- Sau khi lớp kết thúc 2 giờ và không có khiếu nại, backend gọi `POST /payments/jobs/release-eligible-payouts` để tạo payout cho Tutor qua payOS.
- Nếu lệnh payout vẫn đang chờ xử lý, backend có thể gọi `POST /payments/jobs/sync-payout-statuses` để poll `GET /v1/payouts/{id}` và cập nhật trạng thái nội bộ.
- Tutor phải có đủ `bank_bin` và `bank_account_number` trong profile; nếu thiếu, backend sẽ đánh dấu payout là `failed`.
- Khi đã bổ sung lại thông tin ngân hàng hoặc muốn thử lại sau lỗi tạm thời, admin gọi `POST /payments/classes/{class_id}/retry-payout`.
- `GET /payments/providers/payos/payout-account/balance` giúp admin kiểm tra số dư payout account trước khi chạy lệnh chi.

# 8. Luồng tương tác giữa app, backend và payOS

## 8.1 Tutor đóng phí tạo lớp

```mermaid
sequenceDiagram
    actor Tutor
    participant App as EConnect App
    participant API as EConnect Backend
    participant PayOS as payOS

    Tutor->>App: Tạo lớp và bấm thanh toán
    App->>API: POST /payments/class-creation/request
    API->>PayOS: Tạo payment link phí tạo lớp
    PayOS-->>API: checkout_url + orderCode
    API-->>App: transaction_ref + redirect_url
    App->>PayOS: Mở checkout_url
    Tutor->>PayOS: Thanh toán phí tạo lớp
    PayOS->>API: GET /payments/providers/payos/return?orderCode=...
    API-->>PayOS: HTML status page
    PayOS->>API: POST /payments/providers/payos/webhook
    API->>API: Verify webhook, cập nhật payment
    App->>API: Poll transaction_ref
    API-->>App: paid / failed + class status
```

## 8.2 Học viên đóng học phí

```mermaid
sequenceDiagram
    actor Student
    participant App as EConnect App
    participant API as EConnect Backend
    participant PayOS as payOS

    Student->>App: Đăng ký lớp và bấm thanh toán
    App->>API: POST /payments/classes/{class_id}/join/request
    API->>PayOS: Tạo payment link học phí
    PayOS-->>API: checkout_url + orderCode
    API-->>App: transaction_ref + redirect_url
    App->>PayOS: Mở checkout_url
    Student->>PayOS: Thanh toán học phí
    PayOS->>API: GET /payments/providers/payos/return?orderCode=...
    API-->>PayOS: HTML status page
    PayOS->>API: POST /payments/providers/payos/webhook
    API->>API: Verify webhook, confirm booking, giữ escrow
    App->>API: Poll transaction_ref
    API-->>App: paid / failed + booking status
```

## 8.3 Backend chi tiền cho Tutor qua payOS

```mermaid
sequenceDiagram
    actor Job as Scheduler/Admin
    actor Tutor
    participant App as EConnect App
    participant API as EConnect Backend
    participant PayOS as payOS

    Job->>API: POST /payments/jobs/release-eligible-payouts
    API->>API: Kiểm tra lớp đã kết thúc 2 giờ, không có dispute, tutor có bank_bin
    API->>PayOS: POST /v1/payouts
    PayOS-->>API: payout.id + approvalState
    API->>API: Tạo payment_type=payout, status=processing/released

    loop Khi payout đang xử lý
        Job->>API: POST /payments/jobs/sync-payout-statuses
        API->>PayOS: GET /v1/payouts/{payout.id}
        PayOS-->>API: approvalState + transactions.state
        API->>API: Đồng bộ payout status, release escrow nếu thành công
    end

    alt Payout thành công
        API->>API: tutor_payout_status = paid
        Tutor->>App: Mở app xem lịch sử / doanh thu
        App->>API: GET class payment summary / payout status
        API-->>App: paid + tutor_payout_amount
    else Payout thất bại
        API->>API: tutor_payout_status = failed
        Job->>API: POST /payments/classes/{class_id}/retry-payout
        API->>PayOS: Tạo lại payout sau khi sửa thông tin ngân hàng
    end
```

# 9. Quy tắc tính tiền trong hệ thống

## 9.1 Phí tạo lớp của Tutor

- Backend tính phí tạo lớp bằng công thức:

```text
creation_fee_amount = round_half_up(class.price * 10%)
```

- `class.price` là tổng giá trị buổi học mà Tutor đặt cho cả lớp.
- Số tiền này được lưu vào `classes.creation_fee_amount`.
- Payment này là giao dịch `payment_type = class_creation`.
- Nếu Tutor thanh toán thành công thì lớp mới được kích hoạt sang trạng thái `scheduled`.

Ví dụ:

```text
class.price = 200000
creation_fee_amount = 200000 * 10% = 20000
```

## 9.2 Học phí mỗi học viên

- Backend tính học phí mỗi học viên bằng công thức:

```text
student_tuition = round_half_up(class.price / class.max_participants)
```

- Đây là mức học phí mỗi học viên trả cho EConnect khi join lớp.
- Student app nên hiển thị đúng mức này ở card/detail/payment CTA.
- Tutor app vẫn nên hiển thị `class.price` là tổng học phí của cả buổi.
- Các booking trong cùng một lớp sẽ có cùng `tuition_amount` nếu `class.price` và `max_participants` không đổi.
- Payment này là giao dịch `payment_type = tuition`.

Ví dụ:

```text
class.price = 200000
class.max_participants = 4
student_tuition = 200000 / 4 = 50000
```

Nếu lớp có 3 học viên thanh toán thành công thì tổng tiền EConnect đã thu cho lớp đó là:

```text
3 * 50000 = 150000
```

## 9.3 Sau khi học viên thanh toán thành công

Khi callback/webhook xác nhận payment học phí thành công:

- `payments.status = paid`
- `bookings.status = confirmed`
- `bookings.payment_status = paid`
- `bookings.escrow_status = held`
- Tiền được giữ trong escrow của EConnect, chưa chuyển ngay cho Tutor

Nếu xảy ra race condition và lớp đã hết chỗ:

- giao dịch đến sau có thể bị oversell
- booking đó sẽ bị refund tự động
- khoản tiền đã refund không được tính vào payout cho Tutor

# 10. Quy tắc tính payout cho Tutor

## 10.1 Điều kiện tạo payout

Backend chỉ tạo payout cho Tutor khi tất cả điều kiện sau đều đúng:

- Lớp đã kết thúc ít nhất 2 giờ
- Lớp không có khiếu nại đang mở
- Tutor đã cập nhật đủ thông tin `bank_bin` và `bank_account_number`
- Vẫn còn escrow hợp lệ đang được giữ cho lớp đó

## 10.2 Công thức payout

Số tiền payout cho Tutor phải bằng đúng tổng số tiền mà các học viên hợp lệ đã đóng trước đó cho EConnect và vẫn còn đang bị giữ escrow cho lớp.

Công thức nghiệp vụ:

```text
tutor_payout_amount
  = tổng các payment tuition hợp lệ, hiện hành, chưa refund
```

Trong implementation hiện tại, chỉ các khoản sau mới được tính vào payout:

- `Booking.status` là `confirmed` hoặc `completed`
- `Booking.payment_status = paid`
- `Booking.escrow_status = held`
- `Payment.payment_type = tuition`
- `Payment.status = paid`
- `Payment.transaction_ref` phải khớp với `Booking.payment_reference` hiện tại

Điều này rất quan trọng vì nó loại bỏ:

- các giao dịch học phí cũ đã fail
- các giao dịch học phí cũ đã bị thay thế bởi payment mới
- các khoản đã refund
- các booking không còn hợp lệ để trả tiền cho Tutor

## 10.3 Ví dụ payout

Ví dụ lớp có:

- `class.price = 200000`
- `max_participants = 4`
- mỗi học viên đóng `50000`

Tình huống:

- 3 học viên thanh toán thành công
- 1 học viên chưa đóng
- 1 giao dịch cũ của học viên A từng fail trước đó

Khi đó:

```text
Tổng tiền EConnect đã thu hợp lệ = 3 * 50000 = 150000
Payout cho Tutor = 150000
```

Giao dịch fail của học viên A không được cộng vào payout.

## 10.4 Sau khi payout thành công

Khi payOS xác nhận payout thành công:

- `classes.tutor_payout_status = paid`
- `classes.tutor_payout_amount` được cập nhật bằng số tiền đã release thực tế
- `classes.tutor_paid_at` được gán thời điểm chi tiền
- Mỗi booking escrow hợp lệ trong lớp được chuyển sang:

```text
booking.status = completed
booking.escrow_status = released
payment.status = released
```

## 10.5 Khi nào Tutor không nhận đủ số tiền lý thuyết

Payout có thể nhỏ hơn tổng lý thuyết `class.price` trong các trường hợp:

- Chưa đủ học viên thanh toán thành công
- Số lượng học viên đăng ký thành công thấp hơn `max_participants` mà Tutor đã set khi tạo nhóm. Trong trường hợp lớp vẫn đạt `min_participants`, Tutor xác nhận dạy và buổi học vẫn diễn ra, hệ thống chỉ payout theo tổng tiền thực tế đã thu từ các học viên đã đăng ký thành công; các chỗ còn trống không phát sinh `tuition_amount` nên không được cộng vào `tutor_payout_amount`
- Một hoặc nhiều booking đã bị refund
- Có booking bị xác nhận khiếu nại hợp lệ
- Có học viên từng tạo payment nhưng payment đó fail hoặc bị thay thế bằng payment khác

Nói cách khác:

- `class.price` là giá trị mục tiêu của cả lớp
- `tutor_payout_amount` là số tiền thực tế đủ điều kiện để chi cho Tutor

# 11. Các field cần theo dõi trên app/admin

Để hiển thị đúng thông tin payment và payout, app/admin nên ưu tiên các field sau:

- `classes.creation_fee_amount`: phí tạo lớp
- `bookings.tuition_amount`: học phí của từng học viên
- `payments.amount`: số tiền của từng giao dịch
- `payments.status`: trạng thái giao dịch
- `bookings.escrow_status`: trạng thái escrow của booking
- `classes.tutor_payout_status`: trạng thái payout của Tutor
- `classes.tutor_payout_amount`: tổng số tiền sẽ/đã chi cho Tutor
- `payment summary.total_escrow_held`: tổng escrow đang giữ của lớp

Khuyến nghị cách đọc dữ liệu:

- Muốn biết học viên đóng bao nhiêu: đọc `booking.tuition_amount` hoặc `payment.amount` của giao dịch `tuition` hiện hành
- Muốn biết Tutor được nhận bao nhiêu: đọc `classes.tutor_payout_amount`
- Muốn biết lớp còn bao nhiêu tiền đang giữ: đọc `total_escrow_held`
