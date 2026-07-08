import json
import os
import uuid
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query, File, UploadFile, Request
from sqlmodel import Session, select, func

from app.core.database import get_db
from app.core.security import get_optional_current_user_id
from app.models import (
    User,
    Course,
    Lesson,
    Material,
    AccessCode,
    AccessCodeUse,
    Report,
    Message,
    WatchHistory,
    UserActivity,
    UserRole,
    UserCourseAccess,
    Certificate,
    Quiz,
    QuizAttempt,
    PanicModeConfig,
    QBankEnrollment,
    QBankSession,
    ServerConfig,
    VideoModePolicy,
)
from app.schemas import (
    MaterialCreate,
    MaterialResponse,
    AccessCodeCreate,
    AccessCodeResponse,
    AccessCodeValidate,
    ReportCreate,
    ReportUpdate,
    ReportResponse,
    MessageCreate,
    MessageResponse,
    WatchHistoryCreate,
    WatchHistoryResponse,
    CertificateCreate,
    CertificateResponse,
    StatsOverview,
    InstructorStats,
    CourseStats,
    AppHandshakeRequest,
    AppHandshakeResponse,
    PanicModeConfigCreate,
    PanicModeConfigResponse,
    ServerConfigCreate,
    ServerConfigResponse,
    VideoModePolicyCreate,
    VideoModePolicyUpdate,
    VideoModePolicyResponse,
)
from app.api.v1.users import get_current_user, require_instructor
import hashlib
from sqlmodel import func


materials_router = APIRouter(prefix="/materials", tags=["materials"])
codes_router = APIRouter(prefix="/codes", tags=["codes"])
reports_router = APIRouter(prefix="/reports", tags=["reports"])
stats_router = APIRouter(prefix="/stats", tags=["stats"])
messages_router = APIRouter(prefix="/messages", tags=["messages"])
videos_router = APIRouter(prefix="/videos", tags=["videos"])
misc_router = APIRouter(prefix="/misc", tags=["misc"])
certificates_router = APIRouter(prefix="/certificates", tags=["certificates"])


@misc_router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    from app.core.config import settings

    # In a real app, upload to S3/R2. For now, save locally.
    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)

    file_id = str(uuid.uuid4())
    ext = os.path.splitext(file.filename)[1]
    file_path = os.path.join(upload_dir, f"{file_id}{ext}")

    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())

    return {"url": f"{settings.MAIN_SERVER_URL}/{file_path}"}


@misc_router.post("/handshake", response_model=AppHandshakeResponse)
async def app_handshake(
    request: AppHandshakeRequest,
    db: Session = Depends(get_db),
    user_id: Optional[str] = Depends(get_optional_current_user_id),
):
    configs = db.exec(
        select(PanicModeConfig).where(PanicModeConfig.is_active == True)
    ).all()

    panic_mode = False
    webview_url = None

    for config in configs:
        if config.target_type == "global":
            panic_mode = True
            webview_url = config.webview_url
            break
        elif config.target_type == "user" and config.target_value == user_id:
            panic_mode = True
            webview_url = config.webview_url
            break
        elif (
            config.target_type == "platform" and config.target_value == request.platform
        ):
            panic_mode = True
            webview_url = config.webview_url
            break
        elif config.target_type == "version" and config.target_value == request.version:
            panic_mode = True
            webview_url = config.webview_url
            break
        elif (
            config.target_type == "build"
            and config.target_value == request.build_number
        ):
            panic_mode = True
            webview_url = config.webview_url
            break

    server_mode = "hybrid"
    download_policy = "allow"
    mode_mismatch_action = "warn"
    server_mode_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "server_mode")
    ).first()
    download_policy_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "download_policy")
    ).first()
    mismatch_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "mode_mismatch_action")
    ).first()
    if server_mode_cfg:
        server_mode = server_mode_cfg.value
    if download_policy_cfg:
        download_policy = download_policy_cfg.value
    if mismatch_cfg:
        mode_mismatch_action = mismatch_cfg.value

    return AppHandshakeResponse(
        panic_mode=panic_mode,
        webview_url=webview_url,
        user_token=None,
        device_id=request.device_id,
        server_mode=server_mode,
        download_policy=download_policy,
        mode_mismatch_action=mode_mismatch_action,
    )


