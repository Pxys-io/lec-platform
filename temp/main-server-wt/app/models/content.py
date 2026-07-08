import uuid
from datetime import datetime
from typing import Optional, List
from sqlmodel import Field, SQLModel, Relationship
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from enum import Enum


class CourseVisibility(str, Enum):
    PUBLIC = "public"
    PRIVATE = "private"
    RESTRICTED = "restricted"


class LockType(str, Enum):
    NONE = "none"
    PREVIOUS_LESSON = "previous_lesson"
    QUIZ = "quiz"


class MaterialType(str, Enum):
    PDF = "pdf"
    DOCUMENT = "document"
    LINK = "link"
    IMAGE = "image"


class Course(SQLModel, table=True):
    __tablename__ = "courses"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    title: str
    description: str = ""
    instructor_id: str = Field(foreign_key="users.id")
    tags: str = Field(default="[]")
    visibility: CourseVisibility = Field(default=CourseVisibility.PRIVATE)
    thumbnail_url: Optional[str] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class EnrollmentFormConfig(SQLModel, table=True):
    __tablename__ = "enrollment_form_configs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    course_id: str = Field(foreign_key="courses.id", unique=True)
    
    # JSON string containing array of fields: [{label: str, type: str, required: bool, options: List[str]}]
    fields_json: str = Field(default="[]")
    
    # Whether to require images (e.g. proof of payment)
    require_images: bool = Field(default=False)
    image_count: int = Field(default=1)
    image_instructions: Optional[str] = Field(default=None)

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Lesson(SQLModel, table=True):
    __tablename__ = "lessons"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    course_id: str = Field(foreign_key="courses.id")
    title: str
    description: str = ""
    order: int = 0
    video_id: Optional[str] = Field(default=None, nullable=True)
    lock_type: LockType = Field(default=LockType.NONE)
    quiz_id: Optional[str] = Field(default=None, nullable=True, foreign_key="quizzes.id")
    is_published: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class Material(SQLModel, table=True):
    __tablename__ = "materials"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    lesson_id: str = Field(foreign_key="lessons.id")
    type: MaterialType = Field(default=MaterialType.PDF)
    title: str
    url: str
    file_size: Optional[int] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Quiz(SQLModel, table=True):
    __tablename__ = "quizzes"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    lesson_id: str = Field(foreign_key="lessons.id", unique=True)
    title: str
    description: Optional[str] = Field(default=None, nullable=True)
    passing_score: float = Field(default=70.0)
    time_limit: Optional[int] = Field(default=None, nullable=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Question(SQLModel, table=True):
    __tablename__ = "questions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    quiz_id: str = Field(foreign_key="quizzes.id")
    type: str = Field(default="multiple_choice")
    question: str
    options: Optional[str] = Field(default=None, nullable=True)
    correct_answer: str
    points: float = Field(default=1.0)
    order: int = 0


class QuizAttempt(SQLModel, table=True):
    __tablename__ = "quiz_attempts"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    quiz_id: str = Field(foreign_key="quizzes.id")
    answers: str = Field(default="{}")
    score: Optional[float] = Field(default=None, nullable=True)
    passed: Optional[bool] = Field(default=None, nullable=True)
    started_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = Field(default=None, nullable=True)


class Comment(SQLModel, table=True):
    __tablename__ = "comments"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="users.id")
    lesson_id: str = Field(foreign_key="lessons.id")
    content: str
    parent_id: Optional[str] = Field(default=None, nullable=True, foreign_key="comments.id")
    is_edited: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)