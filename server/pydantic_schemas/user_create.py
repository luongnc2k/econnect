from pydantic import BaseModel
from typing import Literal

class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    role: Literal['student', 'tutor']