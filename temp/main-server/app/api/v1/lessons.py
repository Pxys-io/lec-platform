import json
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select

from app.core.database import get_db
from app.models import User, Course, Lesson, Material, Comment, UserRole, UserCourseAccess, UserLessonAccess, WatchHistory, QuizAttempt, LockType
from app.schemas import (
    LessonCreate,
    LessonUpdate,
    LessonResponse,
    MaterialCreate,
    MaterialResponse,
    CommentCreate,
    CommentResponse,
)
from app.api.v1.users import get_current_user, require_instructor


router = APIRouter(prefix="/lessons", tags=["lessons"])


def check_lesson_access(db: Session, user: User, lesson: Lesson) -> bool:
    if user.role in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        return True
    
    course = db.get(Course, lesson.course_id)
    if course.instructor_id == user.id:
        return True

    # Check individual lesson access
    lesson_access = db.exec(
        select(UserLessonAccess).where(
            (UserLessonAccess.user_id == user.id) & 
            (UserLessonAccess.lesson_id == lesson.id)
        )
    ).first()
    if lesson_access:
        from datetime import datetime
        if not lesson_access.expires_at or lesson_access.expires_at > datetime.utcnow():
            return True

    # Check course access
    access = db.exec(
        select(UserCourseAccess).where(
            (UserCourseAccess.user_id == user.id) & 
            (UserCourseAccess.course_id == lesson.course_id)
        )
    ).first()
    
    if not access and course.visibility != "public":
        # Check if it has 'default' tag
        tags = json.loads(course.tags) if course.tags else []
        if "default" not in tags:
            return False

    # Check locking logic
    if lesson.lock_type == LockType.NONE:
        return True
    
    # Get previous lesson
    prev_lesson = db.exec(
        select(Lesson)
        .where((Lesson.course_id == lesson.course_id) & (Lesson.order < lesson.order))
        .order_by(Lesson.order.desc())
    ).first()
    
    if not prev_lesson:
        return True # No previous lesson to lock on
    
    if lesson.lock_type == LockType.PREVIOUS_LESSON:
        history = db.exec(
            select(WatchHistory)
            .where((WatchHistory.user_id == user.id) & (WatchHistory.lesson_id == prev_lesson.id))
        ).first()
        if not history or history.completion_percentage < 90:
            return False
            
    elif lesson.lock_type == LockType.QUIZ:
        if not prev_lesson.quiz_id:
            return True
        attempt = db.exec(
            select(QuizAttempt)
            .where((QuizAttempt.user_id == user.id) & (QuizAttempt.quiz_id == prev_lesson.quiz_id))
            .order_by(QuizAttempt.completed_at.desc())
        ).first()
        if not attempt or not attempt.passed:
            return False
            
    return True


@router.get("/{lesson_id}", response_model=LessonResponse)
def get_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    if not check_lesson_access(db, user, lesson):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Lesson is locked or you don't have access"
        )

    return LessonResponse(
        id=lesson.id,
        course_id=lesson.course_id,
        title=lesson.title,
        description=lesson.description,
        order=lesson.order,
        video_id=lesson.video_id,
        lock_type=lesson.lock_type.value,
        quiz_id=lesson.quiz_id,
        is_published=lesson.is_published,
        created_at=lesson.created_at,
        updated_at=lesson.updated_at,
    )


