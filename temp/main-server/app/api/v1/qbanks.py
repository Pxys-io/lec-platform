import json
import random
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func

from app.core.database import get_db
from app.models import (
    User, 
    QBank, 
    Question, 
    QBankEnrollment, 
    QBankSession, 
    UserRole
)
from app.schemas import (
    QBankCreate,
    QBankUpdate,
    QBankResponse,
    QuestionCreate,
    QuestionResponse,
    QBankEnrollmentCreate,
    QBankEnrollmentResponse,
    QBankSessionCreate,
    QBankSessionResponse,
    QBankSessionSubmit,
)
from app.api.v1.users import get_current_user, require_instructor


router = APIRouter(prefix="/qbanks", tags=["qbanks"])


@router.get("", response_model=List[QBankResponse])
def get_qbanks(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    qbanks = db.exec(select(QBank)).all()
    return qbanks


@router.get("/{qbank_id}", response_model=QBankResponse)
def get_qbank(
    qbank_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    qbank = db.get(QBank, qbank_id)
    if not qbank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QBank not found")
    return qbank


@router.post("", response_model=QBankResponse)
def create_qbank(
    request: QBankCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    qbank = QBank(
        title=request.title,
        description=request.description,
        instructor_id=user.id,
        tags=json.dumps(request.tags),
        visibility=request.visibility,
        thumbnail_url=request.thumbnail_url,
        price=request.price,
    )
    db.add(qbank)
    db.commit()
    db.refresh(qbank)
    return qbank


@router.put("/{qbank_id}", response_model=QBankResponse)
def update_qbank(
    qbank_id: str,
    request: QBankUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    qbank = db.get(QBank, qbank_id)
    if not qbank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QBank not found")

    if request.title is not None:
        qbank.title = request.title
    if request.description is not None:
        qbank.description = request.description
    if request.visibility is not None:
        qbank.visibility = request.visibility
    if request.thumbnail_url is not None:
        qbank.thumbnail_url = request.thumbnail_url
    if request.tags is not None:
        qbank.tags = json.dumps(request.tags)
    if request.price is not None:
        qbank.price = request.price

    db.add(qbank)
    db.commit()
    db.refresh(qbank)
    return qbank


@router.delete("/{qbank_id}")
def delete_qbank(
    qbank_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    qbank = db.get(QBank, qbank_id)
    if not qbank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QBank not found")
    db.delete(qbank)
    db.commit()
    return {"message": "QBank deleted successfully"}


@router.get("/enrollments/all", response_model=List[QBankEnrollmentResponse])
def get_all_qbank_enrollments(
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    enrollments = db.exec(select(QBankEnrollment)).all()
    return enrollments


@router.post("/enrollments/{enrollment_id}/approve")
def approve_qbank_enrollment(
    enrollment_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    enrollment = db.get(QBankEnrollment, enrollment_id)
    if not enrollment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enrollment not found")
    
    enrollment.status = "approved"
    db.add(enrollment)
    db.commit()
    return {"message": "Enrollment approved"}


@router.post("/enrollments/{enrollment_id}/reject")
def reject_qbank_enrollment(
    enrollment_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    enrollment = db.get(QBankEnrollment, enrollment_id)
    if not enrollment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enrollment not found")
    
    enrollment.status = "rejected"
    db.add(enrollment)
    db.commit()
    return {"message": "Enrollment rejected"}


@router.post("/{qbank_id}/enroll", response_model=QBankEnrollmentResponse)
def enroll_qbank(
    qbank_id: str,
    request: QBankEnrollmentCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    qbank = db.get(QBank, qbank_id)
    if not qbank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QBank not found")

    existing = db.exec(
        select(QBankEnrollment)
        .where(QBankEnrollment.qbank_id == qbank_id)
        .where(QBankEnrollment.user_id == user.id)
    ).first()

    if existing:
        return existing

    enrollment = QBankEnrollment(
        user_id=user.id,
        qbank_id=qbank_id,
        status="approved" if qbank.price == 0 else "pending",
        form_data_json=json.dumps(request.form_data),
    )
    db.add(enrollment)
    db.commit()
    db.refresh(enrollment)
    return enrollment


@router.get("/{qbank_id}/questions", response_model=List[QuestionResponse])
def get_qbank_questions(
    qbank_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Check enrollment
    enrollment = db.exec(
        select(QBankEnrollment)
        .where(QBankEnrollment.qbank_id == qbank_id)
        .where(QBankEnrollment.user_id == user.id)
        .where(QBankEnrollment.status == "approved")
    ).first()

    if not enrollment and user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN, UserRole.INSTRUCTOR]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not enrolled in this QBank")

    questions = db.exec(select(Question).where(Question.qbank_id == qbank_id)).all()
    
    result = []
    for q in questions:
        options = json.loads(q.options) if q.options else None
        result.append(QuestionResponse(
            id=q.id,
            qbank_id=q.qbank_id,
            type=q.type,
            question=q.question,
            options=options,
            correct_answer=q.correct_answer,
            explanation=q.explanation,
            points=q.points,
            tags=json.loads(q.tags) if q.tags else [],
            order=q.order,
        ))
    return result


@router.post("/{qbank_id}/questions", response_model=QuestionResponse)
def create_qbank_question(
    qbank_id: str,
    request: QuestionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    qbank = db.get(QBank, qbank_id)
    if not qbank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="QBank not found")

    question = Question(
        qbank_id=qbank_id,
        type=request.type,
        question=request.question,
        options=json.dumps(request.options) if request.options else None,
        correct_answer=request.correct_answer,
        explanation=request.explanation,
        points=request.points,
        tags=json.dumps(request.tags),
        order=request.order,
    )
    db.add(question)
    db.commit()
    db.refresh(question)

    options = json.loads(question.options) if question.options else None

    return QuestionResponse(
        id=question.id,
        qbank_id=question.qbank_id,
        type=question.type,
        question=question.question,
        options=options,
        correct_answer=question.correct_answer,
        explanation=question.explanation,
        points=question.points,
        tags=json.loads(question.tags) if question.tags else [],
        order=question.order,
    )


@router.delete("/questions/{question_id}")
def delete_qbank_question(
    question_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    question = db.get(Question, question_id)
    if not question:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")
    db.delete(question)
    db.commit()
    return {"message": "Question deleted successfully"}


@router.post("/{qbank_id}/sessions", response_model=QBankSessionResponse)
def create_qbank_session(
    qbank_id: str,
    request: QBankSessionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Check enrollment
    enrollment = db.exec(
        select(QBankEnrollment)
        .where(QBankEnrollment.qbank_id == qbank_id)
        .where(QBankEnrollment.user_id == user.id)
        .where(QBankEnrollment.status == "approved")
    ).first()

    if not enrollment:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not enrolled in this QBank")

    # Filter questions based on subjects
    query = select(Question).where(Question.qbank_id == qbank_id)
    all_questions = db.exec(query).all()
    
    filtered_questions = []
    if not request.subjects:
        filtered_questions = all_questions
    else:
        for q in all_questions:
            q_tags = json.loads(q.tags) if q.tags else []
            if any(subject in q_tags for subject in request.subjects):
                filtered_questions.append(q)

    if not filtered_questions:
        raise HTTPException(status_code=status.HTTP_400_BAD_USER_INPUT, detail="No questions found for selected subjects")

    selected_questions = random.sample(filtered_questions, min(len(filtered_questions), request.count))
    question_ids = [q.id for q in selected_questions]

    session = QBankSession(
        user_id=user.id,
        qbank_id=qbank_id,
        title=request.title,
        config_json=json.dumps({
            "subjects": request.subjects,
            "mode": request.mode,
            "count": request.count
        }),
        questions_json=json.dumps(question_ids),
        answers_json=json.dumps({}),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    return session


@router.get("/sessions/recent", response_model=List[QBankSessionResponse])
def get_recent_sessions(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    sessions = db.exec(
        select(QBankSession)
        .where(QBankSession.user_id == user.id)
        .order_by(QBankSession.created_at.desc())
        .limit(10)
    ).all()
    return sessions


@router.post("/sessions/{session_id}/submit", response_model=QBankSessionResponse)
def submit_qbank_session(
    session_id: str,
    request: QBankSessionSubmit,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    session = db.get(QBankSession, session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    question_ids = json.loads(session.questions_json)
    questions = db.exec(select(Question).where(Question.id.in_(question_ids))).all()
    
    total_points = sum(q.points for q in questions)
    earned_points = 0

    for question in questions:
        user_answer = request.answers.get(question.id, "").strip().lower()
        correct = question.correct_answer.strip().lower()
        if user_answer == correct:
            earned_points += question.points

    score = (earned_points / total_points * 100) if total_points > 0 else 0

    session.answers_json = json.dumps(request.answers)
    session.score = score
    session.completed_at = datetime.utcnow()
    
    db.add(session)
    db.commit()
    db.refresh(session)

    return session
