#!/usr/bin/env python3
"""Test version of seed_videos.py for worktree testing."""

import json, uuid, hashlib, shutil, subprocess, sys, os
from datetime import datetime
from pathlib import Path

import httpx
from sqlmodel import Session, select

# Use worktree path
sys.path.insert(0, str(Path(__file__).parent / "video-server-wt"))
from app.core.database import engine
from app.models.video import Video, VideoResolution, VideoSegment

# Use test port
VIDEO_SERVER_PORT = os.getenv("VIDEO_SERVER_PORT", "9001")
VIDEO_SERVER_URL = f"http://localhost:{VIDEO_SERVER_PORT}"
SAMPLE_VIDEO = str(Path(__file__).parent / "video-server-wt" / "test_videos" / "sample.mp4")
VIDEO_STORAGE_PATH = str(Path(__file__).parent / "video-server-wt" / "storage" / "videos")


def _id():
    return str(uuid.uuid4())


def _hash(video_id: str, segment_num: int, resolution: str) -> str:
    data = f"{video_id}-{segment_num}-{resolution}-{datetime.utcnow().isoformat()}"
    return hashlib.sha256(data.encode()).hexdigest()[:12]


def pre_transcode(template_dir: Path) -> bool:
    """Transcode sample.mp4 ONCE to 360p HLS segments."""
    template_dir.mkdir(parents=True, exist_ok=True)

    print(f"\n⚡ Pre-transcoding sample.mp4 → 360p HLS (one time only)...")

    cmd = [
        "ffmpeg",
        "-i", SAMPLE_VIDEO,
        "-fflags", "+genpts",
        "-vf", "scale=640:360,setpts=PTS-STARTPTS",
        "-af", "asetpts=PTS-STARTPTS",
        "-force_key_frames", "expr:gte(t,n_forced*60)",
        "-c:v", "libx264",
        "-profile:v", "high",
        "-pix_fmt", "yuv420p",
        "-b:v", "800k",
        "-c:a", "aac",
        "-hls_time", "60",
        "-hls_list_size", "0",
        "-hls_segment_filename", f"{template_dir}/segment_%03d.ts",
        f"{template_dir}/playlist.m3u8",
        "-y",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  ❌ FFmpeg error: {result.stderr[-500:]}")
        return False

    segments = sorted(template_dir.glob("segment_*.ts"))
    total_dur = sum(get_segment_duration(s) for s in segments)
    print(f"  ✅ Pre-transcode complete ({len(segments)} segments, {total_dur:.0f}s total)")
    return True


def get_segment_duration(seg_path: Path) -> float:
    """Probe a .ts file for its duration."""
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(seg_path)],
        capture_output=True, text=True,
    )
    try:
        return float(result.stdout.strip())
    except (ValueError, AttributeError):
        return 60.0


def create_video_records(video_id: str, template_dir: Path) -> list[str]:
    """Copy pre-transcoded segments for a video and create DB records.

    Returns list of segment files copied.
    """
    video_dir = Path(VIDEO_STORAGE_PATH) / video_id / "360p"
    video_dir.mkdir(parents=True, exist_ok=True)

    template_segments = sorted(template_dir.glob("segment_*.ts"))
    segment_paths = []

    for seg in template_segments:
        dest = video_dir / seg.name
        shutil.copy2(seg, dest)
        segment_paths.append(dest)

    # Copy playlist too
    shutil.copy2(template_dir / "playlist.m3u8", video_dir / "playlist.m3u8")

    # Create DB records
    with Session(engine) as session:
        # Update video status
        video = session.get(Video, video_id)
        if video:
            video.status = "ready"
            video.duration_seconds = float(len(template_segments) * 60)
            session.add(video)

        # Create VideoResolution
        res = VideoResolution(
            video_id=video_id,
            resolution="360p",
            width=640,
            height=360,
            bitrate=800000,
            segments_count=len(template_segments),
            total_size_bytes=sum(s.stat().st_size for s in segment_paths),
            status="ready",
        )
        session.add(res)
        session.flush()

        # Create VideoSegments
        for i, seg_path in enumerate(segment_paths):
            dur = get_segment_duration(seg_path)
            seg = VideoSegment(
                video_id=video_id,
                resolution_id=res.id,
                segment_number=i,
                segment_hash=_hash(video_id, i, "360p"),
                filename=seg_path.name,
                duration_seconds=dur,
                byte_size=seg_path.stat().st_size,
                storage_path=str(seg_path),
            )
            session.add(seg)

        session.commit()

    return [str(p) for p in segment_paths]


