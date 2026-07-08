import os
import uuid
import hashlib
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query, File, UploadFile
from sqlmodel import Session, select

from app.core.database import get_db
from app.core.config import settings
from app.models.video import Video, VideoResolution, VideoSegment, TranscodeJob
from app.schemas.video import (
    VideoCreate,
    VideoUpdate,
    VideoResponse,
    VideoDetailResponse,
    VideoResolutionResponse,
    ManifestResponse,
    TranscodeJobResponse,
    UploadInitRequest,
    UploadInitResponse,
    UploadStatusResponse,
)

from app.core.overlay_queue import get_overlay_queue, OverlayJob
from app.core.cache import cache_get_or_compute, cache_set, start_cache_cleanup_worker

router = APIRouter(prefix="/internal/videos", tags=["internal"])


def get_upload_dir(upload_id: str) -> Path:
    return Path(settings.VIDEO_STORAGE_PATH) / "uploads" / upload_id


def _compute_watermark_positions(video, segments, user_email):
    import random
    seed_str = f"{video.id}-{user_email or 'anon'}"
    random.seed(seed_str)
    import json as _json
    total_segments = len(segments)
    num_marks = min(total_segments, video.watermark_segments)
    if num_marks <= 0:
        return {"data": _json.dumps([])}
    if num_marks >= total_segments:
        return {"data": _json.dumps(list(range(total_segments)))}
    mark_indices = set()
    part_size = total_segments / num_marks
    for i in range(num_marks):
        start = int(i * part_size)
        end = int((i + 1) * part_size) if i < num_marks - 1 else total_segments
        if end - start > 1 and i < num_marks - 1:
            end -= 1
        idx = random.randint(start, end - 1) if start < end else start
        mark_indices.add(idx)
    return {"data": _json.dumps(list(mark_indices))}


start_cache_cleanup_worker()

@router.post("/upload/init", response_model=UploadInitResponse)
def init_upload(
    request: UploadInitRequest,
    db: Session = Depends(get_db),
):
    ensure_storage_dirs()
    video_id = str(uuid.uuid4())

    upload_dir = get_upload_dir(video_id)
    upload_dir.mkdir(parents=True, exist_ok=True)

    import json
    metadata = request.dict()
    metadata["total_chunks"] = request.total_chunks
    with open(upload_dir / "metadata.json", "w") as f:
        json.dump(metadata, f)

    return UploadInitResponse(upload_id=video_id)

@router.post("/upload/{upload_id}/chunk")
async def upload_chunk(
    upload_id: str,
    chunk_index: int = Query(...),
    file: UploadFile = File(...),
):
    upload_dir = get_upload_dir(upload_id)
    if not upload_dir.exists():
        raise HTTPException(status_code=404, detail="Upload session not found")

    chunk_path = upload_dir / f"chunk_{chunk_index}"
    with open(chunk_path, "wb") as buffer:
        buffer.write(await file.read())

    return {"message": "Chunk received", "chunk_index": chunk_index}

@router.get("/upload/{upload_id}/status", response_model=UploadStatusResponse)
def upload_status(upload_id: str):
    upload_dir = get_upload_dir(upload_id)
    if not upload_dir.exists():
        raise HTTPException(status_code=404, detail="Upload session not found")

    import json
    with open(upload_dir / "metadata.json", "r") as f:
        metadata = json.load(f)

    received_chunks = []
    for i in range(metadata["total_chunks"]):
        if (upload_dir / f"chunk_{i}").exists():
            received_chunks.append(i)

    return UploadStatusResponse(
        upload_id=upload_id,
        received_chunks=received_chunks,
        total_chunks=metadata["total_chunks"]
    )

