from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime


class CourseBase(BaseModel):
    title: str
    description: str = ""
    visibility: str = "private"
    thumbnail_url: Optional[str] = None
    tags: List[str] = []


class CourseCreate(CourseBase):
    pass


class CourseUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    visibility: Optional[str] = None
    thumbnail_url: Optional[str] = None
    tags: Optional[List[str]] = None


class CourseResponse(CourseBase):
    id: str
    instructor_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class LessonBase(BaseModel):
    title: str
    description: str = ""
    order: int = 0
    lock_type: str = "none"
    is_published: bool = False


class LessonCreate(LessonBase):
    course_id: str


class LessonUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    order: Optional[int] = None
    video_id: Optional[str] = None
    lock_type: Optional[str] = None
    is_published: Optional[bool] = None


class LessonResponse(LessonBase):
    id: str
    course_id: str
    video_id: Optional[str] = None
    quiz_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MaterialBase(BaseModel):
    type: str = "pdf"
    title: str
    url: str
    file_size: Optional[int] = None


class MaterialCreate(MaterialBase):
    lesson_id: str


class MaterialResponse(MaterialBase):
    id: str
    lesson_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class QuizBase(BaseModel):
    title: str
    description: Optional[str] = None
    passing_score: float = 70.0
    time_limit: Optional[int] = None


class QuizCreate(QuizBase):
    lesson_id: str


class QuizUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    passing_score: Optional[float] = None
    time_limit: Optional[int] = None


class QuizResponse(QuizBase):
    id: str
    lesson_id: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class QBankBase(BaseModel):
    title: str
    description: str = ""
    visibility: str = "private"
    thumbnail_url: Optional[str] = None
    tags: List[str] = []
    price: float = 0.0


class QBankCreate(QBankBase):
    pass


class QBankUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    visibility: Optional[str] = None
    thumbnail_url: Optional[str] = None
    tags: Optional[List[str]] = None
    price: Optional[float] = None


class QBankResponse(QBankBase):
    id: str
    instructor_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class QuestionBase(BaseModel):
    type: str = "multiple_choice"
    question: str
    options: Optional[List[str]] = None
    correct_answer: str
    explanation: Optional[str] = None
    points: float = 1.0
    tags: List[str] = []
    order: int = 0


class QuestionCreate(QuestionBase):
    quiz_id: Optional[str] = None
    qbank_id: Optional[str] = None


class QuestionResponse(QuestionBase):
    id: str
    quiz_id: Optional[str] = None
    qbank_id: Optional[str] = None

    class Config:
        from_attributes = True


class QuizSubmit(BaseModel):
    answers: dict


class QuizAttemptResponse(BaseModel):
    id: str
    quiz_id: str
    score: Optional[float] = None
    passed: Optional[bool] = None
    started_at: datetime
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CommentBase(BaseModel):
    content: str
    parent_id: Optional[str] = None


class CommentCreate(CommentBase):
    lesson_id: str


class CommentResponse(CommentBase):
    id: str
    user_id: str
    lesson_id: str
    is_edited: bool
    created_at: datetime
    updated_at: datetime
    user_name: str = ""
    user_avatar: Optional[str] = None

    class Config:
        from_attributes = True