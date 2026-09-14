import logging

from sqlmodel import SQLModel, create_engine, Session
from sqlalchemy.orm import sessionmaker
from sqlalchemy import event

from app.core.config import settings

logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

# SQLite needs WAL + a busy timeout to survive concurrent readers/writers
# (the playlist/cache layer writes on every request). Without them, a QueuePool
# of modest size exhausts under load and every request times out (500s).
engine = create_engine(
    settings.DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False, "timeout": 30},
    pool_size=20,
    max_overflow=0,
    pool_pre_ping=True,
)

if settings.DATABASE_URL.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _set_sqlite_pragma(dbapi_conn, connection_record):
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA journal_mode=WAL")
        cur.execute("PRAGMA busy_timeout=30000")
        cur.execute("PRAGMA synchronous=NORMAL")
        cur.close()

SessionLocal = sessionmaker(bind=engine, class_=Session)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    SQLModel.metadata.create_all(engine)
    _migrate_target_duration()


def _migrate_target_duration():
    """Add video_resolutions.target_duration on pre-existing DBs and backfill
    it from stored segment durations, so playlist serving reads metadata."""
    import math

    from sqlalchemy import text

    with engine.connect() as conn:
        cols = [r[1] for r in conn.execute(text("PRAGMA table_info(video_resolutions)")).all()]
        if "target_duration" not in cols:
            conn.execute(text("ALTER TABLE video_resolutions ADD COLUMN target_duration FLOAT"))
            conn.commit()
        pending = conn.execute(
            text("SELECT id FROM video_resolutions WHERE target_duration IS NULL")
        ).all()
        for (res_id,) in pending:
            mx = conn.execute(
                text("SELECT MAX(duration_seconds) FROM video_segments WHERE resolution_id = :rid"),
                {"rid": res_id},
            ).scalar()
            conn.execute(
                text("UPDATE video_resolutions SET target_duration = :v WHERE id = :rid"),
                {"v": max(1, math.ceil(mx or 1.0)), "rid": res_id},
            )
        conn.commit()