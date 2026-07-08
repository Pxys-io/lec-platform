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


def get_db() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session