# EConnect Server

FastAPI backend cho EConnect. Xem hướng dẫn đầy đủ tại [README gốc](../README.md).

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


Swagger UI: http://localhost:8000/docs

## Payment Gateway

Backend da ho tro tao payment URL va verify callback cho:

- MoMo: `POST /payments/class-creation/request`, `POST /payments/classes/{class_id}/join/request`, callback qua `/payments/providers/momo/ipn` va `/payments/providers/momo/return`
- VNPAY: tao redirect URL ky so, callback qua `/payments/providers/vnpay/return`

Can cau hinh them trong `.env`:

```env
PAYMENT_PUBLIC_BASE_URL=http://127.0.0.1:8000
PAYMENT_GATEWAY_MODE=mock
MOMO_PARTNER_CODE=...
MOMO_ACCESS_KEY=...
MOMO_SECRET_KEY=...
VNPAY_TMN_CODE=...
VNPAY_HASH_SECRET=...
```

Mock mode:

- Khi `PAYMENT_GATEWAY_MODE=mock`, backend se tra `redirect_url` ve trang mock checkout noi bo.
- Trang mock co 2 nut thanh cong/that bai va se goi lai backend nhu mot PSP gia lap.
- Dung de test end-to-end local cung client polling ma khong can credential sandbox hay public callback URL.
