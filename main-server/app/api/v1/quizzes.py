import json
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select

from app.core.database import get_db
from app.models import User, Quiz, Question, QuizAttempt, Lesson, UserRole
from app.schemas import (
    QuizCreate,
    QuizUpdate,
    QuizResponse,
    QuestionCreate,
    QuestionResponse,
    QuizSubmit,
    QuizAttemptResponse,
)
from app.api.v1.users import get_current_user, require_instructor


router = APIRouter(prefix="/quizzes", tags=["quizzes"])


@router.get("/{quiz_id}", response_model=QuizResponse)
def get_quiz(
    quiz_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    return QuizResponse(
        id=quiz.id,
        lesson_id=quiz.lesson_id,
        title=quiz.title,
        description=quiz.description,
        passing_score=quiz.passing_score,
        time_limit=quiz.time_limit,
        created_at=quiz.created_at,
    )


@router.post("", response_model=QuizResponse)
def create_quiz(
    request: QuizCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    lesson = db.get(Lesson, request.lesson_id)
    if not lesson:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lesson not found")

    quiz = Quiz(
        lesson_id=request.lesson_id,
        title=request.title,
        description=request.description,
        passing_score=request.passing_score,
        time_limit=request.time_limit,
    )
    db.add(quiz)
    db.commit()
    db.refresh(quiz)

    lesson.quiz_id = quiz.id
    db.add(lesson)
    db.commit()

    return QuizResponse(
        id=quiz.id,
        lesson_id=quiz.lesson_id,
        title=quiz.title,
        description=quiz.description,
        passing_score=quiz.passing_score,
        time_limit=quiz.time_limit,
        created_at=quiz.created_at,
    )


@router.put("/{quiz_id}", response_model=QuizResponse)
def update_quiz(
    quiz_id: str,
    request: QuizUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    if request.title is not None:
        quiz.title = request.title
    if request.description is not None:
        quiz.description = request.description
    if request.passing_score is not None:
        quiz.passing_score = request.passing_score
    if request.time_limit is not None:
        quiz.time_limit = request.time_limit

    db.add(quiz)
    db.commit()
    db.refresh(quiz)

    return QuizResponse(
        id=quiz.id,
        lesson_id=quiz.lesson_id,
        title=quiz.title,
        description=quiz.description,
        passing_score=quiz.passing_score,
        time_limit=quiz.time_limit,
        created_at=quiz.created_at,
    )


@router.delete("/{quiz_id}")
def delete_quiz(
    quiz_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    lesson = db.get(Lesson, quiz.lesson_id)
    if lesson:
        lesson.quiz_id = None
        db.add(lesson)

    db.delete(quiz)
    db.commit()

    return {"message": "Quiz deleted successfully"}


@router.get("/{quiz_id}/questions", response_model=List[QuestionResponse])
def get_quiz_questions(
    quiz_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    questions = db.exec(select(Question).where(Question.quiz_id == quiz_id).order_by(Question.order)).all()

    result = []
    for q in questions:
        options = json.loads(q.options) if q.options else None
        result.append(QuestionResponse(
            id=q.id,
            quiz_id=q.quiz_id,
            type=q.type,
            question=q.question,
            options=options,
            correct_answer=q.correct_answer,
            points=q.points,
            order=q.order,
        ))
    return result


@router.post("/{quiz_id}/questions", response_model=QuestionResponse)
def create_question(
    quiz_id: str,
    request: QuestionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    question = Question(
        quiz_id=quiz_id,
        type=request.type,
        question=request.question,
        options=json.dumps(request.options) if request.options else None,
        correct_answer=request.correct_answer,
        points=request.points,
        order=request.order,
    )
    db.add(question)
    db.commit()
    db.refresh(question)

    options = json.loads(question.options) if question.options else None

    return QuestionResponse(
        id=question.id,
        quiz_id=question.quiz_id,
        type=question.type,
        question=question.question,
        options=options,
        correct_answer=question.correct_answer,
        points=question.points,
        order=question.order,
    )


@router.put("/{quiz_id}/questions/{question_id}", response_model=QuestionResponse)
def update_question(
    quiz_id: str,
    question_id: str,
    request: QuestionCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_instructor),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    question = db.get(Question, question_id)
    if not question or question.quiz_id != quiz_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")

    question.type = request.type
    question.question = request.question
    question.options = json.dumps(request.options) if request.options else None
    question.correct_answer = request.correct_answer
    question.points = request.points
    question.order = request.order

    db.add(question)
    db.commit()
    db.refresh(question)

    options = json.loads(question.options) if question.options else None

    return QuestionResponse(
        id=question.id,
        quiz_id=question.quiz_id,
        type=question.type,
        question=question.question,
        options=options,
        correct_answer=question.correct_answer,
        points=question.points,
        order=question.order,
    )


@router.post("/{quiz_id}/submit", response_model=QuizAttemptResponse)
def submit_quiz(
    quiz_id: str,
    request: QuizSubmit,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    questions = db.exec(select(Question).where(Question.quiz_id == quiz_id)).all()

    total_points = sum(q.points for q in questions)
    earned_points = 0

    for question in questions:
        user_answer = request.answers.get(question.id, "").strip().lower()
        correct = question.correct_answer.strip().lower()
        if user_answer == correct:
            earned_points += question.points

    score = (earned_points / total_points * 100) if total_points > 0 else 0
    passed = score >= quiz.passing_score

    attempt = QuizAttempt(
        user_id=user.id,
        quiz_id=quiz_id,
        answers=json.dumps(request.answers),
        score=score,
        passed=passed,
        completed_at=datetime.utcnow(),
    )
    db.add(attempt)
    db.commit()
    db.refresh(attempt)

    return QuizAttemptResponse(
        id=attempt.id,
        quiz_id=attempt.quiz_id,
        score=attempt.score,
        passed=attempt.passed,
        started_at=attempt.started_at,
        completed_at=attempt.completed_at,
    )


@router.get("/{quiz_id}/results", response_model=QuizAttemptResponse)
def get_quiz_results(
    quiz_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    quiz = db.get(Quiz, quiz_id)
    if not quiz:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")

    attempt = db.exec(
        select(QuizAttempt)
        .where(QuizAttempt.quiz_id == quiz_id)
        .where(QuizAttempt.user_id == user.id)
        .order_by(QuizAttempt.started_at.desc())
    ).first()

    if not attempt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No attempt found")

    return QuizAttemptResponse(
        id=attempt.id,
        quiz_id=attempt.quiz_id,
        score=attempt.score,
        passed=attempt.passed,
        started_at=attempt.started_at,
        completed_at=attempt.completed_at,
    )