@router.post("/upload/{upload_id}/complete", response_model=VideoResponse)
def complete_upload(
    upload_id: str,
    db: Session = Depends(get_db),
):
    upload_dir = get_upload_dir(upload_id)
    if not upload_dir.exists():
        raise HTTPException(status_code=404, detail="Upload session not found")

    import json
    with open(upload_dir / "metadata.json", "r") as f:
        metadata = json.load(f)

    total_chunks = metadata["total_chunks"]
    for i in range(total_chunks):
        if not (upload_dir / f"chunk_{i}").exists():
            raise HTTPException(status_code=400, detail=f"Missing chunk {i}")

    ext = os.path.splitext(metadata["filename"])[1]
    originals_dir = Path(settings.VIDEO_STORAGE_PATH) / "originals"
    originals_dir.mkdir(exist_ok=True)

    original_path = originals_dir / f"{upload_id}{ext}"

    with open(original_path, "wb") as outfile:
        for i in range(total_chunks):
            chunk_path = upload_dir / f"chunk_{i}"
            with open(chunk_path, "rb") as infile:
                outfile.write(infile.read())

    import shutil
    shutil.rmtree(upload_dir)

    video = Video(
        id=upload_id,
        title=metadata["title"],
        description=metadata.get("description"),
        original_filename=metadata["filename"],
        original_path=str(original_path),
        watermark_enabled=metadata.get("watermark_enabled", True),
        created_by=metadata.get("created_by"),
        folder=metadata.get("folder", "General"),
        streaming_mode=metadata.get("streaming_mode", "hls"),
        storage_type=settings.VIDEO_STORAGE_TYPE,
        storage_path=settings.VIDEO_STORAGE_PATH,
        status="pending",
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    if settings.MUX_ENABLED:
        import threading
        from app.core.mux import mux_transcode
        threading.Thread(target=mux_transcode, args=(upload_id,), daemon=True).start()
    else:
        job = TranscodeJob(
            video_id=upload_id,
            status="pending",
            resolutions_requested="360p,480p,720p,1080p",
            priority=0,
        )
        db.add(job)
        db.commit()

    return video


def compute_segment_hash(video_id: str, segment_num: int, resolution: str) -> str:
    data = f"{video_id}-{segment_num}-{resolution}-{datetime.utcnow().isoformat()}"
    return hashlib.sha256(data.encode()).hexdigest()[:12]


def ensure_storage_dirs():
    Path(settings.VIDEO_STORAGE_PATH).mkdir(parents=True, exist_ok=True)


from app.core.worker import worker

@router.get("/jobs", response_model=list[TranscodeJobResponse])
def list_jobs(
    video_id: Optional[str] = None,
    user_id: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    query = select(TranscodeJob)
    if video_id:
        query = query.where(TranscodeJob.video_id == video_id)
    if status:
        query = query.where(TranscodeJob.status == status)
    
    # If user_id is provided, we need to join with Video to filter by created_by
    if user_id:
        query = query.join(Video).where(Video.created_by == user_id)
        
    jobs = db.exec(query.order_by(TranscodeJob.created_at.desc())).all()
    
    # Calculate queue positions
    pending_jobs = db.exec(
        select(TranscodeJob)
        .where(TranscodeJob.status.in_(["pending", "running"]))
        .order_by(TranscodeJob.priority.desc(), TranscodeJob.created_at.asc())
    ).all()
    
    job_positions = {job.id: i for i, job in enumerate(pending_jobs)}
    
    response = []
    for job in jobs:
        job_resp = TranscodeJobResponse.from_orm(job)
        job_resp.queue_position = job_positions.get(job.id)
        video = db.get(Video, job.video_id)
        if video:
            job_resp.transcode_method = video.transcode_method
        response.append(job_resp)

    return response


@router.post("/jobs/{job_id}/kill")
def kill_job(
    job_id: str,
    db: Session = Depends(get_db),
):
    job = db.get(TranscodeJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.status == "running":
        success = worker.kill_job(job_id)
        if success:
            job.status = "cancelled"
            db.add(job)
            db.commit()
            return {"message": "Job killed successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to kill running job")
    elif job.status == "pending":
        job.status = "cancelled"
        db.add(job)
        db.commit()
        return {"message": "Job cancelled successfully"}
    else:
        raise HTTPException(status_code=400, detail=f"Cannot kill job in status {job.status}")


@router.get("", response_model=list[VideoResponse])
def list_videos(
    skip: int = 0,
    limit: int = 50,
    created_by: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    query = select(Video)
    if created_by:
        query = query.where(Video.created_by == created_by)
    
    videos = db.exec(
        query.order_by(Video.created_at.desc()).offset(skip).limit(limit)
    ).all()
    return videos


@router.post("/upload", response_model=VideoResponse)
async def upload_video(
    file: UploadFile = File(...),
    title: str = Query(...),
    description: Optional[str] = Query(None),
    created_by: Optional[str] = Query(None),
    watermark_enabled: bool = Query(True),
    folder: str = Query("General"),
    streaming_mode: str = Query("hls"),
    db: Session = Depends(get_db),
):
    ensure_storage_dirs()
    
    video_id = str(uuid.uuid4())
    ext = os.path.splitext(file.filename)[1]
    
    # Save original video
    originals_dir = Path(settings.VIDEO_STORAGE_PATH) / "originals"
    originals_dir.mkdir(exist_ok=True)
    
    original_path = originals_dir / f"{video_id}{ext}"
    
    with open(original_path, "wb") as buffer:
        buffer.write(await file.read())
        
    video = Video(
        id=video_id,
        title=title,
        description=description,
        original_filename=file.filename,
        original_path=str(original_path),
        watermark_enabled=watermark_enabled,
        created_by=created_by,
        folder=folder,
        streaming_mode=streaming_mode,
        storage_type=settings.VIDEO_STORAGE_TYPE,
        storage_path=settings.VIDEO_STORAGE_PATH,
        status="pending",
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    if settings.MUX_ENABLED:
        import threading
        from app.core.mux import mux_transcode
        threading.Thread(target=mux_transcode, args=(video_id,), daemon=True).start()
    else:
        job = TranscodeJob(
            video_id=video_id,
            status="pending",
            resolutions_requested="360p,480p,720p,1080p",
            priority=0,
        )
        db.add(job)
        db.commit()
    
    return video


@router.post("", response_model=VideoResponse)
def create_video(
    request: VideoCreate,
    db: Session = Depends(get_db),
):
    ensure_storage_dirs()
    video = Video(
        title=request.title,
        description=request.description,
        original_filename=request.original_filename,
        original_path=request.original_path,
        watermark_enabled=request.watermark_enabled,
        watermark_mode=request.watermark_mode,
        watermark_segments=request.watermark_segments,
        watermark_text=request.watermark_text,
        created_by=request.created_by,
        storage_type=settings.VIDEO_STORAGE_TYPE,
        storage_path=settings.VIDEO_STORAGE_PATH,
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    ensure_storage_dirs()

    return video


@router.get("/{video_id}", response_model=VideoDetailResponse)
def get_video(
    video_id: str,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    resolutions = db.exec(
        select(VideoResolution).where(VideoResolution.video_id == video_id)
    ).all()

    return VideoDetailResponse(
        id=video.id,
        title=video.title,
        description=video.description,
        original_filename=video.original_filename,
        original_path=video.original_path,
        duration_seconds=video.duration_seconds,
        width=video.width,
        height=video.height,
        folder=video.folder,
        streaming_mode=video.streaming_mode,
        watermark_enabled=video.watermark_enabled,
        watermark_mode=video.watermark_mode,
        watermark_segments=video.watermark_segments,
        watermark_text=video.watermark_text,
        watermark_color=video.watermark_color,
        watermark_font_size=video.watermark_font_size,
        watermark_opacity=video.watermark_opacity,
        watermark_overlay_count=video.watermark_overlay_count,
        watermark_insert_duration=video.watermark_insert_duration,
        watermark_insert_repeat=video.watermark_insert_repeat,
        watermark_position=video.watermark_position,
        watermark_break_duration=video.watermark_break_duration,
        status=video.status,
        storage_type=video.storage_type,
        storage_path=video.storage_path,
        cdn_url=video.cdn_url,
        created_by=video.created_by,
        created_at=video.created_at,
        updated_at=video.updated_at,
        is_encrypted=video.is_encrypted,
        resolutions=[
            VideoResolutionResponse(
                id=r.id,
                video_id=r.video_id,
                resolution=r.resolution,
                width=r.width,
                height=r.height,
                bitrate=r.bitrate,
                playlist_url=r.playlist_url,
                segments_count=r.segments_count,
                total_size_bytes=r.total_size_bytes,
                status=r.status,
                created_at=r.created_at,
            )
            for r in resolutions
        ],
    )


@router.put("/{video_id}", response_model=VideoResponse)
def update_video(
    video_id: str,
    request: VideoUpdate,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if request.title is not None:
        video.title = request.title
    if request.description is not None:
        video.description = request.description
    if request.folder is not None:
        video.folder = request.folder
    if request.streaming_mode is not None:
        video.streaming_mode = request.streaming_mode
    if request.watermark_enabled is not None:
        video.watermark_enabled = request.watermark_enabled
    if request.watermark_mode is not None:
        video.watermark_mode = request.watermark_mode
    if request.watermark_segments is not None:
        video.watermark_segments = request.watermark_segments
    if request.watermark_text is not None:
        video.watermark_text = request.watermark_text
    if request.watermark_color is not None:
        video.watermark_color = request.watermark_color
    if request.watermark_font_size is not None:
        video.watermark_font_size = request.watermark_font_size
    if request.watermark_opacity is not None:
        video.watermark_opacity = request.watermark_opacity
    if request.watermark_overlay_count is not None:
        video.watermark_overlay_count = request.watermark_overlay_count
    if request.watermark_insert_duration is not None:
        video.watermark_insert_duration = request.watermark_insert_duration
    if request.watermark_insert_repeat is not None:
        video.watermark_insert_repeat = request.watermark_insert_repeat
    if request.watermark_position is not None:
        video.watermark_position = request.watermark_position
    if request.watermark_break_duration is not None:
        video.watermark_break_duration = request.watermark_break_duration
    if request.status is not None:
        video.status = request.status

        if request.status == "ready":
            existing = db.exec(
                select(VideoResolution).where(VideoResolution.video_id == video_id)
            ).first()
            if not existing:
                res = VideoResolution(
                    video_id=video.id,
                    resolution="360p",
                    width=640,
                    height=360,
                    bitrate=800000,
                    segments_count=0,
                    total_size_bytes=0,
                    status="ready",
                )
                db.add(res)

    video.updated_at = datetime.utcnow()
    db.add(video)
    db.commit()
    db.refresh(video)

    return video


@router.delete("/{video_id}")
def delete_video(
    video_id: str,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    resolutions = db.exec(
        select(VideoResolution).where(VideoResolution.video_id == video_id)
    ).all()

    for res in resolutions:
        segments = db.exec(
            select(VideoSegment).where(VideoSegment.resolution_id == res.id)
        ).all()
        for seg in segments:
            if seg.storage_path and os.path.exists(seg.storage_path):
                try:
                    os.remove(seg.storage_path)
                except:
                    pass
            db.delete(seg)
        db.delete(res)

    db.delete(video)
    db.commit()

    return {"message": "Video deleted successfully"}


@router.post("/{video_id}/transcode", response_model=TranscodeJobResponse)
def start_transcode(

    video_id: str,
    resolutions: str = "360p,480p,720p,1080p",
    priority: int = 0,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    # Check if there is already a pending or running job for this video
    existing_job = db.exec(
        select(TranscodeJob).where(
            TranscodeJob.video_id == video_id,
            TranscodeJob.status.in_(["pending", "running"])
        )
    ).first()
    
    if existing_job:
        raise HTTPException(status_code=400, detail="Video already in queue or transcoding")

    job = TranscodeJob(
        video_id=video_id,
        status="pending",
        resolutions_requested=resolutions,
        priority=priority,
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    video.status = "pending" # Waiting for queue
    db.add(video)
    db.commit()

    return job


@router.get("/{video_id}/manifest", response_model=ManifestResponse)
def get_video_manifest(

    video_id: str,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    if video.status != "ready":
        raise HTTPException(status_code=400, detail="Video not ready for streaming")

    resolutions = db.exec(
        select(VideoResolution)
        .where(VideoResolution.video_id == video_id)
        .where(VideoResolution.status == "ready")
    ).all()

    if not resolutions:
        raise HTTPException(status_code=404, detail="No ready resolutions found")

    return ManifestResponse(
        video_id=video_id,
        folder=video.folder,
        streaming_mode=video.streaming_mode,
        watermark_enabled=video.watermark_enabled,
        watermark_mode=video.watermark_mode if video.watermark_enabled else "disabled",
        watermark_color=video.watermark_color,
        watermark_font_size=video.watermark_font_size,
        watermark_opacity=video.watermark_opacity,
        watermark_overlay_count=video.watermark_overlay_count,
        watermark_insert_duration=video.watermark_insert_duration,
        watermark_insert_repeat=video.watermark_insert_repeat,
        watermark_position=video.watermark_position,
        watermark_break_duration=video.watermark_break_duration,
        resolutions=[
            VideoResolutionResponse(
                id=r.id,
                video_id=r.video_id,
                resolution=r.resolution,
                width=r.width,
                height=r.height,
                bitrate=r.bitrate,
                playlist_url=r.playlist_url,
                segments_count=r.segments_count,
                total_size_bytes=r.total_size_bytes,
                status=r.status,
                created_at=r.created_at,
            )
            for r in resolutions
        ],
        default_resolution="720p",
    )


@router.get("/{video_id}/stream")
def get_video_stream(
    video_id: str,
    resolution: str = "720p",
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    if video.streaming_mode == "direct":
        base_url = settings.VIDEO_SERVER_BASE_URL
        return {
            "stream_url": f"{base_url}/internal/videos/{video_id}/raw",
            "resolution": "original",
            "streaming_mode": "direct"
        }

    res = db.exec(
        select(VideoResolution)
        .where(VideoResolution.video_id == video_id)
        .where(VideoResolution.resolution == resolution)
    ).first()

    if not res or res.status != "ready":
        # Fallback to first ready resolution
        res = db.exec(
            select(VideoResolution)
            .where(VideoResolution.video_id == video_id)
            .where(VideoResolution.status == "ready")
        ).first()

    if not res:
        raise HTTPException(status_code=404, detail="No ready resolution found")

    if res.playlist_url:
        return {"stream_url": res.playlist_url, "resolution": res.resolution, "streaming_mode": "hls"}

    base_url = settings.VIDEO_SERVER_BASE_URL
    return {
        "stream_url": f"{base_url}/internal/videos/{video_id}/playlist/{res.resolution}",
        "resolution": res.resolution,
        "streaming_mode": "hls"
    }


@router.get("/{video_id}/raw")
def get_raw_video(
    video_id: str,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    if video.status == "blocked":
        raise HTTPException(status_code=403, detail="Video is blocked")
        
    if not os.path.exists(video.original_path):
        raise HTTPException(status_code=404, detail="Original file not found")
        
    from fastapi.responses import FileResponse
    return FileResponse(video.original_path)


@router.get("/{video_id}/playlist/{resolution}")
def get_playlist(
    video_id: str,
    resolution: str,
    user_email: str = Query(None),
    user_phone: str = Query(None),
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    res = db.exec(
        select(VideoResolution)
        .where(VideoResolution.video_id == video_id)
        .where(VideoResolution.resolution == resolution)
    ).first()

    if not res or res.status != "ready":
        raise HTTPException(status_code=404, detail="Resolution not found")

    segments = db.exec(
        select(VideoSegment)
        .where(VideoSegment.resolution_id == res.id)
        .order_by(VideoSegment.segment_number)
    ).all()

    base_url = settings.VIDEO_SERVER_BASE_URL
    playlist_lines = [
        "#EXTM3U",
        "#EXT-X-VERSION:3",
        "#EXT-X-TARGETDURATION:60",
        f"#EXT-X-MEDIA-SEQUENCE:0",
    ]

    if video.is_encrypted and video.encryption_key_hex and video.encryption_iv_hex:
        key_url = f"{base_url}/internal/videos/{video_id}/key"
        playlist_lines.append(f'#EXT-X-KEY:METHOD=AES-128,URI="{key_url}",IV=0x{video.encryption_iv_hex}')

    import base64
    import random

    user_info = f"{user_email or 'Unknown'}|{user_phone or 'Unknown'}"
    user_info_b64 = base64.b64encode(user_info.encode()).decode()

    # Cache watermark positions with TTL (anti-abuse)
    import json as _json
    pos_cache_key = f"{video.id}-{user_email or 'anon'}-{res.id}"
    pos_entry = cache_get_or_compute(
        db, pos_cache_key, "watermark_position",
        settings.WATERMARK_POSITION_CACHE_TTL,
        lambda: _compute_watermark_positions(video, segments, user_email),
    )
    mark_indices = set(_json.loads(pos_entry.data))

    if settings.VIDEO_SERVER_DEBUG:
        cum_time = 0.0
        mark_entries = []
        mode = video.watermark_mode
        for i, seg in enumerate(segments):
            if i in mark_indices and video.watermark_enabled:
                if mode == "insert":
                    dur = video.watermark_break_duration * video.watermark_insert_repeat
                    mark_entries.append(f"insert:{cum_time:.3f}+{dur:.3f}s")
                else:
                    end = cum_time + seg.duration_seconds
                    mark_entries.append(f"overlay:{cum_time:.3f}-{end:.3f}")
            cum_time += seg.duration_seconds
        playlist_lines.append(f"# Watermarked segments: {','.join(mark_entries)}")

    # Enqueue overlay pre-generation jobs (priority by watermark index)
    if video.watermark_enabled and video.watermark_mode == "overlay" and mark_indices:
        queue = get_overlay_queue()
        wm_config = {
            "watermark_overlay_count": video.watermark_overlay_count,
            "watermark_color": video.watermark_color,
            "watermark_font_size": video.watermark_font_size,
            "watermark_opacity": video.watermark_opacity,
        }
        sorted_marks = sorted(mark_indices)
        for wm_idx, seg_idx in enumerate(sorted_marks):
            seg = segments[seg_idx]
            job = OverlayJob(
                video_id=video.id,
                seg=seg,
                res=res,
                user_info=user_info,
                user_info_b64=user_info_b64,
                wm_index=wm_idx,
                wm_config=wm_config,
                encryption_key_hex=video.encryption_key_hex,
                encryption_iv_hex=video.encryption_iv_hex,
            )
            queue.enqueue(job)

    prev_was_watermark = False
    for i, seg in enumerate(segments):
        is_marked = i in mark_indices and video.watermark_enabled

        if is_marked and video.watermark_mode == "insert":
            if i > 0:
                playlist_lines.append("#EXT-X-DISCONTINUITY")
            for _ in range(video.watermark_insert_repeat):
                playlist_lines.append(f"#EXTINF:{video.watermark_break_duration:.3f},")
                playlist_lines.append(
                    f"{base_url}/internal/videos/watermark/{res.id}/{user_info_b64}.ts"
                )
            prev_was_watermark = True

        if prev_was_watermark:
            playlist_lines.append("#EXT-X-DISCONTINUITY")
            prev_was_watermark = False

        if is_marked and video.watermark_mode == "overlay":
            playlist_lines.append("#EXT-X-DISCONTINUITY")
            playlist_lines.append(f"#EXTINF:{seg.duration_seconds:.3f},")
            playlist_lines.append(
                f"{base_url}/internal/videos/{video_id}/overlay/{seg.segment_hash}/{user_info_b64}.ts"
            )
        else:
            playlist_lines.append(f"#EXTINF:{seg.duration_seconds:.3f},")
            playlist_lines.append(
                f"{base_url}/internal/videos/{video_id}/segment/{seg.segment_hash}"
            )

    playlist_lines.append("#EXT-X-ENDLIST")

    from fastapi.responses import PlainTextResponse

    return PlainTextResponse(
        content="\n".join(playlist_lines), media_type="application/vnd.apple.mpegurl"
    )


@router.get("/{video_id}/overlay/{segment_hash}/{info_b64}.ts")
def get_overlay_segment(
    video_id: str,
    segment_hash: str,
    info_b64: str,
    db: Session = Depends(get_db),
):
    import base64

    try:
        user_info = base64.b64decode(info_b64).decode()
    except:
        user_info = "Unknown"

    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    seg = db.exec(
        select(VideoSegment).where(VideoSegment.segment_hash == segment_hash)
    ).first()

    if not seg:
        raise HTTPException(status_code=404, detail="Segment not found")

    res = db.get(VideoResolution, seg.resolution_id)

    cache_key = f"overlay_{segment_hash}_{info_b64}"
    cached = cache_get(db, cache_key, "overlay")
    if cached and cached.file_path and os.path.exists(cached.file_path):
        from fastapi.responses import FileResponse
        return FileResponse(cached.file_path, media_type="video/mp2t")

    temp_dir = Path(settings.CACHE_STORAGE_PATH) / "overlays"
    temp_dir.mkdir(parents=True, exist_ok=True)

    file_hash = hashlib.md5(cache_key.encode()).hexdigest()
    overlay_file = temp_dir / f"{file_hash}.ts"

    if not overlay_file.exists():
        import random
        rng = random.Random(segment_hash + info_b64)
        count = max(1, video.watermark_overlay_count)
        color = video.watermark_color.lstrip("#")
        fontsize = video.watermark_font_size
        opacity = video.watermark_opacity

        drawtexts = []
        for _ in range(count):
            x = rng.randint(10, max(10, res.width - 200))
            y = rng.randint(10, max(10, res.height - 50))
            drawtexts.append(
                f"drawtext=text='{user_info}':fontsize={fontsize}:"
                f"fontcolor={color}@{opacity}:x={x}:y={y}"
            )
        vf = ",".join(drawtexts)

        cmd = [
            "ffmpeg",
            "-i", seg.storage_path,
            "-fflags", "+genpts",
            "-vf", vf,
            "-map", "0:v:0",
            "-map", "0:a:0",
            "-c:v", "libx264",
            "-c:a", "copy",
            str(overlay_file),
            "-y",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Overlay ffmpeg error: {result.stderr[-500:]}")

    # Re-encrypt if the video uses encryption
    if video and video.is_encrypted and video.encryption_key_hex and video.encryption_iv_hex:
        from app.core.encryption import encrypt_file_inplace
        encrypt_file_inplace(str(overlay_file), video.encryption_key_hex, video.encryption_iv_hex)

    ttl = settings.WATERMARK_INSERT_CACHE_TTL
    cache_set(db, cache_key, "overlay", ttl, file_path=str(overlay_file))

    from fastapi.responses import FileResponse
    return FileResponse(str(overlay_file), media_type="video/mp2t")


@router.get("/watermark/{resolution_id}/{info_b64}.ts")
def get_dynamic_watermark_segment(
    resolution_id: str,
    info_b64: str,
    db: Session = Depends(get_db),
):
    import base64
    import shutil

    try:
        user_info = base64.b64decode(info_b64).decode()
    except:
        user_info = "Unknown"

    res = db.get(VideoResolution, resolution_id)
    if not res:
        raise HTTPException(status_code=404, detail="Resolution not found")

    video = db.get(Video, res.video_id)
    break_dur = video.watermark_break_duration if video else settings.WATERMARK_BREAK_DURATION

    user_name = user_info.split("|")[0] if "|" in user_info else user_info
    cache_key = f"break_{resolution_id}_{info_b64}_{break_dur}"

    cached = cache_get(db, cache_key, "break_screen")
    if cached and cached.file_path and os.path.exists(cached.file_path):
        from fastapi.responses import FileResponse
        return FileResponse(cached.file_path, media_type="video/mp2t")

    file_hash = hashlib.md5(cache_key.encode()).hexdigest()
    break_dir = Path(settings.CACHE_STORAGE_PATH) / "break_screens"
    break_dir.mkdir(parents=True, exist_ok=True)
    break_file = break_dir / f"{file_hash}.ts"

    if not break_file.exists():
        has_espeak = shutil.which("espeak") is not None

        tts_wav = None
        if has_espeak:
            tts_wav = break_dir / f"{file_hash}_tts.wav"
            if not tts_wav.exists():
                if break_dur < 60:
                    tts_text = f"{user_name}, please take a {break_dur} second break"
                elif break_dur == 60:
                    tts_text = f"{user_name}, please take a one minute break"
                else:
                    tts_text = f"{user_name}, please take a break"
                subprocess.run(
                    ["espeak", tts_text, "-w", str(tts_wav)],
                    capture_output=True
                )

        if break_dur < 60:
            title_text = f"{user_name}, take a {break_dur}-Second Break"
        elif break_dur == 60:
            title_text = f"{user_name}, take a 1-Minute Break"
        else:
            title_text = f"{user_name}, take a Break"
        subtitle = "Please relax and rest your eyes"
        countdown_expr = f"%{{eif\\:{break_dur}-t\\:d}}"

        vf = (
            f"drawtext=text='{title_text}':fontsize=48:fontcolor=white:"
            f"x=(w-text_w)/2:y=h/2-100,"
            f"drawtext=text='{subtitle}':fontsize=24:fontcolor=lightgray:"
            f"x=(w-text_w)/2:y=h/2-40,"
            f"drawtext=text='{countdown_expr}':fontsize=120:fontcolor=yellow:"
            f"x=(w-text_w)/2:y=h/2+80"
        )

        cmd = [
            "ffmpeg", "-y",
            "-f", "lavfi",
            "-i", f"color=c=darkblue:s={res.width}x{res.height}:d={break_dur}",
            "-vf", vf,
            "-c:v", "libx264", "-preset", "fast", "-crf", "23",
            "-pix_fmt", "yuv420p",
            "-f", "mpegts",
        ]

        if tts_wav and tts_wav.exists():
            cmd.extend(["-i", str(tts_wav)])
            cmd.extend(["-c:a", "aac", "-b:a", "128k", "-shortest"])

        cmd.append(str(break_file))
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0 or not break_file.exists():
            print(f"Break screen ffmpeg error: {result.stderr[-300:]}")
            fallback = break_dir / f"fallback_{res.width}x{res.height}.ts"
            if not fallback.exists():
                subprocess.run([
                    "ffmpeg", "-y",
                    "-f", "lavfi",
                    "-i", f"color=c=darkblue:s={res.width}x{res.height}:d=5",
                    "-c:v", "libx264", "-preset", "ultrafast", "-crf", "28",
                    "-pix_fmt", "yuv420p",
                    "-f", "mpegts",
                    str(fallback),
                ], capture_output=True)
            if fallback.exists():
                import shutil as _su
                _su.copy(fallback, break_file)

    # Re-encrypt break screen if video is encrypted
    if video and video.is_encrypted and video.encryption_key_hex and video.encryption_iv_hex:
        from app.core.encryption import encrypt_file_inplace
        encrypt_file_inplace(str(break_file), video.encryption_key_hex, video.encryption_iv_hex)

    cache_set(db, cache_key, "break_screen", settings.WATERMARK_INSERT_CACHE_TTL, file_path=str(break_file))

    from fastapi.responses import FileResponse
    return FileResponse(str(break_file), media_type="video/mp2t")


@router.get("/{video_id}/key")
def get_encryption_key(video_id: str, db: Session = Depends(get_db)):
    video = db.get(Video, video_id)
    if not video or not video.encryption_key_hex:
        raise HTTPException(status_code=404, detail="Encryption key not found")
    from fastapi.responses import Response
    key = bytes.fromhex(video.encryption_key_hex)
    return Response(content=key, media_type="application/octet-stream",
                    headers={"Content-Type": "application/octet-stream"})


@router.get("/{video_id}/segment/{segment_hash}")
def get_segment(
    video_id: str,
    segment_hash: str,
    db: Session = Depends(get_db),
):
    seg = db.exec(
        select(VideoSegment).where(VideoSegment.segment_hash == segment_hash)
    ).first()

    if not seg:
        raise HTTPException(status_code=404, detail="Segment not found")

    seg_path = seg.storage_path
    if not seg_path or not os.path.exists(seg_path):
        raise HTTPException(status_code=404, detail="Segment file not found")

    video = db.get(Video, video_id)
    if video and video.is_encrypted:
        enc_path = seg_path + ".enc"
        if os.path.exists(enc_path):
            seg_path = enc_path

    from fastapi.responses import FileResponse

    return FileResponse(
        seg_path,
        media_type="video/mp2t",
        headers={"Content-Disposition": f"inline; filename={seg.filename}"},
    )


@router.get("/{video_id}/status")
def get_video_status(
    video_id: str,
    db: Session = Depends(get_db),
):
    video = db.get(Video, video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Video not found"
        )

    if video.status == "blocked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Video is blocked"
        )

    resolutions = db.exec(
        select(VideoResolution).where(VideoResolution.video_id == video_id)
    ).all()

    return {
        "video_id": video_id,
        "status": video.status,
        "resolutions": [
            {
                "resolution": r.resolution,
                "status": r.status,
                "progress": r.segments_count,
            }
            for r in resolutions
        ],
    }
