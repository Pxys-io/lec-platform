#!/usr/bin/env python3
import subprocess
import time
import sys
import requests
import json
import os
from pathlib import Path

BASE_URL = "http://localhost:8001"
API_PREFIX = f"{BASE_URL}/api/v1/internal/videos"
VIDEO_ID = ""
TEST_VIDEO = "/home/pxy/projects/lec/video-server/test_videos/sample.mp4"


def kill_server():
    subprocess.run(["pkill", "-f", "uvicorn app.main:app"], capture_output=True)
    time.sleep(1)


def start_server():
    proc = subprocess.Popen(
        [".venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"],
        cwd="/home/pxy/projects/lec/video-server",
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    time.sleep(3)
    return proc


def test(name, fn):
    print(f"\n=== Test: {name} ===")
    try:
        result = fn()
        if result:
            print(f"PASS: {name}")
            return True
        else:
            print(f"FAIL: {name}")
            return False
    except Exception as e:
        print(f"FAIL: {name} - {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    print("="*60)
    print("LEC Video Server - Actual Transcode Test")
    print("="*60)

    global VIDEO_ID
    print("Killing existing server...")
    kill_server()

    print("Starting video server...")
    proc = start_server()

    total = 0
    passed = 0
    failed = 0

    try:
        # === Basic Tests ===
        def root():
            r = requests.get(f"{BASE_URL}/", timeout=3)
            return "LEC Video Server API" in r.text
        total += 1
        if test("Root Endpoint", root): passed += 1
        else: failed += 1

        def health():
            r = requests.get(f"{BASE_URL}/health", timeout=3)
            return "healthy" in r.text
        total += 1
        if test("Health Check", health): passed += 1
        else: failed += 1

        # === Create Test Video ===
        def create_test_video():
            if os.path.exists(TEST_VIDEO):
                print(f"  Test video already exists")
                return True
            print(f"  Creating 30-second test video...")
            result = subprocess.run([
                "ffmpeg", "-f", "lavfi", "-i", "testsrc=duration=30:size=640x480:rate=30",
                "-f", "lavfi", "-i", "sine=frequency=1000:duration=30",
                "-pix_fmt", "yuv420p", "-c:v", "libx264", "-c:a", "aac",
                "-shortest", TEST_VIDEO, "-y"
            ], capture_output=True)
            if result.returncode != 0:
                print(f"  Failed to create test video")
                return False
            print(f"  Test video created: {TEST_VIDEO}")
            return True
        total += 1
        if test("Create Test Video", create_test_video): passed += 1
        else: failed += 1

        # === Create Video with Watermark Config ===
        def create_video_with_watermark():
            global VIDEO_ID
            r = requests.post(API_PREFIX, json={
                "title": "Test Transcode Video",
                "description": "Video for transcoding and watermarking test",
                "original_filename": "test_video.mp4",
                "original_path": TEST_VIDEO,
                "watermark_enabled": True,
                "watermark_segments": 5,
                "watermark_text": "User123ID99999"
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            VIDEO_ID = data.get("id", "")
            print(f"  Created video: {VIDEO_ID}")
            print(f"  Watermark text: {data.get('watermark_text')}")
            return bool(VIDEO_ID)
        total += 1
        if test("Create Video with Watermark", create_video_with_watermark): passed += 1
        else: failed += 1

        # === Start Actual Transcode ===
        def start_actual_transcode():
            print(f"  Starting transcoding for video: {VIDEO_ID}")
            r = requests.post(
                f"{API_PREFIX}/{VIDEO_ID}/transcode",
                params={"resolutions": "360p,480p,720p", "user_id": "user123"},
                timeout=300
            )
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Job status: {data.get('status')}")
            print(f"  Progress: {data.get('progress')}")
            print(f"  Resolutions completed: {data.get('resolutions_completed')}")
            return data.get('status') == 'completed'
        total += 1
        if test("Start Actual Transcode", start_actual_transcode): passed += 1
        else: failed += 1

        # === Verify Video Status ===
        def verify_video_status():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Video status: {data.get('status')}")
            print(f"  Resolutions: {len(data.get('resolutions', []))}")
            for res in data.get('resolutions', []):
                print(f"    - {res.get('resolution')}: {res.get('segments_count')} segments")
            return data.get('status') == 'ready'
        total += 1
        if test("Verify Video Status", verify_video_status): passed += 1
        else: failed += 1

        # === Verify Storage Structure ===
        def verify_storage():
            storage_path = Path(f"./storage/videos/{VIDEO_ID}")
            if not storage_path.exists():
                print(f"  Storage path not found: {storage_path}")
                return False
            print(f"  Storage path: {storage_path}")
            for item in sorted(storage_path.iterdir()):
                if item.is_dir():
                    segments = list(item.glob("*.ts"))
                    playlist = list(item.glob("*.m3u8"))
                    print(f"  {item.name}: {len(segments)} segments, {len(playlist)} playlists")
            return True
        total += 1
        if test("Verify Storage Structure", verify_storage): passed += 1
        else: failed += 1

        # === Verify Watermark Segments ===
        def verify_watermark_segments():
            storage_path = Path(f"./storage/videos/{VIDEO_ID}")
            if not storage_path.exists():
                print(f"  Storage path not found")
                return False
            total_watermarks = 0
            for item in storage_path.iterdir():
                if item.is_dir():
                    watermarks = list(item.glob("watermark_*.ts"))
                    total_watermarks += len(watermarks)
                    if watermarks:
                        print(f"  {item.name}: {len(watermarks)} watermark segments")
            print(f"  Total watermark segments: {total_watermarks}")
            return total_watermarks > 0
        total += 1
        if test("Verify Watermark Segments", verify_watermark_segments): passed += 1
        else: failed += 1

        # === Get Manifest ===
        def get_manifest():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/manifest", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Resolutions available: {len(data.get('resolutions', []))}")
            for res in data.get('resolutions', []):
                print(f"    - {res.get('resolution')}: {res.get('segments_count')} segments")
            return True
        total += 1
        if test("Get Manifest", get_manifest): passed += 1
        else: failed += 1

        # === Get Playlist ===
        def get_playlist():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/playlist/720p", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            lines = r.text.split("\n")
            print(f"  Playlist has {len(lines)} lines")
            watermark_count = sum(1 for line in lines if "WATERMARK" in line)
            print(f"  Watermark markers: {watermark_count}")
            return watermark_count > 0
        total += 1
        if test("Get Playlist with Watermarks", get_playlist): passed += 1
        else: failed += 1

        # === Benchmark: Multiple Transcodes ===
        def benchmark_transcodes():
            print(f"  Creating and transcoding 3 videos...")
            start = time.time()
            video_ids = []
            for i in range(3):
                r = requests.post(API_PREFIX, json={
                    "title": f"Benchmark Video {i}",
                    "original_filename": "test_video.mp4",
                    "original_path": TEST_VIDEO,
                    "watermark_enabled": True,
                    "watermark_segments": 3,
                    "watermark_text": f"User{i}"
                }, timeout=3)
                if r.status_code != 200:
                    print(f"  Failed to create video {i}")
                    return False
                vid = r.json().get("id", "")
                video_ids.append(vid)
                
                # Start transcode
                r2 = requests.post(
                    f"{API_PREFIX}/{vid}/transcode",
                    params={"resolutions": "360p,480p"},
                    timeout=300
                )
                if r2.status_code != 200:
                    print(f"  Failed to transcode video {i}")
                    return False
            
            end = time.time()
            elapsed = end - start
            print(f"  Created and transcoded 3 videos in {elapsed:.1f}s")
            print(f"  Average per video: {elapsed/3:.1f}s")
            return elapsed < 300  # 5 minutes max
        total += 1
        if test("Benchmark: 3 Videos", benchmark_transcodes): passed += 1
        else: failed += 1

        # === Cleanup ===
        def cleanup():
            if os.path.exists(TEST_VIDEO):
                os.remove(TEST_VIDEO)
                print(f"  Cleaned up test video")
            return True
        total += 1
        if test("Cleanup", cleanup): passed += 1
        else: failed += 1

    finally:
        proc.terminate()
        proc.wait()

    print("\n" + "="*60)
    print("Test Results Summary")
    print("="*60)
    print(f"Total tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Success rate: {passed * 100 / total:.1f}%")
    print("="*60)

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())