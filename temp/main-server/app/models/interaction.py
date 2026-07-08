import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import Field, SQLModel, Relationship


class EnrollmentRequest(SQLModel, table=True):
    __tablename__ = "enrollment_requests"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    course_id: str = Field(foreign_key="courses.id")
    
    status: str = Field(default="pending") # pending, approved, rejected
    
    # JSON string containing submitted values: {label: value}
    form_data_json: str = Field(default="{}")
    
    admin_comment: Optional[str] = Field(default=None)
    
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    processed_at: Optional[datetime] = Field(default=None)
    processed_by: Optional[str] = Field(default=None, foreign_key="users.id")


class EnrollmentRequestImage(SQLModel, table=True):
    __tablename__ = "enrollment_request_images"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    request_id: str = Field(foreign_key="enrollment_requests.id")
    url: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


class QBankEnrollment(SQLModel, table=True):
    __tablename__ = "qbank_enrollments"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    qbank_id: str = Field(foreign_key="qbanks.id")
    status: str = Field(default="pending") # pending, approved, rejected
    form_data_json: str = Field(default="{}")
    expires_at: Optional[datetime] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class QBankSession(SQLModel, table=True):
    __tablename__ = "qbank_sessions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    qbank_id: str = Field(foreign_key="qbanks.id")
    title: str
    config_json: str = Field(default="{}") # {subjects: [], mode: str, count: int}
    questions_json: str = Field(default="[]") # List of question IDs
    answers_json: str = Field(default="{}") # {question_id: answer}
    score: Optional[float] = Field(default=None, nullable=True)
    completed_at: Optional[datetime] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Report(SQLModel, table=True):
    __tablename__ = "reports"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    target_type: str
    target_id: str
    reason: str
    description: Optional[str] = Field(default=None, nullable=True)
    status: str = Field(default="pending")
    resolved_by: Optional[str] = Field(default=None, nullable=True, foreign_key="users.id")
    resolved_at: Optional[datetime] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    sender_id: str = Field(foreign_key="users.id")
    recipient_id: str = Field(foreign_key="users.id")
    content: str
    is_read: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class AccessCode(SQLModel, table=True):
    __tablename__ = "access_codes"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    code: str = Field(unique=True, index=True)
    created_by: str = Field(foreign_key="users.id")
    course_id: Optional[str] = Field(default=None, nullable=True, foreign_key="courses.id")
    lesson_id: Optional[str] = Field(default=None, nullable=True, foreign_key="lessons.id")
    access_type: str = Field(default="full")
    access_duration: Optional[int] = Field(default=None, nullable=True)
    expires_at: Optional[datetime] = Field(default=None, nullable=True)
    max_uses: Optional[int] = Field(default=None, nullable=True)
    current_uses: int = Field(default=0)
    is_active: bool = Field(default=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    used_at: Optional[datetime] = Field(default=None, nullable=True)


class WatchHistory(SQLModel, table=True):
    __tablename__ = "watch_history"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    lesson_id: str = Field(foreign_key="lessons.id")
    watch_time: float = Field(default=0.0)
    completion_percentage: float = Field(default=0.0)
    last_position: float = Field(default=0.0)
    device_info: Optional[str] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Certificate(SQLModel, table=True):
    __tablename__ = "certificates"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    course_id: str = Field(foreign_key="courses.id")
    title: str
    description: Optional[str] = Field(default=None, nullable=True)
    issued_at: datetime = Field(default_factory=datetime.utcnow)
    expiry_date: Optional[datetime] = Field(default=None, nullable=True)
    certificate_hash: str = Field(unique=True, index=True)
    metadata_json: Optional[str] = Field(default=None, nullable=True)


class UserActivity(SQLModel, table=True):
    __tablename__ = "user_activities"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    action: str
    target_type: Optional[str] = Field(default=None, nullable=True)
    target_id: Optional[str] = Field(default=None, nullable=True)
    extra_data: Optional[str] = Field(default=None, nullable=True)
    ip_address: Optional[str] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)