@router.post("", response_model=LessonResponse)
def create_lesson(
    request: LessonCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = db.get(Course, request.course_id)
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot create lesson for this course")

    lesson = Lesson(
        course_id=request.course_id,
        title=request.title,
        description=request.description,
        order=request.order,
        lock_type=request.lock_type,
        is_published=request.is_published,
    )
    db.add(lesson)
    db.commit()
    db.refresh(lesson)

    return LessonResponse(
        id=lesson.id,
        course_id=lesson.course_id,
        title=lesson.title,
        description=lesson.description,
        order=lesson.order,
        video_id=lesson.video_id,
        lock_type=lesson.lock_type.value,
        quiz_id=lesson.quiz_id,
        is_published=lesson.is_published,
        created_at=lesson.created_at,
        updated_at=lesson.updated_at,
    )


@router.put("/{lesson_id}", response_model=LessonResponse)
def update_lesson(
    lesson_id: str,
    request: LessonUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    course = db.get(Course, lesson.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot update this lesson")

    if request.title is not None:
        lesson.title = request.title
    if request.description is not None:
        lesson.description = request.description
    if request.order is not None:
        lesson.order = request.order
    if request.video_id is not None:
        lesson.video_id = request.video_id
    if request.lock_type is not None:
        lesson.lock_type = request.lock_type
    if request.is_published is not None:
        lesson.is_published = request.is_published

    db.add(lesson)
    db.commit()
    db.refresh(lesson)

    return LessonResponse(
        id=lesson.id,
        course_id=lesson.course_id,
        title=lesson.title,
        description=lesson.description,
        order=lesson.order,
        video_id=lesson.video_id,
        lock_type=lesson.lock_type.value,
        quiz_id=lesson.quiz_id,
        is_published=lesson.is_published,
        created_at=lesson.created_at,
        updated_at=lesson.updated_at,
    )


@router.delete("/{lesson_id}")
def delete_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    course = db.get(Course, lesson.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot delete this lesson")

    db.delete(lesson)
    db.commit()

    return {"message": "Lesson deleted successfully"}


@router.get("/{lesson_id}/materials", response_model=list[MaterialResponse])
def get_lesson_materials(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    materials = db.exec(select(Material).where(Material.lesson_id == lesson_id)).all()

    return [
        MaterialResponse(
            id=m.id,
            lesson_id=m.lesson_id,
            type=m.type.value,
            title=m.title,
            url=m.url,
            file_size=m.file_size,
            created_at=m.created_at,
        )
        for m in materials
    ]


@router.post("/{lesson_id}/materials", response_model=MaterialResponse)
def create_material(
    lesson_id: str,
    request: MaterialCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    course = db.get(Course, lesson.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot add material to this lesson")

    material = Material(
        lesson_id=lesson_id,
        type=request.type,
        title=request.title,
        url=request.url,
        file_size=request.file_size,
    )
    db.add(material)
    db.commit()
    db.refresh(material)

    return MaterialResponse(
        id=material.id,
        lesson_id=material.lesson_id,
        type=material.type.value,
        title=material.title,
        url=material.url,
        file_size=material.file_size,
        created_at=material.created_at,
    )


@router.get("/{lesson_id}/comments", response_model=list[CommentResponse])
def get_lesson_comments(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    comments = db.exec(select(Comment).where(Comment.lesson_id == lesson_id)).all()

    result = []
    from app.models import UserProfile
    for comment in comments:
        profile = db.exec(select(UserProfile).where(UserProfile.user_id == comment.user_id)).first()
        result.append(CommentResponse(
            id=comment.id,
            user_id=comment.user_id,
            lesson_id=comment.lesson_id,
            content=comment.content,
            parent_id=comment.parent_id,
            is_edited=comment.is_edited,
            created_at=comment.created_at,
            updated_at=comment.updated_at,
            user_name=f"{profile.first_name} {profile.last_name}" if profile else "Unknown",
            user_avatar=profile.avatar_url if profile else None,
        ))

    return result


@router.post("/{lesson_id}/comments", response_model=CommentResponse)
def create_comment(
    lesson_id: str,
    request: CommentCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    comment = Comment(
        user_id=user.id,
        lesson_id=lesson_id,
        content=request.content,
        parent_id=request.parent_id,
    )
    db.add(comment)
    db.commit()
    db.refresh(comment)

    from app.models import UserProfile
    profile = db.exec(select(UserProfile).where(UserProfile.user_id == comment.user_id)).first()

    return CommentResponse(
        id=comment.id,
        user_id=comment.user_id,
        lesson_id=comment.lesson_id,
        content=comment.content,
        parent_id=comment.parent_id,
        is_edited=comment.is_edited,
        created_at=comment.created_at,
        updated_at=comment.updated_at,
        user_name=f"{profile.first_name} {profile.last_name}" if profile else "Unknown",
        user_avatar=profile.avatar_url if profile else None,
    )