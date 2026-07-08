import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import text
from sqlmodel import Session, select

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.models import User, Course, Lesson, UserCourseAccess, UserRole
from app.schemas import CourseCreate, CourseUpdate, CourseResponse, LessonResponse
from app.api.v1.users import get_current_user, require_instructor


router = APIRouter(prefix="/courses", tags=["courses"])


@router.get("", response_model=list[CourseResponse])
def list_courses(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    tag: str = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, le=100),
):
    query = select(Course)

    # Base visibility filtering
    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        if user.role == UserRole.INSTRUCTOR:
            # Instructors see their own courses plus public/default/granted
            query = query.where(
                (Course.instructor_id == user.id)
                | (Course.visibility == "public")
                | (Course.tags.like('%"default"%'))
                | (
                    (Course.visibility == "restricted")
                    & (
                        Course.id.in_(
                            select(UserCourseAccess.course_id).where(
                                UserCourseAccess.user_id == user.id
                            )
                        )
                    )
                )
            )
        else:
            # Students see public, default-tagged, or explicitly granted courses
            query = query.where(
                (Course.visibility == "public")
                | (Course.tags.like('%"default"%'))
                | (
                    (Course.visibility == "restricted")
                    & (
                        Course.id.in_(
                            select(UserCourseAccess.course_id).where(
                                UserCourseAccess.user_id == user.id
                            )
                        )
                    )
                )
            )

    courses = db.exec(query.offset(skip).limit(limit)).all()

    result = []
    for course in courses:
        tags = json.loads(course.tags) if course.tags else []
        result.append(
            CourseResponse(
                id=course.id,
                title=course.title,
                description=course.description,
                instructor_id=course.instructor_id,
                visibility=course.visibility.value,
                thumbnail_url=course.thumbnail_url,
                tags=tags,
                created_at=course.created_at,
                updated_at=course.updated_at,
            )
        )

    if tag:
        result = [c for c in result if tag in c.tags]

    return result


@router.get("/latest", response_model=list[CourseResponse])
def get_latest_courses(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    limit: int = Query(10, le=50),
):
    query = select(Course).order_by(Course.created_at.desc())

    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        query = query.where(
            (Course.visibility == "public")
            | (Course.tags.like('%"default"%'))
            | (
                (Course.visibility == "restricted")
                & (
                    Course.id.in_(
                        select(UserCourseAccess.course_id).where(
                            UserCourseAccess.user_id == user.id
                        )
                    )
                )
            )
        )

    courses = db.exec(query.limit(limit)).all()

    result = []
    for course in courses:
        tags = json.loads(course.tags) if course.tags else []
        result.append(
            CourseResponse(
                id=course.id,
                title=course.title,
                description=course.description,
                instructor_id=course.instructor_id,
                visibility=course.visibility.value,
                thumbnail_url=course.thumbnail_url,
                tags=tags,
                created_at=course.created_at,
                updated_at=course.updated_at,
            )
        )
    return result


@router.get("/{course_id}", response_model=CourseResponse)
def get_course(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    if (
        user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]
        and course.instructor_id != user.id
    ):
        # Check if user has explicit access
        access = db.exec(
            select(UserCourseAccess).where(
                (UserCourseAccess.user_id == user.id)
                & (UserCourseAccess.course_id == course_id)
            )
        ).first()

        if not access:
            if course.visibility == "private":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Course not accessible",
                )

            if course.visibility == "restricted":
                # Check if it has 'default' tag
                tags = json.loads(course.tags) if course.tags else []
                if "default" not in tags:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied to this course",
                    )

    tags = json.loads(course.tags) if course.tags else []
    return CourseResponse(
        id=course.id,
        title=course.title,
        description=course.description,
        instructor_id=course.instructor_id,
        visibility=course.visibility.value,
        thumbnail_url=course.thumbnail_url,
        tags=tags,
        created_at=course.created_at,
        updated_at=course.updated_at,
    )


