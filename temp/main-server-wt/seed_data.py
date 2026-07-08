import sys, os, json, uuid, hashlib
from pathlib import Path
from datetime import datetime, timedelta, timezone

sys.path.append(os.getcwd())

from sqlmodel import Session, select
from app.core.database import engine, create_db_and_tables
from app.models.user import User, UserRole, UserProfile, UserCourseAccess
from app.models.content import (
    Course,
    CourseVisibility,
    Lesson,
    LockType,
    Material,
    MaterialType,
    Quiz,
    Question,
)
from app.models.interaction import WatchHistory, Message, AccessCode


def _hash(pw: str) -> str:
    return hashlib.sha256(pw.encode()).hexdigest()


def _id() -> str:
    return str(uuid.uuid4())


def _now():
    return datetime.now(timezone.utc)


def seed():
    create_db_and_tables()
    with Session(engine) as session:
        existing = session.exec(
            select(User).where(User.email == "admin@lec.com")
        ).first()
        if existing:
            print("Data already seeded. Skipping.")
            return

        admin_id = _id()
        inst_id = _id()
        stu_id = _id()

        users = [
            User(
                id=admin_id,
                email="admin@lec.com",
                password_hash=_hash("admin123"),
                phone="0000000000",
                role=UserRole.SUPER_ADMIN,
                created_at=_now(),
            ),
            User(
                id=inst_id,
                email="instructor@lec.com",
                password_hash=_hash("instructor123"),
                phone="1111111111",
                role=UserRole.INSTRUCTOR,
                created_at=_now(),
            ),
            User(
                id=stu_id,
                email="student@lec.com",
                password_hash=_hash("student123"),
                phone="2222222222",
                role=UserRole.STUDENT,
                created_at=_now(),
            ),
        ]
        session.add_all(users)
        session.flush()

        profiles = [
            UserProfile(
                id=_id(), user_id=admin_id, first_name="Admin", last_name="User"
            ),
            UserProfile(id=_id(), user_id=inst_id, first_name="John", last_name="Doe"),
            UserProfile(id=_id(), user_id=stu_id, first_name="Jane", last_name="Smith"),
        ]
        session.add_all(profiles)

        courses_data = [
            (
                "Introduction to Python Programming",
                "Learn Python from scratch — variables, loops, functions, and OOP.",
                inst_id,
                ["python", "programming", "beginner"],
                "public",
            ),
            (
                "Advanced Web Development",
                "Master React, FastAPI, and deployment strategies.",
                inst_id,
                ["web", "javascript", "advanced"],
                "public",
            ),
            (
                "Data Science Fundamentals",
                "Statistics, Pandas, and machine learning basics.",
                inst_id,
                ["data-science"],
                "private",
            ),
        ]
        courses = []
        for title, desc, iid, tags, vis in courses_data:
            c = Course(
                id=_id(),
                title=title,
                description=desc,
                instructor_id=iid,
                tags=json.dumps(tags),
                visibility=vis,
                created_at=_now(),
                updated_at=_now(),
            )
            session.add(c)
            courses.append(c)
        session.flush()

        video_ids = []
        video_ids_file = Path(__file__).parent.parent / "video_ids.json"
        if video_ids_file.exists():
            video_ids = json.loads(video_ids_file.read_text())
            print(f"  Loaded {len(video_ids)} video IDs from video_ids.json")
        else:
            video_ids = []
            print("  No video IDs found, using None for video lessons")

        lessons_data = [
            (
                courses[0].id,
                "Variables & Data Types",
                "Understand integers, floats, strings, and booleans.",
                1,
                "none",
                True,
                video_ids[0],
            ),
            (
                courses[0].id,
                "Control Flow",
                "If-else, for loops, and while loops.",
                2,
                "previous_lesson",
                True,
                video_ids[1],
            ),
            (
                courses[0].id,
                "Functions",
                "Define and call functions, scope, and parameters.",
                3,
                "previous_lesson",
                True,
                video_ids[2],
            ),
            (
                courses[0].id,
                "Object-Oriented Python",
                "Classes, inheritance, and polymorphism.",
                4,
                "quiz",
                True,
                None,
            ),
            (
                courses[1].id,
                "React Fundamentals",
                "Components, props, state, and hooks.",
                1,
                "none",
                True,
                video_ids[3],
            ),
            (
                courses[1].id,
                "FastAPI Backend",
                "Build REST APIs with FastAPI and SQLModel.",
                2,
                "previous_lesson",
                True,
                video_ids[4],
            ),
            (
                courses[1].id,
                "Deployment",
                "Docker, CI/CD, and cloud hosting.",
                3,
                "previous_lesson",
                True,
                video_ids[5],
            ),
            (
                courses[2].id,
                "Statistics Review",
                "Mean, median, standard deviation, and probability.",
                1,
                "none",
                True,
                None,
            ),
            (
                courses[2].id,
                "Pandas & Data Wrangling",
                "DataFrames, filtering, groupby, and joins.",
                2,
                "previous_lesson",
                True,
                None,
            ),
            (
                courses[2].id,
                "Intro to Machine Learning",
                "Supervised vs unsupervised learning, scikit-learn.",
                3,
                "previous_lesson",
                True,
                None,
            ),
        ]
        lessons = []
        for cid, title, desc, order, lock, pub, vid in lessons_data:
            l = Lesson(
                id=_id(),
                course_id=cid,
                title=title,
                description=desc,
                order=order,
                lock_type=lock,
                video_id=vid,
                is_published=pub,
                created_at=_now(),
                updated_at=_now(),
            )
            session.add(l)
            lessons.append(l)
        session.flush()

        materials_data = [
            (
                lessons[0].id,
                "link",
                "Python Official Docs",
                "https://docs.python.org/3/",
            ),
            (
                lessons[0].id,
                "pdf",
                "Python Cheat Sheet",
                "https://example.com/python-cheat-sheet.pdf",
            ),
            (
                lessons[1].id,
                "link",
                "Looping Techniques",
                "https://realpython.com/python-loops/",
            ),
            (lessons[4].id, "link", "React Docs", "https://react.dev/"),
            (
                lessons[7].id,
                "pdf",
                "Statistics Quick Guide",
                "https://example.com/stats-guide.pdf",
            ),
        ]
        for lid, mtype, title, url in materials_data:
            session.add(
                Material(id=_id(), lesson_id=lid, type=mtype, title=title, url=url)
            )

        quiz_lesson = lessons[3]
        quiz = Quiz(
            id=_id(),
            lesson_id=quiz_lesson.id,
            title="Python OOP Quiz",
            description="Test your OOP knowledge.",
            passing_score=70.0,
            time_limit=10,
            created_at=_now(),
        )
        session.add(quiz)
        session.flush()
        quiz_lesson.quiz_id = quiz.id

        questions = [
            (
                quiz.id,
                "multiple_choice",
                "What does `class` keyword do?",
                json.dumps(
                    ["Defines a function", "Defines a class", "Imports a module"]
                ),
                "Defines a class",
                1.0,
                1,
            ),
            (
                quiz.id,
                "multiple_choice",
                "What is `self` in Python methods?",
                json.dumps(
                    [
                        "The class name",
                        "The instance reference",
                        "A keyword for private vars",
                    ]
                ),
                "The instance reference",
                1.0,
                2,
            ),
            (
                quiz.id,
                "multiple_choice",
                "Which method is called on object creation?",
                json.dumps(["__init__", "__str__", "__call__"]),
                "__init__",
                1.0,
                3,
            ),
        ]
        for qid, qtype, question, opts, answer, points, order in questions:
            session.add(
                Question(
                    id=_id(),
                    quiz_id=qid,
                    type=qtype,
                    question=question,
                    options=opts,
                    correct_answer=answer,
                    points=points,
                    order=order,
                )
            )

        quiz_lesson2 = lessons[6]
        quiz2 = Quiz(
            id=_id(),
            lesson_id=quiz_lesson2.id,
            title="Web Dev Final Quiz",
            description="Test your full-stack knowledge.",
            passing_score=60.0,
            time_limit=15,
            created_at=_now(),
        )
        session.add(quiz2)
        session.flush()
        quiz_lesson2.quiz_id = quiz2.id

        questions2 = [
            (
                quiz2.id,
                "multiple_choice",
                "What is React?",
                json.dumps(["A database", "A UI library", "A backend framework"]),
                "A UI library",
                1.0,
                1,
            ),
            (
                quiz2.id,
                "multiple_choice",
                "What does FastAPI use for validation?",
                json.dumps(["Pydantic", "Django ORM", "Flask"]),
                "Pydantic",
                1.0,
                2,
            ),
            (
                quiz2.id,
                "multiple_choice",
                "Which tool is used for containerization?",
                json.dumps(["Docker", "npm", "Webpack"]),
                "Docker",
                1.0,
                3,
            ),
        ]
        for qid, qtype, question, opts, answer, points, order in questions2:
            session.add(
                Question(
                    id=_id(),
                    quiz_id=qid,
                    type=qtype,
                    question=question,
                    options=opts,
                    correct_answer=answer,
                    points=points,
                    order=order,
                )
            )

        for c in courses:
            session.add(
                UserCourseAccess(
                    id=_id(),
                    user_id=stu_id,
                    course_id=c.id,
                    access_type="full",
                    created_at=_now(),
                )
            )

        session.add(
            WatchHistory(
                id=_id(),
                user_id=stu_id,
                lesson_id=lessons[0].id,
                watch_time=300.0,
                completion_percentage=100.0,
                last_position=300.0,
                created_at=_now(),
                updated_at=_now(),
            )
        )
        session.add(
            WatchHistory(
                id=_id(),
                user_id=stu_id,
                lesson_id=lessons[1].id,
                watch_time=150.0,
                completion_percentage=45.0,
                last_position=150.0,
                created_at=_now(),
                updated_at=_now(),
            )
        )

        session.add(
            Message(
                id=_id(),
                sender_id=admin_id,
                recipient_id=stu_id,
                content="Welcome to LEC! Start your learning journey.",
                created_at=_now(),
            )
        )
        session.add(
            Message(
                id=_id(),
                sender_id=stu_id,
                recipient_id=inst_id,
                content="Great course, thanks!",
                created_at=_now(),
            )
        )

        session.commit()

        print(f"✅ Admin:      admin@lec.com / admin123")
        print(f"✅ Instructor: instructor@lec.com / instructor123")
        print(f"✅ Student:    student@lec.com / student123")
        print(
            f"✅ {len(courses)} courses, {len(lessons)} lessons, {len(materials_data)} materials, {len(questions)} quiz questions seeded"
        )


if __name__ == "__main__":
    seed()
