from typing import Optional
from pydantic import BaseModel, EmailStr
from datetime import datetime


class UserBase(BaseModel):
    email: EmailStr
    phone: str


class UserCreate(UserBase):
    password: str
    role: str = "student"
    first_name: str = ""
    last_name: str = ""


class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    role: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None


class UserResponse(UserBase):
    id: str
    role: str
    created_at: datetime
    last_login: Optional[datetime]
    banned_until: Optional[datetime]
    first_name: str = ""
    last_name: str = ""
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserCourseAccessCreate(BaseModel):
    course_id: str
    access_type: str = "full"
    access_duration: Optional[int] = None
    expires_at: Optional[datetime] = None