@misc_router.get("/panic-mode", response_model=List[PanicModeConfigResponse])
def get_panic_mode_configs(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    return db.exec(select(PanicModeConfig)).all()


@misc_router.post("/panic-mode", response_model=PanicModeConfigResponse)
def create_panic_mode_config(
    request: PanicModeConfigCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    config = PanicModeConfig(
        is_active=request.is_active,
        target_type=request.target_type,
        target_value=request.target_value,
        webview_url=request.webview_url,
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    return config


@misc_router.put("/panic-mode/{config_id}", response_model=PanicModeConfigResponse)
def update_panic_mode_config(
    config_id: str,
    request: PanicModeConfigCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    config = db.get(PanicModeConfig, config_id)
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Config not found"
        )

    config.is_active = request.is_active
    config.target_type = request.target_type
    config.target_value = request.target_value
    config.webview_url = request.webview_url
    config.updated_at = datetime.utcnow()

    db.add(config)
    db.commit()
    db.refresh(config)
    return config


@misc_router.delete("/panic-mode/{config_id}")
def delete_panic_mode_config(
    config_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    config = db.get(PanicModeConfig, config_id)
    if not config:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Config not found"
        )
    db.delete(config)
    db.commit()
    return {"message": "Config deleted successfully"}


@materials_router.get("/{material_id}", response_model=MaterialResponse)
def get_material(
    material_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    material = db.get(Material, material_id)
    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Material not found"
        )

    return MaterialResponse(
        id=material.id,
        lesson_id=material.lesson_id,
        type=material.type.value,
        title=material.title,
        url=material.url,
        file_size=material.file_size,
        created_at=material.created_at,
    )


@materials_router.delete("/{material_id}")
def delete_material(
    material_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    material = db.get(Material, material_id)
    if not material:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Material not found"
        )

    lesson = db.get(Lesson, material.lesson_id)
    course = db.get(Course, lesson.course_id)

    if user.role == UserRole.INSTRUCTOR and course.instructor_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Cannot delete this material"
        )

    db.delete(material)
    db.commit()

    return {"message": "Material deleted successfully"}


@codes_router.get("", response_model=list[AccessCodeResponse])
def list_codes(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    codes = db.exec(select(AccessCode).where(AccessCode.created_by == user.id)).all()

    return [
        AccessCodeResponse(
            id=c.id,
            code=c.code,
            course_id=c.course_id,
            lesson_id=c.lesson_id,
            access_type=c.access_type,
            access_duration=c.access_duration,
            expires_at=c.expires_at,
            max_uses=c.max_uses,
            current_uses=c.current_uses,
            is_active=c.is_active,
            created_at=c.created_at,
        )
        for c in codes
    ]


@codes_router.post("", response_model=AccessCodeResponse)
def create_code(
    request: AccessCodeCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    code_str = uuid.uuid4().hex[:12].upper()

    code = AccessCode(
        code=code_str,
        created_by=user.id,
        course_id=request.course_id,
        lesson_id=request.lesson_id,
        access_type=request.access_type,
        access_duration=request.access_duration,
        expires_at=request.expires_at,
        max_uses=request.max_uses,
    )
    db.add(code)
    db.commit()
    db.refresh(code)

    return AccessCodeResponse(
        id=code.id,
        code=code.code,
        course_id=code.course_id,
        lesson_id=code.lesson_id,
        access_type=code.access_type,
        access_duration=code.access_duration,
        expires_at=code.expires_at,
        max_uses=code.max_uses,
        current_uses=code.current_uses,
        is_active=code.is_active,
        created_at=code.created_at,
    )


@codes_router.get("/{code}")
def get_code(
    code: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    code_obj = db.exec(select(AccessCode).where(AccessCode.code == code)).first()
    if not code_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Code not found"
        )

    return {
        "code": code_obj.code,
        "current_uses": code_obj.current_uses,
        "is_active": code_obj.is_active,
    }


@codes_router.post("/validate")
def validate_code(
    request: AccessCodeValidate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    code_obj = db.exec(
        select(AccessCode).where(AccessCode.code == request.code)
    ).first()
    if not code_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Invalid code"
        )

    if not code_obj.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Code is inactive"
        )

    if code_obj.expires_at and code_obj.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Code has expired"
        )

    if code_obj.max_uses and code_obj.current_uses >= code_obj.max_uses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Code usage limit reached"
        )

    code_obj.current_uses += 1
    code_obj.used_at = datetime.utcnow()
    db.add(code_obj)

    use = AccessCodeUse(access_code_id=code_obj.id, user_id=user.id)
    db.add(use)

    if code_obj.course_id:
        expires = None
        if code_obj.access_duration:
            expires = datetime.utcnow() + timedelta(days=code_obj.access_duration)

        access = UserCourseAccess(
            user_id=user.id,
            course_id=code_obj.course_id,
            access_type=code_obj.access_type,
            granted_by=code_obj.created_by,
            expires_at=expires,
        )
        db.add(access)

    db.commit()

    return {"message": "Code validated successfully", "course_id": code_obj.course_id}


@codes_router.delete("/{code_id}")
def deactivate_code(
    code_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    code = db.get(AccessCode, code_id)
    if not code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Code not found"
        )

    if code.created_by != user.id and user.role not in [
        UserRole.ADMIN,
        UserRole.SUPER_ADMIN,
    ]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Cannot deactivate this code"
        )

    code.is_active = False
    db.add(code)
    db.commit()

    return {"message": "Code deactivated successfully"}


