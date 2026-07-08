import uuid
from datetime import datetime
from typing import Optional, List
from sqlmodel import Field, SQLModel, Relationship
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from enum import Enum


class UserRole(str, Enum):
    STUDENT = "student"
    INSTRUCTOR = "instructor"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    email: str = Field(unique=True, index=True)
    password_hash: str
    phone: str
    role: UserRole = Field(default=UserRole.STUDENT)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: Optional[datetime] = Field(default=None, nullable=True)
    banned_until: Optional[datetime] = Field(default=None, nullable=True)
    device_limit: int = Field(default=2)


class UserDevice(SQLModel, table=True):
    __tablename__ = "user_devices"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", index=True)
    device_id: str = Field(index=True)
    device_type: str = Field(default="mobile")  # "mobile" or "desktop"
    last_login: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class UserProfile(SQLModel, table=True):
    __tablename__ = "user_profiles"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id", unique=True)
    first_name: str = ""
    last_name: str = ""
    avatar_url: Optional[str] = Field(default=None, nullable=True)


class UserCourseAccess(SQLModel, table=True):
    __tablename__ = "user_course_access"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    course_id: str = Field(foreign_key="courses.id")
    access_type: str = Field(default="full")
    expires_at: Optional[datetime] = Field(default=None, nullable=True)
    granted_by: Optional[str] = Field(default=None, foreign_key="users.id", nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class UserLessonAccess(SQLModel, table=True):
    __tablename__ = "user_lesson_access"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    lesson_id: str = Field(foreign_key="lessons.id")
    expires_at: Optional[datetime] = Field(default=None, nullable=True)
    granted_by: Optional[str] = Field(default=None, foreign_key="users.id", nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class AccessCodeUse(SQLModel, table=True):
    __tablename__ = "access_code_uses"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    access_code_id: str = Field(foreign_key="access_codes.id")
    user_id: str = Field(foreign_key="users.id")
    used_at: datetime = Field(default_factory=datetime.utcnow)


class PanicModeConfig(SQLModel, table=True):
    __tablename__ = "panic_mode_configs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    is_active: bool = Field(default=False)
    target_type: str = Field(default="global")  # global, user, platform, version, build
    target_value: Optional[str] = Field(default=None, nullable=True)
    webview_url: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)