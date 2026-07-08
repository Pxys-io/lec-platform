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