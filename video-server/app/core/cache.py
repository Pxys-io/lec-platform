import json
import os
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from sqlmodel import Session, select

from app.core.config import settings
from app.core.database import get_db
from app.models.video import CacheEntry

_cache_worker_started = False
_cache_worker_lock = threading.Lock()


def _cache_storage_dir() -> Path:
    return Path(settings.CACHE_STORAGE_PATH)


def _type_dir(cache_type: str) -> Path:
    d = _cache_storage_dir() / cache_type.replace("_", "/")
    d.mkdir(parents=True, exist_ok=True)
    return d


def cache_get(
    db: Session, cache_key: str, cache_type: str
) -> Optional[CacheEntry]:
    entry = db.exec(
        select(CacheEntry)
        .where(CacheEntry.cache_key == cache_key)
        .where(CacheEntry.cache_type == cache_type)
        .where(CacheEntry.status == "active")
    ).first()
    if not entry:
        return None

    age = (datetime.utcnow() - entry.last_accessed).total_seconds()
    if age > entry.ttl_seconds:
        entry.status = "expired"
        db.add(entry)
        db.commit()
        return None

    entry.last_accessed = datetime.utcnow()
    db.add(entry)
    db.commit()
    return entry


def cache_set(
    db: Session,
    cache_key: str,
    cache_type: str,
    ttl_seconds: int,
    file_path: Optional[str] = None,
    data: Optional[str] = None,
) -> CacheEntry:
    entry = db.exec(
        select(CacheEntry)
        .where(CacheEntry.cache_key == cache_key)
        .where(CacheEntry.cache_type == cache_type)
    ).first()

    if entry:
        entry.file_path = file_path
        entry.data = data
        entry.ttl_seconds = ttl_seconds
        entry.last_accessed = datetime.utcnow()
        entry.status = "active"
    else:
        entry = CacheEntry(
            cache_key=cache_key,
            cache_type=cache_type,
            file_path=file_path,
            data=data,
            ttl_seconds=ttl_seconds,
            last_accessed=datetime.utcnow(),
            status="active",
        )
    db.add(entry)
    db.commit()
    return entry


def cache_get_or_compute(
    db: Session,
    cache_key: str,
    cache_type: str,
    ttl_seconds: int,
    compute_fn,
):
    existing = cache_get(db, cache_key, cache_type)
    if existing:
        return existing
    result = compute_fn()
    return cache_set(
        db, cache_key, cache_type, ttl_seconds,
        file_path=result.get("file_path"),
        data=result.get("data"),
    )


def cache_expire_old_entries(db: Session):
    now = datetime.utcnow()
    entries = db.exec(
        select(CacheEntry).where(CacheEntry.status == "active")
    ).all()
    expired_count = 0
    for entry in entries:
        age = (now - entry.last_accessed).total_seconds()
        if age > entry.ttl_seconds:
            entry.status = "expired"
            if entry.file_path and os.path.exists(entry.file_path):
                try:
                    os.remove(entry.file_path)
                except OSError:
                    pass
            db.add(entry)
            expired_count += 1
    if expired_count:
        db.commit()
    return expired_count


def start_cache_cleanup_worker(interval_seconds=300):
    global _cache_worker_started
    with _cache_worker_lock:
        if _cache_worker_started:
            return
        _cache_worker_started = True

    def _worker():
        while True:
            time.sleep(interval_seconds)
            try:
                db = next(get_db())
                count = cache_expire_old_entries(db)
                if count:
                    print(f"Cache cleanup: expired {count} entries")
            except Exception as e:
                print(f"Cache cleanup error: {e}")

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
