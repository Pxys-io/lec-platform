"""
LEC Seed Script — Internal Medicine courses with sample HLS video.
Clears all data, creates video records, then seeds courses/lessons/quizzes.
"""
import sys, os, json, uuid, hashlib, shutil
from pathlib import Path
from datetime import datetime, timezone

# ── Paths ──
MAIN_DIR = Path(__file__).parent.parent / "main-server"
VIDEO_DIR = Path(__file__).parent.parent / "video-server"
STORAGE = VIDEO_DIR / "storage" / "videos"

sys.path.insert(0, str(MAIN_DIR))
sys.path.insert(0, str(VIDEO_DIR))

# ── Main server models ──
os.chdir(MAIN_DIR)
from sqlmodel import Session, select
from app.core.database import engine, create_db_and_tables
from app.models.user import User, UserRole, UserProfile, UserCourseAccess
from app.models.content import (
    Course, CourseVisibility, Lesson, LockType, Material, MaterialType, Quiz, Question,
)
from app.models.interaction import WatchHistory, Message

def _id(): return str(uuid.uuid4())
def _now(): return datetime.now(timezone.utc)
def _hash(pw): return hashlib.sha256(pw.encode()).hexdigest()


def seed():
    create_db_and_tables()

    # ── Check existing ──
    with Session(engine) as session:
        if session.exec(select(User).where(User.email == "admin@lec.com")).first():
            print("Clearing existing data...")
            for model in [Question, Quiz, Material, WatchHistory, Message,
                          UserCourseAccess, Lesson, Course, UserProfile, User]:
                for row in session.exec(select(model)).all():
                    session.delete(row)
            session.commit()

    # ── Create sample HLS videos ──
    print("Creating sample HLS videos...")
    video_ids = []
    for i in range(6):
        vid = _id()
        video_ids.append(vid)
        vdir = STORAGE / vid / "360p"
        vdir.mkdir(parents=True, exist_ok=True)

        # Copy segments
        for j, seg_src in enumerate(sorted(Path("/tmp/hls_segments").glob("*.ts"))):
            shutil.copy(seg_src, vdir / f"seg_{j:04d}.ts")

        # Write playlist
        seg_count = len(list(vdir.glob("*.ts")))
        lines = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-TARGETDURATION:11"]
        for j in range(seg_count):
            lines.append("#EXTINF:10.000,")
            lines.append(f"seg_{j:04d}.ts")
        lines.append("#EXT-X-ENDLIST")
        (vdir / "playlist.m3u8").write_text("\n".join(lines))

    # ── Video server DB ──
    print("Seeding video server DB...")
    os.chdir(VIDEO_DIR)
    from sqlmodel import Session as VSession, create_engine as VCreateEngine
    from sqlmodel import SQLModel as VSQLModel

    vs_engine = VCreateEngine(f"sqlite:///{VIDEO_DIR / 'video_server.db'}")
    from app.models.video import Video, VideoResolution, VideoSegment
    from app.core.database import init_db as v_init_db
    v_init_db()

    with VSession(vs_engine) as vs:
        for vid in video_ids:
            v = Video(
                id=vid, title=f"Lecture {video_ids.index(vid)+1}",
                description="Internal Medicine lecture",
                original_filename=f"lecture_{video_ids.index(vid)+1}.mp4",
                original_path=f"originals/{vid}.mp4",
                duration_seconds=50.0, width=848, height=480,
                status="ready", folder="Internal Medicine",
                streaming_mode="hls", watermark_enabled=True,
                storage_type="local", storage_path=str(STORAGE),
            )
            vs.add(v)
            vs.flush()

            r = VideoResolution(
                id=_id(), video_id=vid, resolution="360p",
                width=848, height=480, bitrate=460560,
                playlist_url=f"/videos/{vid}/playlist/360p",
                segments_count=5, total_size_bytes=3000000, status="ready",
            )
            vs.add(r)
            vs.flush()

            for j in range(5):
                seg = VideoSegment(
                    id=_id(), video_id=vid, resolution_id=r.id,
                    segment_index=j, filename=f"seg_{j:04d}.ts",
                    duration=10.0, size_bytes=600000,
                    storage_path=f"{vid}/360p/seg_{j:04d}.ts",
                )
                vs.add(seg)
        vs.commit()
    print(f"  ✅ {len(video_ids)} videos created in video server")

    # ── Main server seed ──
    print("Seeding main server DB...")
    os.chdir(MAIN_DIR)

    with Session(engine) as session:
        # Users
        admin_id, inst_id, stu_id = _id(), _id(), _id()
        session.add_all([
            User(id=admin_id, email="admin@lec.com", password_hash=_hash("admin123"),
                 phone="0000000000", role=UserRole.SUPER_ADMIN, created_at=_now()),
            User(id=inst_id, email="instructor@lec.com", password_hash=_hash("instructor123"),
                 phone="1111111111", role=UserRole.INSTRUCTOR, created_at=_now()),
            User(id=stu_id, email="student@lec.com", password_hash=_hash("student123"),
                 phone="2222222222", role=UserRole.STUDENT, created_at=_now()),
        ])
        session.flush()
        session.add_all([
            UserProfile(id=_id(), user_id=admin_id, first_name="Admin", last_name="User"),
            UserProfile(id=_id(), user_id=inst_id, first_name="Dr. Ahmed", last_name="Hassan"),
            UserProfile(id=_id(), user_id=stu_id, first_name="Sara", last_name="Ali"),
        ])

        # ── Internal Medicine Courses ──
        courses_data = [
            ("Cardiology Essentials",
             "Master the fundamentals of cardiovascular medicine — ECG interpretation, heart failure, arrhythmias, and valvular disease.",
             ["cardiology", "ecg", "heart-failure"], "public"),
            ("Pulmonology & Critical Care",
             "Respiratory medicine from basics to ICU — ABG interpretation, ventilator management, and sepsis protocols.",
             ["pulmonology", "critical-care", "icu"], "public"),
            ("Gastroenterology Review",
             "GI system diseases — liver cirrhosis, IBD, GI bleeding management, and hepatobiliary disorders.",
             ["gastroenterology", "hepatology", "gi"], "public"),
            ("Nephrology & Fluid Balance",
             "Kidney diseases, electrolyte disorders, acid-base balance, and dialysis principles.",
             ["nephrology", "electrolytes", "dialysis"], "private"),
            ("Endocrinology & Diabetes",
             "Endocrine disorders — diabetes mellitus, thyroid disease, adrenal pathology, and metabolic syndrome.",
             ["endocrinology", "diabetes", "thyroid"], "public"),
        ]

        courses = []
        for title, desc, tags, vis in courses_data:
            c = Course(id=_id(), title=title, description=desc,
                       instructor_id=inst_id, tags=json.dumps(tags),
                       visibility=vis, created_at=_now(), updated_at=_now())
            session.add(c)
            courses.append(c)
        session.flush()

        # ── Lessons per course (internal medicine topics) ──
        lessons_config = [
            # Cardiology
            [("ECG Basics & Normal Rhythm", "Understanding the PQRST complex, axis, and rate calculation.", "none"),
             ("Heart Failure Classification", "NYHA classes, systolic vs diastolic HF, and BNP interpretation.", "previous_lesson"),
             ("Acute Coronary Syndromes", "STEMI vs NSTEMI, troponins, and reperfusion strategies.", "previous_lesson"),
             ("Valvular Heart Disease", "Murmurs, echocardiographic findings, and surgical indications.", "quiz"),
             ("Arrhythmias & ECG Interpretation", "AF, SVT, VT, heart blocks — diagnosis and management.", "previous_lesson"),],
            # Pulmonology
            [("ABG Interpretation Made Simple", "Step-by-step arterial blood gas analysis with clinical scenarios.", "none"),
             ("COPD & Asthma Management", "GOLD guidelines, inhaler therapy, and acute exacerbations.", "previous_lesson"),
             ("Pneumonia & Empyema", "Community vs hospital-acquired, CURB-65, and antibiotic selection.", "previous_lesson"),
             ("Mechanical Ventilation Basics", "Modes, settings, weaning protocols, and ventilator-associated events.", "previous_lesson"),
             ("Sepsis & Septic Shock", "Surviving Sepsis Campaign, fluid resuscitation, and vasopressors.", "quiz"),],
            # Gastroenterology
            [("Upper GI Bleeding", "Variceal vs non-variceal, Rockall score, and endoscopic management.", "none"),
             ("Liver Cirrhosis & Complications", "Child-Pugh, MELD score, ascites, SBP, and hepatorenal syndrome.", "previous_lesson"),
             ("Inflammatory Bowel Disease", "Crohn's vs UC, extraintestinal manifestations, and biologic therapy.", "previous_lesson"),
             ("Hepatitis A to E", "Viral hepatitis serology, treatment algorithms, and vaccination.", "previous_lesson"),
             ("Pancreatitis — Acute & Chronic", "Ranson's criteria, imaging, and management of complications.", "quiz"),],
            # Nephrology
            [("AKI vs CKD Classification", "KDIGO staging, risk factors, and when to dialyze.", "none"),
             ("Electrolyte Emergencies", "Hyperkalemia, hyponatremia, hypercalcemia — rapid management.", "previous_lesson"),
             ("Acid-Base Disorders", "Metabolic acidosis/alkalosis, respiratory compensation, and anion gap.", "previous_lesson"),
             ("Nephrotic vs Nephritic Syndrome", "Presentation, workup, and biopsy findings.", "previous_lesson"),
             ("Dialysis Indications & Types", "HD vs PD, emergent indications, and access options.", "quiz"),],
            # Endocrinology
            [("Diabetes Mellitus — Type 1 vs 2", "Pathophysiology, diagnostic criteria, and initial management.", "none"),
             ("Diabetic Ketoacidosis", "DKA protocol — fluids, insulin, potassium monitoring.", "previous_lesson"),
             ("Thyroid Disorders", "Hypo/hyperthyroidism, thyroid nodules, and cancer workup.", "previous_lesson"),
             ("Adrenal Insufficiency", "Primary vs secondary, Addison's disease, and stress dosing.", "previous_lesson"),
             ("Metabolic Syndrome & Obesity", "Diagnostic criteria, cardiovascular risk, and lifestyle interventions.", "quiz"),],
        ]

        all_lessons = []
        vid_idx = 0
        for ci, (course, lconfig) in enumerate(zip(courses, lessons_config)):
            for li, (title, desc, lock) in enumerate(lconfig):
                vid = video_ids[vid_idx % len(video_ids)] if li < 3 else None  # First 3 lessons get videos
                if li < 3:
                    vid_idx += 1
                l = Lesson(id=_id(), course_id=course.id, title=title, description=desc,
                           order=li+1, lock_type=lock, video_id=vid, is_published=True,
                           created_at=_now(), updated_at=_now())
                session.add(l)
                all_lessons.append(l)
        session.flush()

        # ── Materials ──
        materials_data = [
            (0, "link", "ECG Made Simple", "https://ecg.utah.edu/"),
            (1, "pdf", "NYHA Classification Guide", "https://example.com/nyha.pdf"),
            (5, "link", "ABG Calculator", "https://abgcalc.com/"),
            (10, "pdf", "Upper GI Bleeding Algorithm", "https://example.com/gi-bleed.pdf"),
            (15, "link", "KDIGO Guidelines", "https://kdigo.org/guidelines/"),
            (20, "pdf", "Insulin Protocol Card", "https://example.com/insulin.pdf"),
        ]
        for li_offset, mtype, title, url in materials_data:
            if li_offset < len(all_lessons):
                session.add(Material(id=_id(), lesson_id=all_lessons[li_offset].id,
                                     type=mtype, title=title, url=url))

        # ── Quizzes ──
        quiz_configs = [
            (3, "Cardiology Board-Style Quiz", "Test your cardiology knowledge.", 70.0, 15,
             [("What does ST elevation in leads II, III, aVF suggest?",
               ["Anterior MI", "Inferior MI", "Lateral MI"], "Inferior MI"),
              ("Which BNP level strongly suggests heart failure?",
               [">100 pg/mL", ">400 pg/mL", ">1000 pg/mL"], ">400 pg/mL"),
              ("Austin Flint murmur is associated with?",
               ["Mitral stenosis", "Aortic regurgitation", "Tricuspid regurgitation"], "Aortic regurgitation"),]),
            (9, "Pulmonology Assessment", "Critical care and respiratory medicine quiz.", 60.0, 10,
             [("A patient has pH 7.28, PaCO2 55, HCO3 24. What is the primary disorder?",
               ["Metabolic acidosis", "Respiratory acidosis", "Respiratory alkalosis"], "Respiratory acidosis"),
              ("First-line vasopressor in septic shock?",
               ["Dopamine", "Norepinephrine", "Vasopressin"], "Norepinephrine"),
              ("CURB-65 includes all EXCEPT?",
               ["Urea >7", "Respiratory rate ≥30", "Blood glucose >180"], "Blood glucose >180"),]),
            (14, "GI Board Review", "Gastroenterology knowledge assessment.", 70.0, 12,
             [("First-line treatment for acute variceal bleeding?",
               ["PPI IV", "Octreotide + band ligation", "TIPS"], "Octreotide + band ligation"),
              ("Which IBD has skip lesions and cobblestoning?",
               ["Ulcerative colitis", "Crohn's disease", "Both"], "Crohn's disease"),
              ("Most common cause of acute pancreatitis worldwide?",
               ["Alcohol", "Gallstones", "Hypertriglyceridemia"], "Gallstones"),]),
            (19, "Nephrology Quiz", "Kidney and electrolyte disorders assessment.", 65.0, 10,
             [("Immediate treatment for severe hyperkalemia (K+ >6.5) with ECG changes?",
               ["Kayexalate", "Calcium gluconate", "Insulin + dextrose"], "Calcium gluconate"),
              ("Anion gap metabolic acidosis is seen in?",
               ["Diarrhea", "DKA", "RTA Type 1"], "DKA"),
              ("Nephrotic syndrome in adults — most common cause?",
               ["Minimal change disease", "Membranous nephropathy", "FSGS"], "Membranous nephropathy"),]),
            (24, "Endocrinology Final Quiz", "Diabetes and endocrine disorders assessment.", 60.0, 12,
             [("HbA1c diagnostic cutoff for diabetes?",
               [">5.7%", ">6.5%", ">7.0%"], ">6.5%"),
              ("In DKA, which electrolyte must be checked before starting insulin?",
               ["Sodium", "Potassium", "Calcium"], "Potassium"),
              ("Most common cause of hypothyroidism worldwide?",
               ["Iodine deficiency", "Hashimoto's thyroiditis", "Post-surgical"], "Hashimoto's thyroiditis"),]),
        ]

        for qi, (lesson_offset, title, desc, passing, time_limit, questions) in enumerate(quiz_configs):
            if lesson_offset < len(all_lessons):
                lesson = all_lessons[lesson_offset]
                quiz = Quiz(id=_id(), lesson_id=lesson.id, title=title, description=desc,
                            passing_score=passing, time_limit=time_limit, created_at=_now())
                session.add(quiz)
                session.flush()
                lesson.quiz_id = quiz.id
                for oi, (question, opts, answer) in enumerate(questions):
                    session.add(Question(id=_id(), quiz_id=quiz.id, type="multiple_choice",
                                         question=question, options=json.dumps(opts),
                                         correct_answer=answer, points=1.0, order=oi+1))

        # ── Access & messages ──
        for c in courses:
            session.add(UserCourseAccess(id=_id(), user_id=stu_id, course_id=c.id,
                                         access_type="full", created_at=_now()))

        session.add(Message(id=_id(), sender_id=admin_id, recipient_id=stu_id,
                            content="Welcome to LEC Internal Medicine! Start with Cardiology.", created_at=_now()))

        session.commit()

    # ── Print summary ──
    print("\n" + "="*50)
    print("✅ SEED COMPLETE — Internal Medicine")
    print("="*50)
    print(f"  Courses:    {len(courses)}")
    print(f"  Lessons:    {len(all_lessons)}")
    print(f"  Videos:     {len(video_ids)} (HLS 360p, 5 segments each)")
    print(f"  Quizzes:    {len(quiz_configs)}")
    print()
    print("  Users:")
    print(f"    Admin:      admin@lec.com / admin123")
    print(f"    Instructor: instructor@lec.com / instructor123")
    print(f"    Student:    student@lec.com / student123")


if __name__ == "__main__":
    seed()
