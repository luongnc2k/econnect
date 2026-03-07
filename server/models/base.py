from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base() # Tạo một lớp cơ sở (base class) cho tất cả các mô hình (models) trong ứng dụng. 
# Lớp này sẽ được sử dụng để định nghĩa các bảng trong cơ sở dữ liệu và cung cấp các phương thức để tương tác với chúng.