@reports_router.get("", response_model=list[ReportResponse])
def list_reports(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    reports = db.exec(select(Report)).all()

    return [
        ReportResponse(
            id=r.id,
            user_id=r.user_id,
            target_type=r.target_type,
            target_id=r.target_id,
            reason=r.reason,
            description=r.description,
            status=r.status,
            resolved_by=r.resolved_by,
            resolved_at=r.resolved_at,
            created_at=r.created_at,
        )
        for r in reports
    ]


@reports_router.post("", response_model=ReportResponse)
def create_report(
    request: ReportCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    report = Report(
        user_id=user.id,
        target_type=request.target_type,
        target_id=request.target_id,
        reason=request.reason,
        description=request.description,
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    return ReportResponse(
        id=report.id,
        user_id=report.user_id,
        target_type=report.target_type,
        target_id=report.target_id,
        reason=report.reason,
        description=report.description,
        status=report.status,
        resolved_by=report.resolved_by,
        resolved_at=report.resolved_at,
        created_at=report.created_at,
    )


@reports_router.put("/{report_id}", response_model=ReportResponse)
def update_report(
    report_id: str,
    request: ReportUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Report not found"
        )

    if request.status:
        report.status = request.status
        report.resolved_by = user.id
        report.resolved_at = datetime.utcnow()

    db.add(report)
    db.commit()
    db.refresh(report)

    return ReportResponse(
        id=report.id,
        user_id=report.user_id,
        target_type=report.target_type,
        target_id=report.target_id,
        reason=report.reason,
        description=report.description,
        status=report.status,
        resolved_by=report.resolved_by,
        resolved_at=report.resolved_at,
        created_at=report.created_at,
    )


@reports_router.get("/{report_id}", response_model=ReportResponse)
def get_report(
    report_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Report not found"
        )

    return ReportResponse(
        id=report.id,
        user_id=report.user_id,
        target_type=report.target_type,
        target_id=report.target_id,
        reason=report.reason,
        description=report.description,
        status=report.status,
        resolved_by=report.resolved_by,
        resolved_at=report.resolved_at,
        created_at=report.created_at,
    )


@stats_router.get("/overview", response_model=StatsOverview)
def get_overview_stats(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN, UserRole.INSTRUCTOR]:
        # Return student-specific stats
        total_courses = (
            db.exec(
                select(func.count(UserCourseAccess.id)).where(
                    UserCourseAccess.user_id == user.id
                )
            ).first()
            or 0
        )
        total_lessons = (
            db.exec(
                select(func.count(WatchHistory.id))
                .where(WatchHistory.user_id == user.id)
                .where(WatchHistory.completion_percentage >= 90)
            ).first()
            or 0
        )
        total_quizzes = (
            db.exec(
                select(func.count(QuizAttempt.id)).where(QuizAttempt.user_id == user.id)
            ).first()
            or 0
        )
        total_watch = (
            db.exec(
                select(func.sum(WatchHistory.watch_time)).where(
                    WatchHistory.user_id == user.id
                )
            ).first()
            or 0
        )

        return StatsOverview(
            total_users=0,
            total_courses=total_courses,
            total_lessons=total_lessons,
            total_quizzes=total_quizzes,
            total_watch_time=float(total_watch or 0),
        )

    total_users = db.exec(select(func.count(User.id))).first() or 0
    total_courses = db.exec(select(func.count(Course.id))).first() or 0
    total_lessons = db.exec(select(func.count(Lesson.id))).first() or 0

    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    new_users_this_month = (
        db.exec(
            select(func.count(User.id)).where(User.created_at >= thirty_days_ago)
        ).first()
        or 0
    )

    active_users_this_month = (
        db.exec(
            select(func.count(UserActivity.user_id.distinct())).where(
                UserActivity.created_at >= thirty_days_ago
            )
        ).first()
        or 0
    )

    total_watch = db.exec(select(func.sum(WatchHistory.watch_time))).first() or 0

    # Weekly unique users for last 4 weeks
    weekly_unique = []
    for i in range(4):
        start = datetime.utcnow() - timedelta(days=(i + 1) * 7)
        end = datetime.utcnow() - timedelta(days=i * 7)
        count = (
            db.exec(
                select(func.count(UserActivity.user_id.distinct())).where(
                    (UserActivity.created_at >= start) & (UserActivity.created_at < end)
                )
            ).first()
            or 0
        )
        weekly_unique.append({"week": f"{i + 1} weeks ago", "count": count})

    # Monthly watch stats for last 6 months
    monthly_watch = []
    for i in range(6):
        start = datetime.utcnow() - timedelta(days=(i + 1) * 30)
        end = datetime.utcnow() - timedelta(days=i * 30)
        watch_time = (
            db.exec(
                select(func.sum(WatchHistory.watch_time)).where(
                    (WatchHistory.created_at >= start) & (WatchHistory.created_at < end)
                )
            ).first()
            or 0
        )
        monthly_watch.append(
            {"month": f"{i + 1} months ago", "watch_time": float(watch_time or 0)}
        )

    return StatsOverview(
        total_users=total_users,
        total_courses=total_courses,
        total_lessons=total_lessons,
        new_users_this_month=new_users_this_month,
        active_users_this_month=active_users_this_month,
        total_watch_time=float(total_watch or 0),
        weekly_unique_users=weekly_unique,
        monthly_watch_stats=monthly_watch,
    )


@stats_router.get("/users", response_model=dict)
def get_user_stats(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    total_users = db.exec(select(func.count(User.id))).first() or 0

    # Near ending subs (less than 7 days left)
    seven_days_from_now = datetime.utcnow() + timedelta(days=7)
    near_ending = (
        db.exec(
            select(func.count(UserCourseAccess.id)).where(
                (UserCourseAccess.expires_at > datetime.utcnow())
                & (UserCourseAccess.expires_at < seven_days_from_now)
            )
        ).first()
        or 0
    )

    return {"total_users": total_users, "near_ending_subscriptions": near_ending}


@stats_router.get("/courses/{course_id}", response_model=CourseStats)
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

    # Near ending subs for this course
    seven_days_from_now = datetime.utcnow() + timedelta(days=7)
    near_ending = len(
        [
            a
            for a in accesses
            if a.expires_at and datetime.utcnow() < a.expires_at < seven_days_from_now
        ]
    )

    lessons = db.exec(select(Lesson).where(Lesson.course_id == course_id)).all()
    lesson_stats = []
    total_completion = 0
    for lesson in lessons:
        watches = db.exec(
            select(WatchHistory).where(WatchHistory.lesson_id == lesson.id)
        ).all()
        avg_comp = (
            sum(w.completion_percentage for w in watches) / len(watches)
            if watches
            else 0
        )
        lesson_stats.append(
            {
                "lesson_id": lesson.id,
                "title": lesson.title,
                "views": len(watches),
                "avg_completion": avg_comp,
            }
        )
        total_completion += avg_comp

    return CourseStats(
        course_id=course_id,
        total_views=len(accesses),
        unique_users=unique_users,
        average_completion=total_completion / len(lessons) if lessons else 0,
        lesson_stats=lesson_stats,
        near_ending_subscriptions=near_ending,
    )


@stats_router.get("/instructors", response_model=list[InstructorStats])
def get_instructor_stats(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    if user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Super admin only"
        )

    instructors = db.exec(select(User).where(User.role == UserRole.INSTRUCTOR)).all()

    result = []
    for inst in instructors:
        courses = db.exec(select(Course).where(Course.instructor_id == inst.id)).all()
        course_ids = [c.id for c in courses]

        unique_users_count = (
            db.exec(
                select(func.count(UserCourseAccess.user_id.distinct())).where(
                    UserCourseAccess.course_id.in_(course_ids)
                )
            ).first()
            or 0
            if course_ids
            else 0
        )

        watch_time = (
            db.exec(
                select(func.sum(WatchHistory.watch_time))
                .join(Lesson)
                .where(Lesson.course_id.in_(course_ids))
            ).first()
            or 0
            if course_ids
            else 0
        )

        codes_gen = (
            db.exec(
                select(func.count(AccessCode.id)).where(
                    AccessCode.created_by == inst.id
                )
            ).first()
            or 0
        )

        codes_used = (
            db.exec(
                select(func.sum(AccessCode.current_uses)).where(
                    AccessCode.created_by == inst.id
                )
            ).first()
            or 0
        )

        result.append(
            InstructorStats(
                instructor_id=inst.id,
                email=inst.email,
                total_courses=len(courses),
                total_unique_users=unique_users_count,
                total_watch_time=float(watch_time or 0),
                codes_generated=codes_gen,
                codes_used=int(codes_used or 0),
            )
        )

    return result


@stats_router.post("/watch", response_model=WatchHistoryResponse)
def record_watch(
    request: WatchHistoryCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    existing = db.exec(
        select(WatchHistory)
        .where(WatchHistory.user_id == user.id)
        .where(WatchHistory.lesson_id == request.lesson_id)
    ).first()

    if existing:
        existing.watch_time = request.watch_time
        existing.completion_percentage = request.completion_percentage
        existing.last_position = request.last_position
        existing.updated_at = datetime.utcnow()
        if request.device_info:
            existing.device_info = request.device_info
        db.add(existing)
        db.commit()
        db.refresh(existing)
        history = existing
    else:
        history = WatchHistory(
            user_id=user.id,
            lesson_id=request.lesson_id,
            watch_time=request.watch_time,
            completion_percentage=request.completion_percentage,
            last_position=request.last_position,
            device_info=request.device_info,
        )
        db.add(history)
        db.commit()
        db.refresh(history)

    return WatchHistoryResponse(
        id=history.id,
        user_id=history.user_id,
        lesson_id=history.lesson_id,
        watch_time=history.watch_time,
        completion_percentage=history.completion_percentage,
        last_position=history.last_position,
        updated_at=history.updated_at,
    )


@messages_router.get("", response_model=list[MessageResponse])
def get_messages(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    messages = db.exec(
        select(Message)
        .where((Message.sender_id == user.id) | (Message.recipient_id == user.id))
        .order_by(Message.created_at.desc())
    ).all()

    return [
        MessageResponse(
            id=m.id,
            sender_id=m.sender_id,
            recipient_id=m.recipient_id,
            content=m.content,
            is_read=m.is_read,
            created_at=m.created_at,
        )
        for m in messages
    ]


@messages_router.get("/{message_id}", response_model=MessageResponse)
def get_message(
    message_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Message not found"
        )

    if message.sender_id != user.id and message.recipient_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not your message"
        )

    return MessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        recipient_id=message.recipient_id,
        content=message.content,
        is_read=message.is_read,
        created_at=message.created_at,
    )


@messages_router.post("", response_model=MessageResponse)
def send_message(
    request: MessageCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    message = Message(
        sender_id=user.id,
        recipient_id=request.recipient_id,
        content=request.content,
    )
    db.add(message)
    db.commit()
    db.refresh(message)

    return MessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        recipient_id=message.recipient_id,
        content=message.content,
        is_read=message.is_read,
        created_at=message.created_at,
    )


@messages_router.put("/{message_id}/read", response_model=MessageResponse)
def mark_read(
    message_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Message not found"
        )

    if message.recipient_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Cannot mark as read"
        )

    message.is_read = True
    db.add(message)
    db.commit()
    db.refresh(message)

    return MessageResponse(
        id=message.id,
        sender_id=message.sender_id,
        recipient_id=message.recipient_id,
        content=message.content,
        is_read=message.is_read,
        created_at=message.created_at,
    )


@stats_router.get("/continue-watching", response_model=list[dict])
def get_continue_watching(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Get last 5 lessons with watch history > 0 and < 90%
    histories = db.exec(
        select(WatchHistory)
        .where(WatchHistory.user_id == user.id)
        .where(WatchHistory.completion_percentage < 90)
        .order_by(WatchHistory.updated_at.desc())
        .limit(5)
    ).all()

    result = []
    for h in histories:
        lesson = db.get(Lesson, h.lesson_id)
        if lesson:
            course = db.get(Course, lesson.course_id)
            result.append(
                {
                    "lesson_id": lesson.id,
                    "lesson_title": lesson.title,
                    "course_id": course.id if course else None,
                    "course_title": course.title if course else "Unknown",
                    "last_position": h.last_position,
                    "completion_percentage": h.completion_percentage,
                    "updated_at": h.updated_at,
                }
            )
    return result


@videos_router.get("/{lesson_id}/manifest")
async def get_video_manifest_proxy(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson or not lesson.video_id:
        raise HTTPException(status_code=404, detail="Lesson or video not found")

    from app.api.v1.lessons import check_lesson_access
    from app.core.config import settings
    import httpx

    if not check_lesson_access(db, user, lesson):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied (Student {user.id} has no access to lesson {lesson.id})",
        )

    async with httpx.AsyncClient() as client:
        url = f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{lesson.video_id}/manifest"
        r = await client.get(url)
    if r.status_code != 200:
        raise HTTPException(status_code=r.status_code, detail="Video server error")

    manifest = r.json()

    server_mode_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "server_mode")
    ).first()
    policy_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "download_policy")
    ).first()
    action_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "mode_mismatch_action")
    ).first()

    video_policy = db.exec(
        select(VideoModePolicy).where(VideoModePolicy.video_id == lesson.video_id)
    ).first()

    manifest["server_mode"] = server_mode_cfg.value if server_mode_cfg else "hybrid"
    manifest["download_policy"] = policy_cfg.value if policy_cfg else "allow"
    manifest["mode_mismatch_action"] = action_cfg.value if action_cfg else "warn"
    manifest["video_policy"] = (
        {
            "current_action": video_policy.current_action if video_policy else None,
            "banned": video_policy.banned if video_policy else False,
            "mode_when_downloaded": video_policy.mode_when_downloaded
            if video_policy
            else None,
        }
        if video_policy
        else None
    )

    return manifest


