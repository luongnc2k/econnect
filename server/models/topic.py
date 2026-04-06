from sqlalchemy import Boolean, Column, TEXT, VARCHAR
from models.base import Base


class Topic(Base):
    __tablename__ = "topics"

    id = Column(TEXT, primary_key=True)
    name = Column(VARCHAR(100), nullable=False)
    slug = Column(VARCHAR(100), unique=True, nullable=False)
    description = Column(TEXT, nullable=True)
    icon = Column(VARCHAR(10), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
