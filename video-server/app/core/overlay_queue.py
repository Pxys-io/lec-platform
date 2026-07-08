import hashlib
import subprocess
import threading
import random
from pathlib import Path
from queue import PriorityQueue
from app.core.config import settings

_overlay_queue = None
_queue_lock = threading.Lock()


class OverlayJob:
    def __init__(self, video_id, seg, res, user_info, user_info_b64, wm_index, wm_config,
                 encryption_key_hex=None, encryption_iv_hex=None):
        self.video_id = video_id
        self.seg = seg
        self.res = res
        self.user_info = user_info
        self.user_info_b64 = user_info_b64
        self.wm_index = wm_index
        self.wm_config = wm_config
        self.encryption_key_hex = encryption_key_hex
        self.encryption_iv_hex = encryption_iv_hex

    @property
    def cache_path(self):
        from app.core.cache import _cache_storage_dir
        cache_dir = _cache_storage_dir() / "overlays"
        cache_dir.mkdir(parents=True, exist_ok=True)
        file_hash = hashlib.md5(
            f"overlay_{self.seg.segment_hash}_{self.user_info_b64}".encode()
        ).hexdigest()
        return cache_dir / f"{file_hash}.ts"

    def __lt__(self, other):
        return self.wm_index < other.wm_index

    def __eq__(self, other):
        return self.cache_path == other.cache_path if isinstance(other, OverlayJob) else False

    def __hash__(self):
        return hash(str(self.cache_path))


class OverlayQueue:
    def __init__(self, max_concurrent=5):
        self.max_concurrent = max_concurrent
        self.queue = PriorityQueue()
        self._seen = set()
        self._lock = threading.Lock()
        self._start()

    def _start(self):
        for _ in range(self.max_concurrent):
            w = threading.Thread(target=self._worker_loop, daemon=True)
            w.start()

    def _worker_loop(self):
        while True:
            job = self.queue.get()
            try:
                if not job.cache_path.exists():
                    self._generate(job)
            finally:
                with self._lock:
                    self._seen.discard(str(job.cache_path))
                self.queue.task_done()

    def _generate(self, job):
        wm = job.wm_config
        rng = random.Random(job.seg.segment_hash + job.user_info_b64)
        count = max(1, wm.get("watermark_overlay_count", 1))
        color = wm.get("watermark_color", "FFFFFF").lstrip("#")
        fontsize = wm.get("watermark_font_size", 20)
        opacity = wm.get("watermark_opacity", 0.4)

        drawtexts = []
        for _ in range(count):
            x = rng.randint(10, max(10, job.res.width - 200))
            y = rng.randint(10, max(10, job.res.height - 50))
            drawtexts.append(
                f"drawtext=text='{job.user_info}':fontsize={fontsize}:"
                f"fontcolor={color}@{opacity}:x={x}:y={y}"
            )
        vf = ",".join(drawtexts)

        cmd = [
            "ffmpeg",
            "-i", job.seg.storage_path,
            "-fflags", "+genpts",
            "-vf", vf,
            "-map", "0:v:0",
            "-map", "0:a:0",
            "-c:v", "libx264",
            "-c:a", "copy",
            str(job.cache_path),
            "-y",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Overlay ffmpeg error: {result.stderr[-500:]}")

        if job.encryption_key_hex and job.encryption_iv_hex:
            from app.core.encryption import encrypt_file_inplace
            encrypt_file_inplace(str(job.cache_path), job.encryption_key_hex, job.encryption_iv_hex)

    def enqueue(self, job):
        key = str(job.cache_path)
        with self._lock:
            if key in self._seen:
                return
            if job.cache_path.exists():
                return
            self._seen.add(key)
        self.queue.put(job)

    @property
    def pending_count(self):
        return self.queue.qsize()


def get_overlay_queue():
    global _overlay_queue
    with _queue_lock:
        if _overlay_queue is None:
            _overlay_queue = OverlayQueue(
                max_concurrent=settings.OVERLAY_QUEUE_CONCURRENCY
            )
    return _overlay_queue
