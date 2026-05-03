from typing import Literal, Optional

from pydantic import BaseModel


class PublicUserSearchResult(BaseModel):
    id: str
    email: Optional[str] = None
    full_name: str
    avatar_url: Optional[str] = None
    role: Literal["student", "teacher", "admin"]
