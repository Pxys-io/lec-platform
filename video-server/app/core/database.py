import logging

from sqlmodel import SQLModel, create_engine, Session
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

engine = create_engine(settings.DATABASE_URL, echo=False)
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