from sqlalchemy import LargeBinary, TEXT, Column, VARCHAR

from models.base import Base

class User(Base):
    __tablename__ = "users"
    id = Column(TEXT, primary_key=True)
    name = Column(VARCHAR(100))
    email = Column(VARCHAR(100), unique=True, index=True)
    password = Column(LargeBinary)