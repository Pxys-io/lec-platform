import base64
import json
import os
import re
import time
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin

import httpx

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.encryption import generate_encryption_keypair, encrypt_segment_file
from app.models.video import Video, VideoResolution, VideoSegment


MUX_API_BASE = "https://api.mux.com"


def _auth_header() -> dict:
    raw = f"{settings.MUX_TOKEN_ID}:{settings.MUX_TOKEN_SECRET}"
    encoded = base64.b64encode(raw.encode()).decode()
    return {"Authorization": f"Basic {encoded}"}


def _create_direct_upload(original_filename: str, video_id: str) -> dict:
    url = f"{MUX_API_BASE}/video/v1/uploads"
    headers = _auth_header()
    headers["Content-Type"] = "application/json"

    payload = {
        "cors_origin": "*",
        "timeout": 3600,
        "new_asset_settings": {
            "playback_policies": [settings.MUX_PLAYBACK_POLICY],
            "video_quality": settings.MUX_VIDEO_QUALITY,
            "max_resolution_tier": settings.MUX_MAX_RESOLUTION_TIER,
            "passthrough": video_id,
        },
    }

    resp = httpx.post(url, json=payload, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()["data"]


def _upload_file_to_mux(upload_url: str, file_path: str):
    with open(file_path, "rb") as f:
        resp = httpx.put(upload_url, content=f, timeout=7200)
    resp.raise_for_status()


def _get_upload_status(upload_id: str) -> dict:
    url = f"{MUX_API_BASE}/video/v1/uploads/{upload_id}"
    resp = httpx.get(url, headers=_auth_header(), timeout=30)
    resp.raise_for_status()
    return resp.json()["data"]


def _get_asset(asset_id: str) -> dict:
    url = f"{MUX_API_BASE}/video/v1/assets/{asset_id}"
    resp = httpx.get(url, headers=_auth_header(), timeout=30)
    resp.raise_for_status()
    return resp.json()["data"]


def _wait_for_asset(asset_id: str, poll_interval: int = 5, max_attempts: int = 600) -> dict:
    for _ in range(max_attempts):
        asset = _get_asset(asset_id)
        if asset["status"] == "ready":
            return asset
        if asset["status"] == "errored":
            errors = asset.get("errors", {})
            raise RuntimeError(f"MUX asset transcoding failed: {errors}")
        time.sleep(poll_interval)
    raise TimeoutError("MUX asset transcoding did not complete in time")


def _download_m3u8(url: str) -> str:
    resp = httpx.get(url, timeout=60)
    resp.raise_for_status()
    return resp.text


def _download_file(url: str, dest: Path):
    with httpx.stream("GET", url, timeout=120) as resp:
        resp.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in resp.iter_bytes(chunk_size=8192):
                f.write(chunk)


RESOLUTION_PATTERNS = {
    "2160p": (3840, 2160, "16000k"),
    "1440p": (2560, 1440, "8000k"),
    "1080p": (1920, 1080, "5000k"),
    "720p": (1280, 720, "2500k"),
    "480p": (854, 480, "1200k"),
    "360p": (640, 360, "800k"),
    "270p": (480, 270, "400k"),
}


def _parse_resolution_name(width: int, height: int) -> Optional[str]:
    for name, (w, h, _) in RESOLUTION_PATTERNS.items():
        if width == w and height == h:
            return name
    closest = min(RESOLUTION_PATTERNS.items(), key=lambda x: abs(x[1][0] - width) + abs(x[1][1] - height))
    return closest[0]


def _parse_master_playlist(content: str, base_url: str) -> list[dict]:
    variants = []
    lines = content.strip().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("#EXT-X-STREAM-INF:"):
            attrs = {}
            for match in re.finditer(r'(\w+)=("[^"]*"|[^,]+)', line[len("#EXT-X-STREAM-INF:"):].strip()):
                key = match.group(1)
                val = match.group(2).strip('"')
                attrs[key] = val
            i += 1
            if i < len(lines):
                uri = lines[i].strip()
                full_url = urljoin(base_url, uri) if not uri.startswith("http") else uri
                resolution = attrs.get("RESOLUTION", "")
                width, height = 0, 0
                if "x" in resolution:
                    parts = resolution.split("x")
                    width = int(parts[0])
                    height = int(parts[1])
                bandwidth = int(attrs.get("BANDWIDTH", 0))
                res_name = _parse_resolution_name(width, height) if width and height else ""
                variants.append({
                    "uri": full_url,
                    "width": width,
                    "height": height,
                    "bitrate": bandwidth,
                    "resolution": res_name,
                    "codecs": attrs.get("CODECS", ""),
                })
        i += 1
    return variants


def _parse_variant_playlist(content: str, base_url: str) -> list[dict]:
    segments = []
    lines = content.strip().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("#EXTINF:"):
            dur_match = re.match(r"#EXTINF:\s*([\d.]+)", line)
            duration = float(dur_match.group(1)) if dur_match else 60.0
            i += 1
            if i < len(lines):
                seg_uri = lines[i].strip()
                seg_url = urljoin(base_url, seg_uri) if not seg_uri.startswith("http") else seg_uri
                segments.append({"uri": seg_url, "duration": duration, "filename": os.path.basename(seg_uri)})
        i += 1
    return segments


def _compute_segment_hash(video_id: str, segment_num: int, resolution: str) -> str:
    data = f"{video_id}-{segment_num}-{resolution}-{datetime.utcnow().isoformat()}"
    return hashlib.sha256(data.encode()).hexdigest()[:12]


def create_direct_upload_url(original_filename: str, passthrough: str = "") -> tuple[str, str]:
    data = _create_direct_upload(original_filename, passthrough)
    return data["url"], data["id"]


def get_mux_upload_status(mux_upload_id: str) -> dict:
    return _get_upload_status(mux_upload_id)


def _delete_mux_asset(asset_id: str):
    try:
        url = f"{MUX_API_BASE}/video/v1/assets/{asset_id}"
        httpx.delete(url, headers=_auth_header(), timeout=30)
    except Exception:
        pass


def _delete_mux_upload(upload_id: str):
    try:
        url = f"{MUX_API_BASE}/video/v1/uploads/{upload_id}/cancel"
        httpx.put(url, headers=_auth_header(), timeout=30)
    except Exception:
        pass


def mux_transcode(video_id: str):
    db = SessionLocal()
    try:
        video = db.get(Video, video_id)
        if not video:
            return

        video.status = "transcoding"
        video.transcode_method = "mux"
        db.add(video)
        db.commit()

        upload_data = _create_direct_upload(video.original_filename, video.id)
        upload_url = upload_data["url"]
        mux_upload_id = upload_data["id"]

        _upload_file_to_mux(upload_url, video.original_path)

        for attempt in range(600):
            status = _get_upload_status(mux_upload_id)
            if status["status"] == "asset_created":
                asset_id = status["asset_id"]
                break
            if status["status"] in ("errored", "cancelled", "timed_out"):
                video.status = "error"
                db.add(video)
                db.commit()
                return
            time.sleep(3)
        else:
            video.status = "error"
            db.add(video)
            db.commit()
            return

        asset = _wait_for_asset(asset_id)

        playback_ids = asset.get("playback_ids", [])
        if not playback_ids:
            video.status = "error"
            db.add(video)
            db.commit()
            return

        playback_id = playback_ids[0]["id"]
        video.mux_asset_id = asset_id
        video.mux_playback_id = playback_id
        db.add(video)
        db.commit()

        master_url = f"https://stream.mux.com/{playback_id}.m3u8"
        master_content = _download_m3u8(master_url)
        variants = _parse_master_playlist(master_content, f"https://stream.mux.com/")

        if not variants:
            video.status = "error"
            db.add(video)
            db.commit()
            return

        video.width = variants[0]["width"]
        video.height = variants[0]["height"]
        duration = asset.get("duration", 0)
        if duration:
            video.duration_seconds = float(duration)

        storage_base = Path(video.storage_path) / video.id
        storage_base.mkdir(parents=True, exist_ok=True)

        completed_resolutions = []

        for variant in variants:
            res_name = variant["resolution"]
            if not res_name:
                continue

            width = variant["width"]
            height = variant["height"]
            bitrate = variant["bitrate"]

            variant_content = _download_m3u8(variant["uri"])
            segment_entries = _parse_variant_playlist(variant_content, f"https://stream.mux.com/")

            res_path = storage_base / res_name
            res_path.mkdir(exist_ok=True)

            res_record = VideoResolution(
                video_id=video.id,
                resolution=res_name,
                width=width,
                height=height,
                bitrate=bitrate,
                segments_count=len(segment_entries),
                total_size_bytes=0,
                status="ready",
            )
            db.add(res_record)
            db.commit()
            db.refresh(res_record)

            total_bytes = 0
            for i, seg_entry in enumerate(segment_entries):
                seg_filename = seg_entry.get("filename", f"segment_{i:03d}.ts")
                seg_path = res_path / seg_filename

                try:
                    _download_file(seg_entry["uri"], seg_path)
                except Exception as e:
                    continue

                byte_size = seg_path.stat().st_size
                total_bytes += byte_size

                seg = VideoSegment(
                    video_id=video.id,
                    resolution_id=res_record.id,
                    segment_number=i,
                    segment_hash=_compute_segment_hash(video.id, i, res_name),
                    filename=seg_filename,
                    duration_seconds=seg_entry["duration"],
                    byte_size=byte_size,
                    storage_path=str(seg_path),
                )
                db.add(seg)

            res_record.total_size_bytes = total_bytes
            db.add(res_record)
            completed_resolutions.append(res_name)
            db.commit()

        video.storage_path = str(storage_base)

        if settings.VIDEO_ENCRYPTION_ENABLED and not video.is_encrypted:
            from sqlmodel import select
            key_hex, iv_hex = generate_encryption_keypair()
            all_segs = db.exec(
                select(VideoSegment)
                .where(VideoSegment.video_id == video.id)
                .order_by(VideoSegment.segment_number)
            ).all()
            ok = True
            for seg in all_segs:
                enc_path = seg.storage_path + ".enc"
                if not encrypt_segment_file(seg.storage_path, enc_path, key_hex, iv_hex):
                    ok = False
                    break
            if ok:
                video.encryption_key_hex = key_hex
                video.encryption_iv_hex = iv_hex
                video.is_encrypted = True

        video.status = "ready"
        video.cdn_url = master_url
        db.add(video)
        db.commit()

        _delete_mux_asset(asset_id)
        _delete_mux_upload(mux_upload_id)
    except Exception as e:
        video = db.get(Video, video_id)
        if video:
            video.status = "error"
            db.add(video)
            db.commit()
    finally:
        db.close()