@router.post("", response_model=CourseResponse)
def create_course(
    request: CourseCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = Course(
        title=request.title,
        description=request.description,
        instructor_id=user.id,
        visibility=request.visibility,
        thumbnail_url=request.thumbnail_url,
        tags=json.dumps(request.tags),
    )
    db.add(course)
    db.commit()
    db.refresh(course)

    if user.role != UserRole.INSTRUCTOR:
        access = UserCourseAccess(
            user_id=user.id,
            course_id=course.id,
            access_type="full",
            granted_by=user.id,
        )
        db.add(access)
        db.commit()

    tags = json.loads(course.tags) if course.tags else []
    return CourseResponse(
        id=course.id,
        title=course.title,
        description=course.description,
        instructor_id=course.instructor_id,
        visibility=course.visibility.value,
        thumbnail_url=course.thumbnail_url,
        tags=tags,
        created_at=course.created_at,
        updated_at=course.updated_at,
    )


@router.put("/{course_id}", response_model=CourseResponse)
def update_course(
    course_id: str,
    request: CourseUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Cannot update this course"
        )

    if request.title is not None:
        course.title = request.title
    if request.description is not None:
        course.description = request.description
    if request.visibility is not None:
        course.visibility = request.visibility
    if request.thumbnail_url is not None:
        course.thumbnail_url = request.thumbnail_url
    if request.tags is not None:
        course.tags = json.dumps(request.tags)

    db.add(course)
    db.commit()
    db.refresh(course)

    tags = json.loads(course.tags) if course.tags else []
    return CourseResponse(
        id=course.id,
        title=course.title,
        description=course.description,
        instructor_id=course.instructor_id,
        visibility=course.visibility.value,
        thumbnail_url=course.thumbnail_url,
        tags=tags,
        created_at=course.created_at,
        updated_at=course.updated_at,
    )


@router.delete("/{course_id}")
def delete_course(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Cannot delete this course"
        )

    db.delete(course)
    db.commit()

    return {"message": "Course deleted successfully"}


@router.get("/{course_id}/lessons", response_model=list[LessonResponse])
def list_course_lessons(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    lessons = db.exec(
        select(Lesson).where(Lesson.course_id == course_id).order_by(Lesson.order)
    ).all()

    return [
        LessonResponse(
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
        for lesson in lessons
    ]


@router.get("/{course_id}/stats", response_model=dict)
def get_course_stats(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot view stats for this course",
        )

    accesses = db.exec(
        select(UserCourseAccess).where(UserCourseAccess.course_id == course_id)
    ).all()
    unique_users = len(set([a.user_id for a in accesses]))

    lessons = db.exec(select(Lesson).where(Lesson.course_id == course_id)).all()

    return {
        "course_id": course_id,
        "total_enrolled": len(accesses),
        "unique_users": unique_users,
        "total_lessons": len(lessons),
    }

from app.models.content import EnrollmentFormConfig
from app.schemas.enrollment import EnrollmentFormConfigCreate, EnrollmentFormConfigResponse, EnrollmentFormField

@router.get("/{course_id}/enrollment-config", response_model=EnrollmentFormConfigResponse)
def get_enrollment_config(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    config = db.exec(
        select(EnrollmentFormConfig).where(EnrollmentFormConfig.course_id == course_id)
    ).first()
    
    if not config:
        # Return a default empty config if none exists
        return EnrollmentFormConfigResponse(
            id="none",
            course_id=course_id,
            fields=[],
            require_images=False,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
    
    fields = [EnrollmentFormField(**f) for f in json.loads(config.fields_json)]
    
    return EnrollmentFormConfigResponse(
        id=config.id,
        course_id=config.course_id,
        fields=fields,
        require_images=config.require_images,
        image_count=config.image_count,
        image_instructions=config.image_instructions,
        created_at=config.created_at,
        updated_at=config.updated_at
    )


@router.post("/{course_id}/enrollment-config", response_model=EnrollmentFormConfigResponse)
def update_enrollment_config(
    course_id: str,
    request: EnrollmentFormConfigCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
        
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    config = db.exec(
        select(EnrollmentFormConfig).where(EnrollmentFormConfig.course_id == course_id)
    ).first()
    
    fields_data = [f.dict() for f in request.fields]
    
    if not config:
        config = EnrollmentFormConfig(
            course_id=course_id,
            fields_json=json.dumps(fields_data),
            require_images=request.require_images,
            image_count=request.image_count,
            image_instructions=request.image_instructions
        )
    else:
        config.fields_json = json.dumps(fields_data)
        config.require_images = request.require_images
        config.image_count = request.image_count
        config.image_instructions = request.image_instructions
        config.updated_at = datetime.utcnow()
        
    db.add(config)
    db.commit()
    db.refresh(config)
    
    return get_enrollment_config(course_id, db, user)
