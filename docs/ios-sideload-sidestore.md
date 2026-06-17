# Cài app iOS bằng SideStore trên Linux (không cần Apple Developer)

Hướng dẫn sideload `econnect` lên iPhone (iOS 17+) bằng **SideStore**, dùng
**Apple ID miễn phí**, từ máy **Linux**.

## ⚠️ Giới hạn phải biết trước

- **Push notification (FCM) KHÔNG chạy** — Apple ID free không có entitlement push.
- App **hết hạn sau 7 ngày**, phải refresh lại (SideStore refresh được qua WiFi).
- Tối đa **3 app** đang ký cùng lúc trên 1 thiết bị với Apple ID free.
- Nên dùng một **Apple ID phụ** (không phải tài khoản chính), vì phải nhập vào SideStore.

---

## Bước 0 — Lấy file `.ipa`

CI (`Build App` workflow) đã build và xuất artifact `econnect-ios-unsigned`
chứa `econnect-unsigned.ipa`.

```bash
gh run download <RUN_ID> -n econnect-ios-unsigned -D ~/Downloads/econnect
# file: ~/Downloads/econnect/econnect-unsigned.ipa
```

---

## Bước 1 — Cài công cụ trên Linux

```bash
sudo apt update
sudo apt install -y libimobiledevice-utils usbmuxd
```

Cắm iPhone qua USB, mở khoá máy, bấm **Trust / Tin cậy** khi iPhone hỏi.
Kiểm tra:

```bash
idevice_id -l        # phải in ra UDID cua iPhone
ideviceinfo -k ProductVersion   # xac nhan phien ban iOS
```

---

## Bước 2 — Tạo file pairing

SideStore cần file pairing để tự refresh app trên máy.

```bash
idevicepair pair          # bam Trust tren iPhone neu duoc hoi
idevicepair validate
```

Xuất pairing file (định dạng SideStore cần — `ALTPairingFile.mobiledevicepairing`):

```bash
# Pairing record nam trong /var/lib/lockdown (hoac /var/db/lockdown)
sudo cp /var/lib/lockdown/$(idevice_id -l).plist ~/Downloads/econnect/ALTPairingFile.mobiledevicepairing
sudo chown $USER ~/Downloads/econnect/ALTPairingFile.mobiledevicepairing
```

> Nếu không thấy thư mục `/var/lib/lockdown`, thử `/var/db/lockdown` hoặc
> `~/.cache/libimobiledevice`. File có thể tên theo UDID hoặc không.

---

## Bước 3 — Cài SideStore lên iPhone

SideStore cần được sideload **một lần đầu**. Trên Linux không có AltServer, nên
dùng web installer chính thức của SideStore:

1. Tải `SideStore.ipa` mới nhất: https://github.com/SideStore/SideStore/releases
2. Mở trang cài qua trình duyệt trên iPhone theo hướng dẫn tại
   https://sidestore.io/ (mục **Installation → without a computer / pairing file**),
   nạp `ALTPairingFile.mobiledevicepairing` ở Bước 2.
3. Sau khi SideStore xuất hiện trên màn hình chính: vào **Settings → General →
   VPN & Device Management → Developer App**, bấm **Trust** cho profile.

> SideStore dùng một **anisette server** để xác thực Apple ID. Mục Settings
> trong SideStore đã cấu hình sẵn server mặc định; nếu lỗi đăng nhập, đổi sang
> anisette server khác trong danh sách.

---

## Bước 4 — Đăng nhập Apple ID & sideload econnect

1. Mở **SideStore → Settings → đăng nhập Apple ID** (nên dùng tài khoản phụ).
   - Nếu bật 2FA: tạo **app-specific password** tại https://appleid.apple.com
     và dùng mật khẩu đó.
2. Tab **My Apps → dấu `+`** → chọn `econnect-unsigned.ipa`.
3. SideStore ký bằng Apple ID free rồi cài. Xong, mở app trên màn hình chính.

---

## Bước 5 — Refresh mỗi 7 ngày

App hết hạn sau 7 ngày. Để gia hạn:

- Mở **SideStore → My Apps → Refresh All** (cần iPhone và một thiết bị chạy
  SideStore refresh cùng mạng WiFi, hoặc bật tính năng background refresh của
  SideStore).
- Refresh **trước khi** hết hạn, nếu không phải sideload lại từ đầu.

---

## Sự cố thường gặp

| Lỗi | Cách xử lý |
|---|---|
| `idevice_id -l` không ra gì | Cắm lại cáp, mở khoá máy, bấm Trust; `systemctl restart usbmuxd` |
| Đăng nhập Apple ID thất bại | Dùng app-specific password (2FA); đổi anisette server |
| "Maximum number of apps" | Apple ID free chỉ 3 app — xoá bớt app sideload khác |
| App mở lên crash / không gọi được server | Kiểm tra build có `--dart-define=SERVER_URL=...` đúng cloud chưa |
| Push không nhận | Đây là giới hạn Apple ID free, không khắc phục được (cần tài khoản trả phí) |
