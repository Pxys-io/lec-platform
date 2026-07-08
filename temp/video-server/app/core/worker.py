import os
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from sqlmodel import Session, select

from app.core.database import engine, SessionLocal
from app.models.video import Video, VideoResolution, VideoSegment, TranscodeJob
from app.core.config import settings
import hashlib


class TranscodeWorker:
    def __init__(self):
        self.current_job_id: Optional[str] = None
        self.current_process: Optional[subprocess.Popen] = None
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None

    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop_event.set()
        if self.current_process:
            self.current_process.terminate()

    def kill_job(self, job_id: str):
        if self.current_job_id == job_id and self.current_process:
            self.current_process.terminate()
            return True
        return False

    def _run_loop(self):
        while not self._stop_event.is_set():
            try:
                self._process_next_job()
            except Exception as e:
                print(f"Worker error: {e}")
            time.sleep(5)

    def _process_next_job(self):
        with SessionLocal() as db:
            # Find next job: pending, ordered by priority desc, created_at asc
            statement = select(TranscodeJob).where(
                TranscodeJob.status == "pending"
            ).order_by(
                TranscodeJob.priority.desc(),
                TranscodeJob.created_at.asc()
            )
            job = db.exec(statement).first()

            if not job:
                return

            self.current_job_id = job.id
            job.status = "running"
            job.started_at = datetime.utcnow()
            db.add(job)
            db.commit()
            db.refresh(job)

            video = db.get(Video, job.video_id)
            if not video:
                job.status = "error"
                job.error_message = "Video not found"
                db.add(job)
                db.commit()
                return

            video.status = "transcoding"
            db.add(video)
            db.commit()

            success = self._run_transcode_job(video, job.resolutions_requested, job, db)

            if success:
                video.status = "ready"
                job.status = "completed"
                job.completed_at = datetime.utcnow()
            else:
                # If cancelled or failed
                if job.status == "cancelled":
                    video.status = "pending"
                else:
                    job.status = "pending"  # Re-queue
                    job.fail_count += 1
                    job.error_message = "Transcoding failed or was interrupted"
                    video.status = "error"
                
                # If fail count too high, mark as error permanently? 
                # User said "gets throw to the end of the queu to be retried"
                # To move to end of queue, we could update created_at or just use status.
                # Actually, status="pending" and current logic picks by created_at.
                # If we want to move it to the end, we should update its created_at to now.
                job.created_at = datetime.utcnow()

            db.add(video)
            db.add(job)
            db.commit()
            self.current_job_id = None
            self.current_process = None

    def _run_transcode_job(self, video, resolutions_str, job, db):
        if video.streaming_mode == "direct":
            # Just verify original file exists and maybe get metadata
            if not os.path.exists(video.original_path):
                job.error_message = "Original file not found"
                return False
            
            # Optionally: we could use ffprobe to update video metadata
            try:
                cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,duration,codec_name", "-of", "json", video.original_path]
                import json
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    data = json.loads(result.stdout)
                    if "streams" in data and len(data["streams"]) > 0:
                        stream = data["streams"][0]
                        video.width = stream.get("width")
                        video.height = stream.get("height")
                        video.duration_seconds = float(stream.get("duration", 0))
                        video.codec = stream.get("codec_name")
            except:
                pass
                
            return True

        resolution_configs = {
            "360p": {"width": 640, "height": 360, "bitrate": "800k"},
            "480p": {"width": 854, "height": 480, "bitrate": "1200k"},
            "720p": {"width": 1280, "height": 720, "bitrate": "2500k"},
            "1080p": {"width": 1920, "height": 1080, "bitrate": "5000k"},
        }

        storage_base = Path(video.storage_path) / video.id
        storage_base.mkdir(parents=True, exist_ok=True)

        resolutions = [r.strip() for r in resolutions_str.split(",") if r.strip()]
        total_resolutions = len(resolutions)

        completed_resolutions = []

        for idx, res_name in enumerate(resolutions):
            if self._stop_event.is_set():
                job.status = "cancelled"
                return False

            config = resolution_configs.get(res_name)
            if not config:
                continue

            res_path = storage_base / res_name
            res_path.mkdir(exist_ok=True)

            # Transcode to HLS
            cmd = [
                "ffmpeg",
                "-i", video.original_path,
                "-fflags", "+genpts",
                "-vf", f"scale={config['width']}:{config['height']},setpts=PTS-STARTPTS",
                "-af", "asetpts=PTS-STARTPTS",
                "-force_key_frames", "expr:gte(t,n_forced*60)",
                "-c:v", "libx264",
                "-profile:v", "high",
                "-pix_fmt", "yuv420p",
                "-b:v", config["bitrate"],
                "-c:a", "aac",
                "-hls_time", "60",
                "-hls_list_size", "0",
                "-hls_segment_filename", f"{res_path}/segment_%03d.ts",
                f"{res_path}/playlist.m3u8",
                "-y",
            ]
            
            self.current_process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            stdout, stderr = self.current_process.communicate()
            
            if self.current_process.returncode != 0:
                print(f"FFmpeg error for {res_name}: {stderr}")
                if self.current_process.returncode == -15: # Terminated
                    job.status = "cancelled"
                return False

            # Create DB records for resolution and segments
            segments = sorted(res_path.glob("segment_*.ts"))
            res_record = VideoResolution(
                video_id=video.id,
                resolution=res_name,
                width=config["width"],
                height=config["height"],
                bitrate=int(config["bitrate"].replace("k", "000")),
                segments_count=len(segments),
                total_size_bytes=sum(s.stat().st_size for s in segments),
                status="ready",
            )
            db.add(res_record)
            db.commit()
            db.refresh(res_record)

            for i, seg_file in enumerate(segments):
                # Simple duration estimation if ffprobe fails
                seg_duration = 60.0 # Default based on hls_time
                
                seg = VideoSegment(
                    video_id=video.id,
                    resolution_id=res_record.id,
                    segment_number=i,
                    segment_hash=self._compute_segment_hash(video.id, i, res_name),
                    filename=seg_file.name,
                    duration_seconds=seg_duration,
                    byte_size=seg_file.stat().st_size,
                    storage_path=str(seg_file),
                )
                db.add(seg)
            
            completed_resolutions.append(res_name)
            job.resolutions_completed = ",".join(completed_resolutions)
            job.progress = ((idx + 1) / total_resolutions) * 100
            db.add(job)
            db.commit()

        return True

    def _compute_segment_hash(self, video_id: str, segment_num: int, resolution: str) -> str:
        data = f"{video_id}-{segment_num}-{resolution}-{datetime.utcnow().isoformat()}"
        return hashlib.sha256(data.encode()).hexdigest()[:12]


worker = TranscodeWorker()
