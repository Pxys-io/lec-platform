import json
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func

from app.core.database import get_db
from app.core.security import get_current_user_id, get_password_hash
from app.models import User, UserProfile, UserCourseAccess, UserRole, Course
from app.schemas import (
    UserCreate,
    UserUpdate,
    UserResponse,
    UserCourseAccessCreate,
    CourseResponse,
)


router = APIRouter(prefix="/users", tags=["users"])


def get_current_user(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> User:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    return user


def require_admin(user: User = Depends(get_current_user)):
    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required"
        )
    return user


def require_instructor(user: User = Depends(get_current_user)):
    if user.role not in [UserRole.INSTRUCTOR, UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Instructor access required"
        )
    return user


@router.get("", response_model=list[UserResponse])
def list_users(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, le=100),
    role: str = Query(None),
):
    query = select(User)
    if role:
        query = query.where(User.role == role)
    query = query.offset(skip).limit(limit)
    users = db.exec(query).all()

    result = []
    for user in users:
        profile = db.exec(
            select(UserProfile).where(UserProfile.user_id == user.id)
        ).first()
        result.append(
            UserResponse(
                id=user.id,
                email=user.email,
                phone=user.phone,
                role=user.role.value,
                created_at=user.created_at,
                last_login=user.last_login,
                banned_until=user.banned_until,
                first_name=profile.first_name if profile else "",
                last_name=profile.last_name if profile else "",
                avatar_url=profile.avatar_url if profile else None,
            )
        )
    return result


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    profile = db.exec(select(UserProfile).where(UserProfile.user_id == user.id)).first()
    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name if profile else "",
        last_name=profile.last_name if profile else "",
        avatar_url=profile.avatar_url if profile else None,
    )


@router.post("", response_model=UserResponse)
def create_user(
    request: UserCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    existing = db.exec(select(User).where(User.email == request.email)).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user = User(
        email=request.email,
        password_hash=get_password_hash(request.password),
        phone=request.phone,
        role=request.role,
    )
    db.add(user)
    db.flush()

    profile = UserProfile(
        user_id=user.id,
        first_name=request.first_name,
        last_name=request.last_name,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)

    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name,
        last_name=profile.last_name,
    )


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: str,
    request: UserUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    if request.email:
        user.email = request.email
    if request.phone:
        user.phone = request.phone
    if request.role is not None:
        if user.role == UserRole.SUPER_ADMIN and request.role != UserRole.SUPER_ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot change super admin role",
            )
        if admin.role != UserRole.SUPER_ADMIN and request.role in [
            UserRole.ADMIN,
            UserRole.SUPER_ADMIN,
        ]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only super admin can assign admin roles",
            )
        user.role = UserRole(request.role)
    db.add(user)
    db.flush()

    profile = db.exec(select(UserProfile).where(UserProfile.user_id == user.id)).first()
    if not profile:
        profile = UserProfile(user_id=user.id)
        db.add(profile)

    if request.first_name is not None:
        profile.first_name = request.first_name
    if request.last_name is not None:
        profile.last_name = request.last_name

    db.commit()
    db.refresh(user)
    db.refresh(profile)

    return UserResponse(
        id=user.id,
        email=user.email,
        phone=user.phone,
        role=user.role.value,
        created_at=user.created_at,
        last_login=user.last_login,
        banned_until=user.banned_until,
        first_name=profile.first_name or "",
        last_name=profile.last_name or "",
        avatar_url=profile.avatar_url,
    )


@router.delete("/{user_id}")
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    if user.role == UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete super admin"
        )

    db.delete(user)
    db.commit()

    return {"message": "User deleted successfully"}


@router.post("/{user_id}/ban")
def ban_user(
    user_id: str,
    ban_duration_days: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    if user.role == UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot ban super admin"
        )

    if ban_duration_days > 0:
        user.banned_until = datetime.utcnow() + timedelta(days=ban_duration_days)
    else:
        user.banned_until = datetime.utcnow() + timedelta(days=365 * 10)

    db.add(user)
    db.commit()

    return {"message": f"User banned for {ban_duration_days} days"}


@router.post("/{user_id}/unban")
def unban_user(
    user_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    user.banned_until = None
    db.add(user)
    db.commit()

    return {"message": "User unbanned successfully"}


@router.post("/{user_id}/access", response_model=dict)
def grant_access(
    user_id: str,
    request: UserCourseAccessCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    target_user = db.get(User, user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    course = db.get(Course, request.course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot grant access to this course",
        )

    access = UserCourseAccess(
        user_id=user_id,
        course_id=request.course_id,
        access_type=request.access_type,
        granted_by=user.id,
        expires_at=request.expires_at,
    )
    if request.access_duration:
        access.expires_at = datetime.utcnow() + timedelta(days=request.access_duration)

    db.add(access)
    db.commit()

    return {"message": "Access granted successfully", "access_id": access.id}


@router.get("/{user_id}/access", response_model=list[dict])
def get_user_accesses(
    user_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    target_user = db.get(User, user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )

    accesses = db.exec(
        select(UserCourseAccess).where(UserCourseAccess.user_id == user_id)
    ).all()

    result = []
    for acc in accesses:
        course = db.get(Course, acc.course_id)
        result.append(
            {
                "access_id": acc.id,
                "course_id": acc.course_id,
                "course_title": course.title if course else "Unknown",
                "access_type": acc.access_type,
                "expires_at": acc.expires_at,
                "granted_by": acc.granted_by,
                "created_at": acc.created_at,
            }
        )
    return result


@router.delete("/{user_id}/access/{access_id}")
def revoke_access(
    user_id: str,
    access_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    access = db.get(UserCourseAccess, access_id)
    if not access or access.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Access not found"
        )

    course = db.get(Course, access.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot revoke access to this course",
        )

    db.delete(access)
    db.commit()

    return {"message": "Access revoked successfully"}


@router.get("/me/courses", response_model=list[CourseResponse])
def get_my_courses(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if user.role in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        courses = db.exec(select(UserCourseAccess)).all()
        course_ids = list(set([c.course_id for c in courses]))
        courses = db.exec(
            select(UserCourseAccess).where(UserCourseAccess.course_id.in_(course_ids))
        ).all()
    else:
        accesses = db.exec(
            select(UserCourseAccess).where(UserCourseAccess.user_id == user.id)
        ).all()
        course_ids = [a.course_id for a in accesses]

    courses = []
    for course_id in course_ids:
        course = db.get(course_id, course_id)
        if course:
            courses.append(course)

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
