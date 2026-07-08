import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlmodel import Session, select

from app.core.database import get_db
from app.models import User, Course, UserRole, UserCourseAccess
from app.models.content import EnrollmentFormConfig
from app.models.interaction import EnrollmentRequest, EnrollmentRequestImage
from app.schemas.enrollment import (
    EnrollmentRequestCreate,
    EnrollmentRequestResponse,
    EnrollmentRequestImageResponse,
)
from app.api.v1.users import get_current_user, require_instructor


router = APIRouter(prefix="/enrollment", tags=["enrollment"])


@router.post("/request", response_model=EnrollmentRequestResponse)
def submit_enrollment_request(
    request: EnrollmentRequestCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Check if course exists
    course = db.get(Course, request.course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    # Check if already enrolled
    existing_access = db.exec(
        select(UserCourseAccess).where(
            UserCourseAccess.user_id == user.id,
            UserCourseAccess.course_id == request.course_id
        )
    ).first()
    if existing_access:
        raise HTTPException(status_code=400, detail="Already enrolled in this course")

    # Check if there is a pending request
    existing_request = db.exec(
        select(EnrollmentRequest).where(
            EnrollmentRequest.user_id == user.id,
            EnrollmentRequest.course_id == request.course_id,
            EnrollmentRequest.status == "pending"
        )
    ).first()
    if existing_request:
        raise HTTPException(status_code=400, detail="Enrollment request already pending")

    # Create request
    enroll_req = EnrollmentRequest(
        user_id=user.id,
        course_id=request.course_id,
        status="pending",
        form_data_json=json.dumps(request.form_data),
    )
    db.add(enroll_req)
    db.commit()
    db.refresh(enroll_req)

    # Add images
    for url in request.image_urls:
        img = EnrollmentRequestImage(
            request_id=enroll_req.id,
            url=url
        )
        db.add(img)
    
    db.commit()
    db.refresh(enroll_req)

    return _map_enrollment_request(enroll_req, db)


@router.get("/requests", response_model=list[EnrollmentRequestResponse])
def list_enrollment_requests(
    course_id: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    query = select(EnrollmentRequest)
    
    if status:
        query = query.where(EnrollmentRequest.status == status)
    
    if course_id:
        query = query.where(EnrollmentRequest.course_id == course_id)
    
    # Instructors can only see requests for their courses
    if user.role == UserRole.INSTRUCTOR:
        query = query.join(Course).where(Course.instructor_id == user.id)
    
    requests = db.exec(query.order_by(EnrollmentRequest.created_at.desc())).all()
    
    return [_map_enrollment_request(r, db) for r in requests]


@router.get("/requests/my", response_model=list[EnrollmentRequestResponse])
def list_my_enrollment_requests(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    requests = db.exec(
        select(EnrollmentRequest)
        .where(EnrollmentRequest.user_id == user.id)
        .order_by(EnrollmentRequest.created_at.desc())
    ).all()
    
    return [_map_enrollment_request(r, db) for r in requests]


@router.post("/requests/{request_id}/approve")
def approve_enrollment_request(
    request_id: str,
    admin_comment: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    enroll_req = db.get(EnrollmentRequest, request_id)
    if not enroll_req:
        raise HTTPException(status_code=404, detail="Request not found")

    course = db.get(Course, enroll_req.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized to approve for this course")

    if enroll_req.status != "pending":
        raise HTTPException(status_code=400, detail=f"Request is already {enroll_req.status}")

    enroll_req.status = "approved"
    enroll_req.admin_comment = admin_comment
    enroll_req.processed_at = datetime.utcnow()
    enroll_req.processed_by = user.id
    db.add(enroll_req)

    # Grant access
    access = UserCourseAccess(
        user_id=enroll_req.user_id,
        course_id=enroll_req.course_id,
        access_type="full",
        granted_by=user.id
    )
    db.add(access)
    
    db.commit()
    return {"message": "Request approved and access granted"}


@router.post("/requests/{request_id}/reject")
def reject_enrollment_request(
    request_id: str,
    admin_comment: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    enroll_req = db.get(EnrollmentRequest, request_id)
    if not enroll_req:
        raise HTTPException(status_code=404, detail="Request not found")

    course = db.get(Course, enroll_req.course_id)
    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(status_code=403, detail="Not authorized to reject for this course")

    if enroll_req.status != "pending":
        raise HTTPException(status_code=400, detail=f"Request is already {enroll_req.status}")

    enroll_req.status = "rejected"
    enroll_req.admin_comment = admin_comment
    enroll_req.processed_at = datetime.utcnow()
    enroll_req.processed_by = user.id
    db.add(enroll_req)
    
    db.commit()
    return {"message": "Request rejected"}


def _map_enrollment_request(r: EnrollmentRequest, db: Session) -> EnrollmentRequestResponse:
    images = db.exec(
        select(EnrollmentRequestImage).where(EnrollmentRequestImage.request_id == r.id)
    ).all()
    
    user = db.get(User, r.user_id)
    course = db.get(Course, r.course_id)
    
    return EnrollmentRequestResponse(
        id=r.id,
        user_id=r.user_id,
        course_id=r.course_id,
        status=r.status,
        form_data=json.loads(r.form_data_json),
        admin_comment=r.admin_comment,
        created_at=r.created_at,
        updated_at=r.updated_at,
        processed_at=r.processed_at,
        processed_by=r.processed_by,
        user_email=user.email if user else None,
        course_title=course.title if course else None,
        images=[
            EnrollmentRequestImageResponse(
                id=img.id,
                url=img.url,
                created_at=img.created_at
            ) for img in images
        ]
    )