@videos_router.get("/{lesson_id}/playlist/{resolution}")
async def proxy_video_playlist(
    lesson_id: str,
    resolution: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson or not lesson.video_id:
        raise HTTPException(status_code=404, detail="Lesson or video not found")

    # Check access (re-use logic or call helper)
    from app.api.v1.lessons import check_lesson_access

    if not check_lesson_access(db, user, lesson):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied (Student {user.id} has no access to lesson {lesson.id})",
        )

    from app.core.config import settings
    import httpx

    # Fetch from video server with user info for watermarking
    async with httpx.AsyncClient() as client:
        url = f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{lesson.video_id}/playlist/{resolution}"
        params = {"user_email": user.email, "user_phone": user.phone}
        r = await client.get(url, params=params)

        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Video server error")

        from fastapi.responses import PlainTextResponse
        import re

        content = r.text
        correct_base = settings.MAIN_SERVER_URL.rstrip("/") + "/api/v1/videos/proxy"
        content = re.sub(
            r"https?://(?:localhost|127\.0\.0\.1):8001(?:/api/v1)?/",
            correct_base + "/",
            content,
        )

        return PlainTextResponse(
            content=content, media_type="application/vnd.apple.mpegurl"
        )


@videos_router.get("/proxy/{full_path:path}")
async def proxy_video_server_content(
    full_path: str,
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    from app.core.config import settings
    import httpx
    from fastapi.responses import Response, StreamingResponse

    async with httpx.AsyncClient() as client:
        url = f"{settings.VIDEO_SERVER_INTERNAL_URL}/{full_path}"
        params = dict(request.query_params)

        r = await client.get(url, params=params, timeout=120)
        media_type = r.headers.get("content-type", "video/mp2t")
        return Response(content=r.content, media_type=media_type, status_code=r.status_code)


@videos_router.get("/{lesson_id}/raw")
async def proxy_raw_video_student(
    lesson_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    lesson = db.get(Lesson, lesson_id)
    if not lesson or not lesson.video_id:
        raise HTTPException(status_code=404, detail="Lesson or video not found")

    from app.api.v1.lessons import check_lesson_access

    if not check_lesson_access(db, user, lesson):
        raise HTTPException(
            status_code=403,
            detail=f"Access denied (Student {user.id} has no access to lesson {lesson.id})",
        )

    from app.core.config import settings
    import httpx
    from fastapi.responses import StreamingResponse

    async def stream_video():
        async with httpx.AsyncClient() as client:
            headers = {
                "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
            }
            async with client.stream(
                "GET",
                f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{lesson.video_id}/raw",
                headers=headers,
                timeout=None,
            ) as r:
                if r.status_code != 200:
                    yield b"Video not found or access denied"
                    return
                async for chunk in r.aiter_bytes():
                    yield chunk

    return StreamingResponse(stream_video(), media_type="video/mp4")


@certificates_router.get("", response_model=list[CertificateResponse])
def get_my_certificates(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    certs = db.exec(
        select(Certificate)
        .where(Certificate.user_id == user.id)
        .order_by(Certificate.issued_at.desc())
    ).all()
    return [
        CertificateResponse(
            id=c.id,
            user_id=c.user_id,
            course_id=c.course_id,
            title=c.title,
            description=c.description,
            issued_at=c.issued_at,
            expiry_date=c.expiry_date,
            certificate_hash=c.certificate_hash,
            metadata_json=c.metadata_json,
        )
        for c in certs
    ]


@certificates_router.get("/course/{course_id}", response_model=CertificateResponse)
def get_course_certificate(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cert = db.exec(
        select(Certificate).where(
            (Certificate.user_id == user.id) & (Certificate.course_id == course_id)
        )
    ).first()
    if not cert:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Certificate not found"
        )
    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        course_id=cert.course_id,
        title=cert.title,
        description=cert.description,
        issued_at=cert.issued_at,
        expiry_date=cert.expiry_date,
        certificate_hash=cert.certificate_hash,
        metadata_json=cert.metadata_json,
    )


@certificates_router.post("/claim/{course_id}", response_model=CertificateResponse)
def claim_certificate(
    course_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    course = db.get(Course, course_id)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Course not found"
        )

    existing = db.exec(
        select(Certificate).where(
            (Certificate.user_id == user.id) & (Certificate.course_id == course_id)
        )
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Certificate already claimed",
        )

    # Check all quizzes in course lessons are passed
    lessons = db.exec(select(Lesson).where(Lesson.course_id == course_id)).all()
    for lesson in lessons:
        if lesson.quiz_id:
            attempt = db.exec(
                select(QuizAttempt)
                .where(
                    (QuizAttempt.quiz_id == lesson.quiz_id)
                    & (QuizAttempt.user_id == user.id)
                )
                .order_by(QuizAttempt.completed_at.desc())
            ).first()
            if not attempt or not attempt.passed:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Complete all quizzes first: {lesson.title}",
                )

    raw = f"{user.id}:{course_id}:{datetime.utcnow().isoformat()}"
    cert_hash = hashlib.sha256(raw.encode()).hexdigest()[:16]

    cert = Certificate(
        user_id=user.id,
        course_id=course_id,
        title=f"Completion - {course.title}",
        description=f"Successfully completed {course.title}",
        certificate_hash=cert_hash,
    )
    db.add(cert)
    db.commit()
    db.refresh(cert)

    return CertificateResponse(
        id=cert.id,
        user_id=cert.user_id,
        course_id=cert.course_id,
        title=cert.title,
        description=cert.description,
        issued_at=cert.issued_at,
        expiry_date=cert.expiry_date,
        certificate_hash=cert.certificate_hash,
        metadata_json=cert.metadata_json,
    )


@certificates_router.get("/all", response_model=list[CertificateResponse])
def list_all_certificates(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    if user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        certs = db.exec(
            select(Certificate)
            .join(Course)
            .where(Course.instructor_id == user.id)
            .order_by(Certificate.issued_at.desc())
        ).all()
    else:
        certs = db.exec(
            select(Certificate).order_by(Certificate.issued_at.desc())
        ).all()
    return [
        CertificateResponse(
            id=c.id,
            user_id=c.user_id,
            course_id=c.course_id,
            title=c.title,
            description=c.description,
            issued_at=c.issued_at,
            expiry_date=c.expiry_date,
            certificate_hash=c.certificate_hash,
            metadata_json=c.metadata_json,
        )
        for c in certs
    ]


from pydantic import BaseModel


class UploadInitRequest(BaseModel):
    title: str
    description: Optional[str] = None
    filename: str
    total_size: int
    total_chunks: int
    watermark_enabled: bool = True
    folder: str = "General"
    streaming_mode: str = "hls"


# Video management endpoints
@videos_router.post("/upload/init", tags=["videos"])
async def upload_init(
    request: UploadInitRequest,
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    payload = request.dict()
    payload["created_by"] = user.id

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.post(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/upload/init",
            json=payload,
            headers=headers,
            timeout=10.0,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail=r.text)
        return r.json()


@videos_router.post("/upload/{upload_id}/chunk", tags=["videos"])
async def upload_chunk(
    upload_id: str,
    chunk_index: int = Query(...),
    file: UploadFile = File(...),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    async with httpx.AsyncClient() as client:
        files = {"file": (file.filename, await file.read(), file.content_type)}
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.post(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/upload/{upload_id}/chunk",
            params={"chunk_index": chunk_index},
            files=files,
            headers=headers,
            timeout=600.0,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail=r.text)
        return r.json()


@videos_router.get("/upload/{upload_id}/status", tags=["videos"])
async def upload_status(
    upload_id: str,
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.get(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/upload/{upload_id}/status",
            headers=headers,
            timeout=10.0,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail=r.text)
        return r.json()


@videos_router.post("/upload/{upload_id}/complete", tags=["videos"])
async def upload_complete(
    upload_id: str,
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.post(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/upload/{upload_id}/complete",
            headers=headers,
            timeout=60.0,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail=r.text)
        return r.json()


@videos_router.get("/manage", tags=["videos"])
async def list_manage_videos(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
    skip: int = 0,
    limit: int = 50,
):
    from app.core.config import settings
    import httpx

    user_id_filter = user.id if user.role == UserRole.INSTRUCTOR else None

    lesson_video_ids = []
    if user_id_filter:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson_video_ids = [
            l.video_id
            for l in db.exec(
                select(Lesson).where(Lesson.course_id.in_([c.id for c in courses]))
            ).all()
            if l.video_id
        ]

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        params = {"skip": skip, "limit": limit}
        # If we filter by created_by at the API level, we miss the ones assigned to lessons
        # So we fetch all if there's a filter, and filter locally instead, matching the old behavior
        # plus the new "pool" behavior.
        # Actually, let's fetch all (up to 500) and filter locally.

        r = await client.get(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos",
            params={"skip": 0, "limit": 500},
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Video server error: {r.text}")
        videos = r.json()

    if user_id_filter:
        # Include videos created by the instructor OR assigned to their lessons
        videos = [
            v
            for v in videos
            if v.get("created_by") == user_id_filter or v.get("id") in lesson_video_ids
        ]

    return videos[skip : skip + limit]


@videos_router.get("/manage/{video_id}", tags=["videos"])
async def get_manage_video(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.get(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Video not found")
        return r.json()


@videos_router.put("/manage/{video_id}", tags=["videos"])
async def update_manage_video(
    video_id: str,
    request: dict,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.put(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
            json=request,
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Update failed")
        return r.json()


@videos_router.delete("/manage/{video_id}", tags=["videos"])
async def delete_manage_video(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.delete(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Delete failed")
        return {"detail": "Video deleted"}


@videos_router.get("/jobs", tags=["videos"])
async def list_manage_jobs(
    video_id: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    user_id = user.id if user.role == UserRole.INSTRUCTOR else None

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        params = {}
        if video_id:
            params["video_id"] = video_id
        if user_id:
            params["user_id"] = user_id

        r = await client.get(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/jobs",
            params=params,
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=500, detail="Video server error")
        return r.json()


@videos_router.post("/jobs/{job_id}/kill", tags=["videos"])
async def kill_manage_job(
    job_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    # For instructors, verify they own the video this job belongs to
    if user.role == UserRole.INSTRUCTOR:
        async with httpx.AsyncClient() as client:
            headers = {
                "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
            }
            # First get the job to find the video_id
            jr = await client.get(
                f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/jobs",
                headers=headers,
            )
            if jr.status_code == 200:
                jobs = jr.json()
                job = next((j for j in jobs if j["id"] == job_id), None)
                if not job:
                    raise HTTPException(status_code=404, detail="Job not found")

                video_id = job["video_id"]
                # Now check video ownership
                vr = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if vr.status_code == 200:
                    video_data = vr.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        # Also check if it's assigned to one of their lessons
                        courses = db.exec(
                            select(Course).where(Course.instructor_id == user.id)
                        ).all()
                        course_ids = [c.id for c in courses]
                        lesson = None
                        if course_ids:
                            lesson = db.exec(
                                select(Lesson).where(
                                    (Lesson.video_id == video_id)
                                    & (Lesson.course_id.in_(course_ids))
                                )
                            ).first()
                        if not lesson:
                            raise HTTPException(
                                status_code=403,
                                detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                            )
                else:
                    raise HTTPException(
                        status_code=vr.status_code,
                        detail="Video not found on video server",
                    )
            else:
                raise HTTPException(
                    status_code=500, detail="Failed to fetch jobs from video server"
                )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.post(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/jobs/{job_id}/kill",
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Kill failed")
        return r.json()


@videos_router.post("/manage/{video_id}/transcode", tags=["videos"])
async def transcode_manage_video(
    video_id: str,
    priority: int = 0,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        r = await client.post(
            f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}/transcode",
            params={"priority": priority},
            headers=headers,
        )
        if r.status_code != 200:
            raise HTTPException(status_code=r.status_code, detail="Transcode failed")
        return r.json()


@videos_router.get("/manage/{video_id}/manifest", tags=["videos"])
async def get_manage_video_manifest(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    # Basic ownership check for instructors
    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            # Also check if they created it but it's not assigned yet
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code, detail="Video not found"
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        url = f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}/manifest"
        r = await client.get(url, headers=headers)

    if r.status_code != 200:
        raise HTTPException(status_code=r.status_code, detail="Video server error")

    return r.json()


@videos_router.get("/manage/{video_id}/raw", tags=["videos"])
async def proxy_raw_video(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx
    from fastapi.responses import StreamingResponse

    # Ownership check
    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async def stream_video():
        async with httpx.AsyncClient() as client:
            headers = {
                "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
            }
            async with client.stream(
                "GET",
                f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}/raw",
                headers=headers,
                timeout=None,
            ) as r:
                if r.status_code != 200:
                    yield b"Video not found or access denied"
                    return
                async for chunk in r.aiter_bytes():
                    yield chunk

    return StreamingResponse(stream_video(), media_type="video/mp4")


@videos_router.get("/manage/{video_id}/playlist/{resolution}", tags=["videos"])
async def get_manage_video_playlist(
    video_id: str,
    resolution: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    from app.core.config import settings
    import httpx

    # Basic ownership check for instructors
    if user.role == UserRole.INSTRUCTOR:
        courses = db.exec(select(Course).where(Course.instructor_id == user.id)).all()
        lesson = db.exec(
            select(Lesson).where(
                (Lesson.video_id == video_id)
                & (Lesson.course_id.in_([c.id for c in courses]))
            )
        ).first()
        if not lesson:
            async with httpx.AsyncClient() as client:
                headers = {
                    "Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"
                }
                r = await client.get(
                    f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}",
                    headers=headers,
                )
                if r.status_code == 200:
                    video_data = r.json()
                    owner_id = video_data.get("created_by")
                    if str(owner_id) != str(user.id):
                        raise HTTPException(
                            status_code=403,
                            detail=f"Access denied (Video owner: {owner_id}, You: {user.id})",
                        )
                else:
                    raise HTTPException(
                        status_code=r.status_code,
                        detail="Video not found on video server",
                    )

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {settings.VIDEO_SERVER_INTERNAL_TOKEN}"}
        url = f"{settings.VIDEO_SERVER_INTERNAL_URL}/internal/videos/{video_id}/playlist/{resolution}"
        # For admin preview, use admin's own info for watermarking
        params = {"user_email": user.email, "user_phone": user.phone}
        r = await client.get(url, params=params, headers=headers)

    if r.status_code != 200:
        raise HTTPException(status_code=r.status_code, detail="Video server error")

    from fastapi.responses import PlainTextResponse
    import re

    content = r.text
    correct_base = settings.MAIN_SERVER_URL.rstrip("/") + "/api/v1/videos/proxy"
    content = re.sub(
        r"https?://(?:localhost|127\.0\.0\.1):8001(?:/api/v1)?/",
        correct_base + "/",
        content,
    )

    return PlainTextResponse(
        content=content, media_type="application/vnd.apple.mpegurl"
    )


# ── Server Config Routes ───────────────────────────────────────────────


@misc_router.get("/config", response_model=dict)
def get_all_server_config(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    configs = db.exec(select(ServerConfig)).all()
    return {c.key: c.value for c in configs}


@misc_router.get("/config/{key}", response_model=ServerConfigResponse)
def get_server_config(
    key: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    cfg = db.exec(select(ServerConfig).where(ServerConfig.key == key)).first()
    if not cfg:
        raise HTTPException(status_code=404, detail="Config key not found")
    return ServerConfigResponse(
        id=cfg.id,
        key=cfg.key,
        value=cfg.value,
        updated_at=cfg.updated_at,
        updated_by=cfg.updated_by,
    )


@misc_router.put("/config/{key}", response_model=ServerConfigResponse)
def set_server_config(
    key: str,
    request: ServerConfigCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    cfg = db.exec(select(ServerConfig).where(ServerConfig.key == key)).first()
    if not cfg:
        cfg = ServerConfig(
            key=key,
            value=request.value,
            updated_by=user.id,
        )
        db.add(cfg)
    else:
        cfg.value = request.value
        cfg.updated_at = datetime.utcnow()
        cfg.updated_by = user.id
        db.add(cfg)
    db.commit()
    db.refresh(cfg)
    return ServerConfigResponse(
        id=cfg.id,
        key=cfg.key,
        value=cfg.value,
        updated_at=cfg.updated_at,
        updated_by=cfg.updated_by,
    )


@misc_router.delete("/config/{key}")
def delete_server_config(
    key: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    cfg = db.exec(select(ServerConfig).where(ServerConfig.key == key)).first()
    if not cfg:
        raise HTTPException(status_code=404, detail="Config key not found")
    db.delete(cfg)
    db.commit()
    return {"message": f"Config '{key}' deleted"}


@misc_router.put("/server-mode", response_model=dict)
def set_server_mode(
    mode: str,
    download_policy: Optional[str] = None,
    mode_mismatch_action: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    valid_modes = {"cloud_only", "local_only", "hybrid"}
    if mode not in valid_modes:
        raise HTTPException(
            status_code=400, detail=f"Invalid mode. Must be one of: {valid_modes}"
        )

    cfg = db.exec(select(ServerConfig).where(ServerConfig.key == "server_mode")).first()
    if not cfg:
        cfg = ServerConfig(key="server_mode", value=mode, updated_by=user.id)
        db.add(cfg)
    else:
        cfg.value = mode
        cfg.updated_at = datetime.utcnow()
        cfg.updated_by = user.id
        db.add(cfg)

    if download_policy:
        valid_policies = {"allow", "auto_delete", "ban"}
        if download_policy not in valid_policies:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid policy. Must be one of: {valid_policies}",
            )
        pol = db.exec(
            select(ServerConfig).where(ServerConfig.key == "download_policy")
        ).first()
        if not pol:
            pol = ServerConfig(
                key="download_policy", value=download_policy, updated_by=user.id
            )
            db.add(pol)
        else:
            pol.value = download_policy
            pol.updated_at = datetime.utcnow()
            pol.updated_by = user.id
            db.add(pol)

    if mode_mismatch_action:
        valid_actions = {"warn", "block", "auto_delete"}
        if mode_mismatch_action not in valid_actions:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid action. Must be one of: {valid_actions}",
            )
        act = db.exec(
            select(ServerConfig).where(ServerConfig.key == "mode_mismatch_action")
        ).first()
        if not act:
            act = ServerConfig(
                key="mode_mismatch_action",
                value=mode_mismatch_action,
                updated_by=user.id,
            )
            db.add(act)
        else:
            act.value = mode_mismatch_action
            act.updated_at = datetime.utcnow()
            act.updated_by = user.id
            db.add(act)

    db.commit()

    return {
        "server_mode": mode,
        "download_policy": download_policy or "allow",
        "mode_mismatch_action": mode_mismatch_action or "warn",
    }


@misc_router.get("/server-mode", response_model=dict)
def get_server_mode(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    mode_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "server_mode")
    ).first()
    policy_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "download_policy")
    ).first()
    action_cfg = db.exec(
        select(ServerConfig).where(ServerConfig.key == "mode_mismatch_action")
    ).first()

    return {
        "server_mode": mode_cfg.value if mode_cfg else "hybrid",
        "download_policy": policy_cfg.value if policy_cfg else "allow",
        "mode_mismatch_action": action_cfg.value if action_cfg else "warn",
    }


@misc_router.get("/video-mode-policies", response_model=list[VideoModePolicyResponse])
def list_video_mode_policies(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    return db.exec(
        select(VideoModePolicy).order_by(VideoModePolicy.created_at.desc())
    ).all()


@misc_router.post("/video-mode-policies", response_model=VideoModePolicyResponse)
def create_video_mode_policy(
    request: VideoModePolicyCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    existing = db.exec(
        select(VideoModePolicy).where(VideoModePolicy.video_id == request.video_id)
    ).first()
    if existing:
        existing.current_action = request.current_action
        existing.mode_when_downloaded = request.mode_when_downloaded
        existing.updated_at = datetime.utcnow()
        db.add(existing)
        db.commit()
        db.refresh(existing)
        return existing

    policy = VideoModePolicy(
        video_id=request.video_id,
        lesson_id=request.lesson_id,
        mode_when_downloaded=request.mode_when_downloaded,
        current_action=request.current_action,
    )
    db.add(policy)
    db.commit()
    db.refresh(policy)
    return policy


@misc_router.get(
    "/video-mode-policies/{video_id}", response_model=VideoModePolicyResponse
)
def get_video_mode_policy(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    policy = db.exec(
        select(VideoModePolicy).where(VideoModePolicy.video_id == video_id)
    ).first()
    if not policy:
        raise HTTPException(status_code=404, detail="No policy found for this video")
    return policy


@misc_router.put(
    "/video-mode-policies/{video_id}", response_model=VideoModePolicyResponse
)
def update_video_mode_policy(
    video_id: str,
    request: VideoModePolicyUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    policy = db.exec(
        select(VideoModePolicy).where(VideoModePolicy.video_id == video_id)
    ).first()
    if not policy:
        raise HTTPException(status_code=404, detail="No policy found for this video")

    if request.current_action is not None:
        policy.current_action = request.current_action
    if request.notes is not None:
        policy.notes = request.notes
    policy.updated_at = datetime.utcnow()
    db.add(policy)
    db.commit()
    db.refresh(policy)
    return policy


@misc_router.delete("/video-mode-policies/{video_id}")
def delete_video_mode_policy(
    video_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    policy = db.exec(
        select(VideoModePolicy).where(VideoModePolicy.video_id == video_id)
    ).first()
    if not policy:
        raise HTTPException(status_code=404, detail="No policy found for this video")
    db.delete(policy)
    db.commit()
    return {"message": "Policy deleted"}


@misc_router.get("/env-config", response_model=list[dict])
def list_env_configs(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    if user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Super admin only")

    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

    modules = {
        "main-server": os.path.join(base, "main-server", ".env"),
        "video-server": os.path.join(base, "video-server", ".env"),
    }

    result = []
    for name, path in modules.items():
        content = ""
        if os.path.exists(path):
            with open(path) as f:
                content = f.read()
        result.append({"module": name, "path": path, "content": content})
    return result


@misc_router.put("/env-config/{module_name}")
def update_env_config(
    module_name: str,
    body: dict,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    if user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(status_code=403, detail="Super admin only")

    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))))

    paths = {
        "main-server": os.path.join(base, "main-server", ".env"),
        "video-server": os.path.join(base, "video-server", ".env"),
    }

    path = paths.get(module_name)
    if not path:
        raise HTTPException(status_code=404, detail=f"Unknown module: {module_name}")

    content = body.get("content", "")
    with open(path, "w") as f:
        f.write(content)
    return {"message": f"{module_name} .env updated"}
