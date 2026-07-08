from typing import Optional, List
from pydantic import BaseModel
from datetime import datetime

class UploadInitRequest(BaseModel):
    title: str
    description: Optional[str] = None
    filename: str
    total_size: int
    total_chunks: int
    watermark_enabled: bool = True
    created_by: Optional[str] = None
    folder: str = "General"
    streaming_mode: str = "hls"

class UploadInitResponse(BaseModel):
    upload_id: str

class UploadStatusResponse(BaseModel):
    upload_id: str
    received_chunks: List[int]
    total_chunks: int

class VideoBase(BaseModel):
    title: str
    description: Optional[str] = None
    folder: str = "General"
    streaming_mode: str = "hls"
    watermark_enabled: bool = True
    watermark_mode: str = "insert"
    watermark_segments: int = 10
    watermark_text: Optional[str] = None
    watermark_color: str = "#FFFFFF"
    watermark_font_size: int = 20
    watermark_opacity: float = 0.4
    watermark_overlay_count: int = 1
    watermark_insert_duration: float = 1.0
    watermark_insert_repeat: int = 1
    watermark_position: str = "random"


class VideoCreate(VideoBase):
    original_filename: str
    original_path: str
    created_by: Optional[str] = None


class VideoUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    folder: Optional[str] = None
    streaming_mode: Optional[str] = None
    watermark_enabled: Optional[bool] = None
    watermark_mode: Optional[str] = None
    watermark_segments: Optional[int] = None
    watermark_text: Optional[str] = None
    watermark_color: Optional[str] = None
    watermark_font_size: Optional[int] = None
    watermark_opacity: Optional[float] = None
    watermark_overlay_count: Optional[int] = None
    watermark_insert_duration: Optional[float] = None
    watermark_insert_repeat: Optional[int] = None
    watermark_position: Optional[str] = None
    status: Optional[str] = None


class VideoResponse(VideoBase):
    id: str
    original_filename: str
    original_path: str
    duration_seconds: Optional[float] = None
    width: Optional[int] = None
    height: Optional[int] = None
    status: str
    storage_type: str
    storage_path: Optional[str] = None
    cdn_url: Optional[str] = None
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class VideoResolutionResponse(BaseModel):
    id: str
    video_id: str
    resolution: str
    width: int
    height: int
    bitrate: int
    playlist_url: Optional[str] = None
    segments_count: int
    total_size_bytes: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class VideoDetailResponse(VideoResponse):
    resolutions: List[VideoResolutionResponse] = []

    class Config:
        from_attributes = True


class TranscodeJobResponse(BaseModel):
    id: str
    video_id: str
    status: str
    progress: float
    resolutions_requested: str
    resolutions_completed: str
    fail_count: int
    priority: int
    queue_position: Optional[int] = None
    error_message: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SegmentResponse(BaseModel):
    id: str
    video_id: str
    resolution_id: str
    segment_number: int
    segment_hash: str
    filename: str
    duration_seconds: float
    byte_size: int
    is_watermark: bool
    storage_type: str
    storage_path: Optional[str] = None

    class Config:
        from_attributes = True


class ManifestResponse(BaseModel):
    video_id: str
    folder: str = "General"
    streaming_mode: str = "hls"
    watermark_enabled: bool = True
    watermark_mode: str = "insert"
    watermark_color: str = "#FFFFFF"
    watermark_font_size: int = 20
    watermark_opacity: float = 0.4
    watermark_overlay_count: int = 1
    watermark_insert_duration: float = 1.0
    watermark_insert_repeat: int = 1
    watermark_position: str = "random"
    resolutions: List[VideoResolutionResponse]
    default_resolution: str = "720p"


class VideoUploadResponse(BaseModel):
    video_id: str
    upload_url: str
    expires_at: datetime