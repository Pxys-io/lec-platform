from typing import Optional
from pydantic import BaseModel
from datetime import datetime


class ReportCreate(BaseModel):
    target_type: str
    target_id: str
    reason: str
    description: Optional[str] = None


class ReportUpdate(BaseModel):
    status: Optional[str] = None


class ReportResponse(BaseModel):
    id: str
    user_id: str
    target_type: str
    target_id: str
    reason: str
    description: Optional[str] = None
    status: str
    resolved_by: Optional[str] = None
    resolved_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class MessageCreate(BaseModel):
    recipient_id: str
    content: str


class MessageResponse(BaseModel):
    id: str
    sender_id: str
    recipient_id: str
    content: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AccessCodeCreate(BaseModel):
    course_id: Optional[str] = None
    lesson_id: Optional[str] = None
    access_type: str = "full"
    access_duration: Optional[int] = None
    expires_at: Optional[datetime] = None
    max_uses: Optional[int] = None


class AccessCodeResponse(BaseModel):
    id: str
    code: str
    course_id: Optional[str] = None
    lesson_id: Optional[str] = None
    access_type: str
    access_duration: Optional[int] = None
    expires_at: Optional[datetime] = None
    max_uses: Optional[int] = None
    current_uses: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AccessCodeValidate(BaseModel):
    code: str


class WatchHistoryCreate(BaseModel):
    lesson_id: str
    watch_time: float = 0.0
    completion_percentage: float = 0.0
    last_position: float = 0.0
    device_info: Optional[str] = None


class WatchHistoryResponse(BaseModel):
    id: str
    user_id: str
    lesson_id: str
    watch_time: float
    completion_percentage: float
    last_position: float
    updated_at: datetime

    class Config:
        from_attributes = True


class CertificateCreate(BaseModel):
    course_id: str
    title: str
    description: Optional[str] = None
    expiry_date: Optional[datetime] = None
    metadata_json: Optional[str] = None


class CertificateResponse(BaseModel):
    id: str
    user_id: str
    course_id: str
    title: str
    description: Optional[str] = None
    issued_at: datetime
    expiry_date: Optional[datetime] = None
    certificate_hash: str
    metadata_json: Optional[str] = None

    class Config:
        from_attributes = True


class StatsOverview(BaseModel):
    total_users: int
    total_courses: int
    total_lessons: int
    new_users_this_month: int
    active_users_this_month: int
    total_watch_time: float
    weekly_unique_users: list[dict] = []
    monthly_watch_stats: list[dict] = []


class InstructorStats(BaseModel):
    instructor_id: str
    email: str
    total_courses: int
    total_unique_users: int
    total_watch_time: float
    codes_generated: int
    codes_used: int


class CourseStats(BaseModel):
    course_id: str
    total_views: int
    unique_users: int
    average_completion: float
    lesson_stats: list[dict]
    near_ending_subscriptions: int = 0