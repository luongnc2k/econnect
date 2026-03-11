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
