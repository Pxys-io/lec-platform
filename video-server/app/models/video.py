import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field


class Video(SQLModel, table=True):
    __tablename__ = "videos"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    title: str
    description: Optional[str] = None
    original_filename: str
    original_path: str

    duration_seconds: Optional[float] = None
    width: Optional[int] = None
    height: Optional[int] = None
    codec: Optional[str] = None
    bitrate: Optional[int] = None

    status: str = "pending"
    folder: str = "General"
    streaming_mode: str = "hls"  # "hls" or "direct"

    watermark_enabled: bool = True
    watermark_mode: str = "insert"  # "insert" or "overlay"
    watermark_segments: int = 10
    watermark_text: Optional[str] = None
    watermark_color: str = "#FFFFFF"
    watermark_font_size: int = 20
    watermark_opacity: float = 0.4
    watermark_overlay_count: int = 1
    watermark_insert_duration: float = 1.0
    watermark_insert_repeat: int = 1
    watermark_position: str = "random"
    watermark_break_duration: int = 60
    encryption_key_hex: Optional[str] = None
    encryption_iv_hex: Optional[str] = None
    is_encrypted: bool = False

    storage_type: str = "local"
    storage_path: Optional[str] = None
    cdn_url: Optional[str] = None

    transcode_method: str = "local"  # "local" or "mux"
    mux_asset_id: Optional[str] = None
    mux_playback_id: Optional[str] = None

    created_by: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class VideoResolution(SQLModel, table=True):
    __tablename__ = "video_resolutions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    video_id: str = Field(foreign_key="videos.id")
    resolution: str
    width: int
    height: int
    bitrate: int
    playlist_url: Optional[str] = None

    segments_count: int = 0
    total_size_bytes: int = 0

    status: str = "pending"

    created_at: datetime = Field(default_factory=datetime.utcnow)


class VideoSegment(SQLModel, table=True):
    __tablename__ = "video_segments"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    video_id: str = Field(foreign_key="videos.id")
    resolution_id: str = Field(foreign_key="video_resolutions.id")

    segment_number: int
    segment_hash: str
    filename: str

    duration_seconds: float
    byte_size: int

    is_watermark: bool = False
    watermark_text: Optional[str] = None

    storage_type: str = "local"
    storage_path: Optional[str] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)


class TranscodeJob(SQLModel, table=True):
    __tablename__ = "transcode_jobs"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    video_id: str = Field(foreign_key="videos.id")

    status: str = "pending"  # pending, running, completed, error, cancelled
    progress: float = 0.0

    resolutions_requested: str = "360p,480p,720p,1080p"
    resolutions_completed: str = ""

    fail_count: int = Field(default=0)
    error_message: Optional[str] = None
    priority: int = Field(default=0)

    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    created_at: datetime = Field(default_factory=datetime.utcnow)


class WatchSession(SQLModel, table=True):
    __tablename__ = "watch_sessions"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    video_id: str = Field(foreign_key="videos.id")
    user_id: Optional[str] = None

    resolution: str
    segment_start: int
    segment_end: int
    completed: bool = False

    created_at: datetime = Field(default_factory=datetime.utcnow)


class CacheEntry(SQLModel, table=True):
    __tablename__ = "cache_entries"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    cache_key: str = Field(index=True)
    cache_type: str = Field(index=True)
    file_path: Optional[str] = None
    data: Optional[str] = None
    ttl_seconds: int
    last_accessed: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    status: str = "active"