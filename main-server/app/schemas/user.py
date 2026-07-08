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
    device_id: Optional[str] = None
    device_type: Optional[str] = "mobile"


class DeviceInfo(BaseModel):
    device_id: str
    device_type: str
    last_login: datetime


class UserDevicesResponse(BaseModel):
    user_id: str
    device_limit: int
    devices: list[DeviceInfo]


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserCourseAccessCreate(BaseModel):
    course_id: str
    access_type: str = "full"
    access_duration: Optional[int] = None
    expires_at: Optional[datetime] = None


class QBankAccessCreate(BaseModel):
    qbank_id: str


class PanicModeConfigCreate(BaseModel):
    target_type: str = "global"
    target_value: Optional[str] = None
    webview_url: str
    is_active: bool = True


class PanicModeConfigResponse(BaseModel):
    id: str
    is_active: bool
    target_type: str
    target_value: Optional[str] = None
    webview_url: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AppHandshakeRequest(BaseModel):
    platform: str
    version: str
    build_number: str
    device_id: str


class AppHandshakeResponse(BaseModel):
    panic_mode: bool
    webview_url: Optional[str] = None
    user_token: Optional[str] = None
    device_id: Optional[str] = None
    server_mode: str = "hybrid"
    download_policy: str = "allow"
    mode_mismatch_action: str = "warn"
