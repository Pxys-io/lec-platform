import logging

from sqlmodel import SQLModel, create_engine, Session
from typing import Generator

from app.core.config import settings

logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)

engine = create_engine(
    settings.DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {},
)


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)
    _migrate_qbank_taxonomy()


def _migrate_qbank_taxonomy():
    """Additive columns for the UWorld-style QBank upgrade on pre-existing
    DBs (create_all never alters). Idempotent: checks PRAGMA first."""
    from sqlalchemy import text

    wanted = {
        "questions": [
            ("subject", "VARCHAR"),
            ("system", "VARCHAR"),
            ("topic", "VARCHAR"),
        ],
        "qbanks": [
            ("course_id", "VARCHAR"),
        ],
    }
    with engine.connect() as conn:
        for table, cols in wanted.items():
            try:
                existing = {
                    r[1]
                    for r in conn.execute(
                        text(f"PRAGMA table_info({table})")
                    ).all()
                }
            except Exception:
                continue
            for name, ddl in cols:
                if name not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
            conn.commit()


def get_db() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session