from pydantic import BaseModel
from typing import Literal


class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str
    role: Literal['student', 'teacher']
