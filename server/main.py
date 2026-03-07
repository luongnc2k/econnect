from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.profile_router import router as profile_router
from fastapi import Depends, HTTPException, StaticFiles
from models.base import Base
from database import engine
from routes import auth

app = FastAPI() # Tạo một instance của FastAPI để xây dựng ứng dụng API

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads") # Định nghĩa một route để phục vụ các tệp tĩnh (static files) từ thư mục "uploads". Khi có yêu cầu đến đường dẫn bắt đầu bằng "/uploads", FastAPI sẽ tìm kiếm tệp trong thư mục "uploads" và trả về nó nếu tồn tại.
# NOTE : Trong production, bạn nên sử dụng một dịch vụ lưu trữ tệp chuyên dụng như AWS S3 hoặc Google Cloud Storage thay vì phục vụ tệp trực tiếp từ server của bạn. 
# Điều này sẽ giúp cải thiện hiệu suất và độ tin cậy của ứng dụng của bạn.

app.add_middleware( # CORS middleware để cho phép truy cập từ client
    CORSMiddleware, 
    allow_origins=["*"], # Cho phép tất cả các nguồn (origin) truy cập vào API
    allow_credentials=False, # Cho phép gửi cookie và thông tin xác thực trong yêu cầu
    allow_methods=["*"], # Cho phép tất cả các phương thức HTTP (GET, POST, PUT, DELETE, v.v.) được sử dụng trong yêu cầu
    allow_headers=["*"], # Cho phép tất cả các header được gửi trong yêu cầu, bao gồm header tùy chỉnh và header tiêu chuẩn như Content-Type, Authorization, v.v.
)

app.include_router(auth.router, prefix="/auth") # Đăng ký router auth với tiền tố "/auth", tất cả các endpoint trong router này sẽ có đường dẫn bắt đầu bằng "/auth"
app.include_router(profile_router) # Đăng ký router profile_router, tất cả các endpoint trong router này sẽ có đường dẫn bắt đầu bằng "/profiles" (được định nghĩa trong profile_router.py)
Base.metadata.create_all(bind=engine) # Tạo tất cả các bảng trong cơ sở dữ liệu dựa trên các mô hình đã định nghĩa trong Base. Nếu bảng đã tồn tại, nó sẽ không bị ghi đè hoặc xóa đi.

