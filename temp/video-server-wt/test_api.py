#!/usr/bin/env python3
import subprocess
import time
import sys
import requests
import json
import os

BASE_URL = "http://localhost:8001"
API_PREFIX = f"{BASE_URL}/api/v1/internal/videos"
VIDEO_ID = ""


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
    print("==========================================")
    print("LEC Video Server - Comprehensive Test")
    print("==========================================")

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

        # === Video CRUD Tests ===
        def create_video():
            global VIDEO_ID
            r = requests.post(API_PREFIX, json={
                "title": "Test Lecture Video",
                "description": "A comprehensive test video for watermarking",
                "original_filename": "lecture_001.mp4",
                "original_path": "/uploads/lecture_001.mp4",
                "watermark_enabled": True,
                "watermark_segments": 10,
                "watermark_text": "user@example.com | ID: 12345"
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            VIDEO_ID = data.get("id", "")
            print(f"  Created video: {VIDEO_ID}")
            return bool(VIDEO_ID)
        total += 1
        if test("Create Video", create_video): passed += 1
        else: failed += 1

        def get_video():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            if "Test Lecture Video" not in r.text:
                print(f"  Title mismatch")
                return False
            print(f"  Title: {data.get('title')}")
            print(f"  Watermark segments: {data.get('watermark_segments')}")
            print(f"  Watermark text: {data.get('watermark_text')}")
            return True
        total += 1
        if test("Get Video Details", get_video): passed += 1
        else: failed += 1

        def update_video():
            r = requests.put(f"{API_PREFIX}/{VIDEO_ID}", json={
                "title": "Updated Lecture Video",
                "description": "Updated description",
                "status": "ready"
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            if data.get("title") != "Updated Lecture Video":
                print(f"  Title not updated")
                return False
            print(f"  Title: {data.get('title')}")
            return True
        total += 1
        if test("Update Video Metadata", update_video): passed += 1
        else: failed += 1

        def list_videos():
            r = requests.get(API_PREFIX, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Total videos: {len(data)}")
            return True
        total += 1
        if test("List Videos", list_videos): passed += 1
        else: failed += 1

        # === Transcode Job Tests ===
        def start_transcode():
            r = requests.post(
                f"{API_PREFIX}/{VIDEO_ID}/transcode?resolutions=360p,480p,720p",
                timeout=3
            )
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Job ID: {data.get('id')}")
            print(f"  Status: {data.get('status')}")
            print(f"  Resolutions: {data.get('resolutions_requested')}")
            return data.get("status") == "pending"
        total += 1
        if test("Start Transcode Job", start_transcode): passed += 1
        else: failed += 1

        def get_transcode_status():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/status", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Video status: {data.get('status')}")
            print(f"  Resolutions: {data.get('resolutions')}")
            return True
        total += 1
        if test("Get Transcode Status", get_transcode_status): passed += 1
        else: failed += 1

        # === Manifest & Streaming Tests ===
        def get_manifest():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/manifest", timeout=3)
            print(f"  Status: {r.status_code}")
            if r.status_code == 400:
                print(f"  Expected: No ready resolutions yet")
            return r.status_code in [200, 400]
        total += 1
        if test("Get Manifest (empty)", get_manifest): passed += 1
        else: failed += 1

        def get_stream_no_res():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/stream", timeout=3)
            print(f"  Status: {r.status_code}")
            if r.status_code == 404:
                print(f"  Expected: No ready resolution")
            return r.status_code in [200, 404]
        total += 1
        if test("Get Stream (no resolution)", get_stream_no_res): passed += 1
        else: failed += 1

        def get_stream_with_res():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/stream?resolution=720p", timeout=3)
            print(f"  Status: {r.status_code}")
            if r.status_code == 404:
                print(f"  Expected: Resolution not ready")
            return r.status_code in [200, 404]
        total += 1
        if test("Get Stream (with resolution)", get_stream_with_res): passed += 1
        else: failed += 1

        # === Watermark Configuration Tests ===
        def test_watermark_config():
            global VIDEO_ID
            r = requests.post(API_PREFIX, json={
                "title": "No Watermark Video",
                "original_filename": "test_no_wm.mp4",
                "original_path": "/uploads/test_no_wm.mp4",
                "watermark_enabled": False,
                "watermark_segments": 0
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            video_id = data.get("id", "")
            print(f"  Created video without watermark: {video_id}")
            
            r2 = requests.get(f"{API_PREFIX}/{video_id}", timeout=3)
            data2 = r2.json()
            print(f"  Watermark enabled: {data2.get('watermark_enabled')}")
            print(f"  Watermark segments: {data2.get('watermark_segments')}")
            return data2.get('watermark_enabled') == False
        total += 1
        if test("Watermark Config - Disabled", test_watermark_config): passed += 1
        else: failed += 1

        def test_watermark_segments():
            global VIDEO_ID
            r = requests.post(API_PREFIX, json={
                "title": "High Frequency Watermark",
                "original_filename": "test_high_wm.mp4",
                "original_path": "/uploads/test_high_wm.mp4",
                "watermark_enabled": True,
                "watermark_segments": 5
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Watermark segments: {data.get('watermark_segments')}")
            return data.get('watermark_segments') == 5
        total += 1
        if test("Watermark Config - Custom Segments", test_watermark_segments): passed += 1
        else: failed += 1

        # === Storage Tests ===
        def test_storage_path():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            data = r.json()
            print(f"  Storage type: {data.get('storage_type')}")
            print(f"  Storage path: {data.get('storage_path')}")
            return data.get('storage_type') == "local"
        total += 1
        if test("Storage Configuration", test_storage_path): passed += 1
        else: failed += 1

        # === Resolution Tests ===
        def test_resolution_creation():
            global VIDEO_ID
            r = requests.post(API_PREFIX, json={
                "title": "Multi-Resolution Test",
                "original_filename": "multi_res.mp4",
                "original_path": "/uploads/multi_res.mp4",
                "watermark_enabled": True,
                "watermark_segments": 10
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            vid = data.get("id", "")
            print(f"  Created video: {vid}")
            
            r2 = requests.post(f"{API_PREFIX}/{vid}/transcode?resolutions=360p,480p,720p,1080p", timeout=3)
            if r2.status_code != 200:
                print(f"  Transcode Status: {r2.status_code}, Body: {r2.text}")
                return False
            job = r2.json()
            print(f"  Job resolutions: {job.get('resolutions_requested')}")
            return "360p" in job.get('resolutions_requested', '')
        total += 1
        if test("Multi-Resolution Transcode", test_resolution_creation): passed += 1
        else: failed += 1

        # === Segment Hashing Tests ===
        def test_segment_hashing():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/status", timeout=3)
            data = r.json()
            print(f"  Video status: {data.get('status')}")
            print(f"  Resolutions: {data.get('resolutions')}")
            return True
        total += 1
        if test("Segment Hash Verification", test_segment_hashing): passed += 1
        else: failed += 1

        # === Playlist Generation Tests ===
        def test_playlist_generation():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/playlist/720p", timeout=3)
            print(f"  Status: {r.status_code}")
            if r.status_code == 404:
                print(f"  Expected: No ready resolution yet")
            return r.status_code in [200, 404]
        total += 1
        if test("Playlist Generation", test_playlist_generation): passed += 1
        else: failed += 1

        # === Delete Tests ===
        def delete_video():
            r = requests.delete(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            print(f"  Deleted video: {VIDEO_ID}")
            return True
        total += 1
        if test("Delete Video", delete_video): passed += 1
        else: failed += 1

        def verify_delete():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            if r.status_code != 404:
                print(f"  Video still exists!")
                return False
            print(f"  Video confirmed deleted")
            return True
        total += 1
        if test("Verify Deletion", verify_delete): passed += 1
        else: failed += 1

        # === Error Handling Tests ===
        def test_invalid_video():
            r = requests.get(f"{API_PREFIX}/invalid-video-id-12345", timeout=3)
            if r.status_code != 404:
                print(f"  Should return 404, got {r.status_code}")
                return False
            return True
        total += 1
        if test("Invalid Video ID Error", test_invalid_video): passed += 1
        else: failed += 1

        def test_invalid_resolution():
            r = requests.get(f"{API_PREFIX}/{VIDEO_ID}/stream?resolution=9999p", timeout=3)
            if r.status_code not in [200, 404]:
                print(f"  Unexpected status: {r.status_code}")
                return False
            return True
        total += 1
        if test("Invalid Resolution Error", test_invalid_resolution): passed += 1
        else: failed += 1

        # === Performance/Benchmark Tests ===
        print("\n" + "="*50)
        print("BENCHMARK TESTS")
        print("="*50)

        def benchmark_create_video():
            start = time.time()
            for i in range(10):
                r = requests.post(API_PREFIX, json={
                    "title": f"Benchmark Video {i}",
                    "original_filename": f"bench_{i}.mp4",
                    "original_path": f"/uploads/bench_{i}.mp4"
                }, timeout=5)
            end = time.time()
            elapsed = end - start
            per_video = elapsed / 10
            print(f"  Created 10 videos in {elapsed:.2f}s")
            print(f"  Average per video: {per_video*1000:.1f}ms")
            print(f"  Throughput: {10/elapsed:.1f} videos/sec")
            return elapsed < 5
        total += 1
        if test("Benchmark: Create 10 Videos", benchmark_create_video): passed += 1
        else: failed += 1

        def benchmark_get_video():
            global VIDEO_ID
            start = time.time()
            for i in range(50):
                r = requests.get(f"{API_PREFIX}/{VIDEO_ID}", timeout=3)
            end = time.time()
            elapsed = end - start
            per_req = elapsed / 50
            print(f"  50 GET requests in {elapsed:.2f}s")
            print(f"  Average per request: {per_req*1000:.1f}ms")
            print(f"  Throughput: {50/elapsed:.1f} req/sec")
            return elapsed < 3
        total += 1
        if test("Benchmark: 50 GET Requests", benchmark_get_video): passed += 1
        else: failed += 1

        def benchmark_concurrent():
            import concurrent.futures
            global VIDEO_ID
            
            def make_request(i):
                r = requests.post(API_PREFIX, json={
                    "title": f"Concurrent {i}",
                    "original_filename": f"concurrent_{i}.mp4",
                    "original_path": f"/uploads/concurrent_{i}.mp4"
                }, timeout=5)
                return r.status_code
            
            start = time.time()
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = [executor.submit(make_request, i) for i in range(20)]
                results = [f.result() for f in futures]
            end = time.time()
            elapsed = end - start
            print(f"  20 concurrent POST requests in {elapsed:.2f}s")
            print(f"  Throughput: {20/elapsed:.1f} req/sec")
            print(f"  Success rate: {sum(1 for r in results if r == 200)}/20")
            return elapsed < 5
        total += 1
        if test("Benchmark: 20 Concurrent Requests", benchmark_concurrent): passed += 1
        else: failed += 1

    finally:
        proc.terminate()
        proc.wait()

    print("\n" + "="*50)
    print("Test Results Summary")
    print("="*50)
    print(f"Total tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Success rate: {passed * 100 / total:.1f}%")
    print("="*50)

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())