def seed_videos():
    configs = [
        {"title": "Test Video 1 — No Watermark", "enabled": False, "mode": "overlay", "segments": 0, "text": ""},
        {"title": "Test Video 2 — Insert Watermark", "enabled": True, "mode": "insert", "segments": 3, "text": ""},
        {"title": "Test Video 3 — Overlay Watermark", "enabled": True, "mode": "overlay", "segments": 3, "text": "LEC-{user}"},
        {"title": "Test Video 4 — No Watermark", "enabled": False, "mode": "overlay", "segments": 0, "text": ""},
        {"title": "Test Video 5 — Insert Watermark", "enabled": True, "mode": "insert", "segments": 3, "text": ""},
        {"title": "Test Video 6 — Overlay Watermark", "enabled": True, "mode": "overlay", "segments": 3, "text": "LEC-{user}"},
    ]

    # Clean stale video directories (keep template)
    storage = Path(VIDEO_STORAGE_PATH)
    if storage.exists():
        for d in storage.iterdir():
            if d.is_dir() and d.name != "_template_360p":
                shutil.rmtree(d, ignore_errors=True)

    # Step 1: Pre-transcode once
    template_dir = Path(VIDEO_STORAGE_PATH) / "_template_360p"
    if not (template_dir / "playlist.m3u8").exists():
        if not pre_transcode(template_dir):
            print("❌ Pre-transcode failed, aborting")
            return
    else:
        template_segments = sorted(template_dir.glob("segment_*.ts"))
        print(f"♻️  Using cached pre-transcode ({len(template_segments)} segments)")

    # Step 2: Create each video and copy segments
    video_ids = []
    print("\n🎬 Seeding videos (copying pre-transcoded segments)...")

    for cfg in configs:
        print(f"  Creating {cfg['title']}...")

        try:
            resp = httpx.post(
                f"{VIDEO_SERVER_URL}/api/v1/internal/videos",
                json={
                    "title": cfg["title"],
                    "description": f"Test video with {cfg['mode'] or 'no'} watermarking",
                    "original_filename": "sample.mp4",
                    "original_path": SAMPLE_VIDEO,
                    "watermark_enabled": cfg["enabled"],
                    "watermark_mode": cfg["mode"],
                    "watermark_segments": cfg["segments"],
                    "watermark_text": cfg["text"] if cfg["mode"] == "overlay" else "",
                    "created_by": "seed",
                },
            )
            if resp.status_code != 200:
                print(f"    ❌ API failed ({resp.status_code}): {resp.text[:200]}")
                continue
            video_id = resp.json()["id"]
            video_ids.append(video_id)

            # Copy pre-transcoded segments and create DB records
            segments = create_video_records(video_id, template_dir)
            print(f"    ✅ Ready — {len(segments)} segments copied")

        except Exception as e:
            print(f"    ❌ Error: {e}")
            continue

    # Write IDs to file for main-server-wt/seed_data.py
    video_ids_file = Path(__file__).parent / "test_video_ids.json"
    with open(video_ids_file, "w") as f:
        json.dump(video_ids, f)
    print(f"\n✅ {len(video_ids)} videos seeded from pre-transcoded template")
    print(f"✅ Video IDs saved to {video_ids_file}")


if __name__ == "__main__":
    seed_videos()
