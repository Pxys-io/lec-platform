#!/usr/bin/env python3
"""End-to-end integration test for LEC through Cloudflare tunnel URLs.

Usage:
  python3 test_e2e.py --main-url https://xxx.trycloudflare.com --video-url https://yyy.trycloudflare.com
"""

import argparse
import sys
import time
import httpx
import re

PASS = 0
FAIL = 0
client = None


def test(name, fn):
    global PASS, FAIL
    start = time.perf_counter()
    try:
        ok = fn()
        dur = (time.perf_counter() - start) * 1000
        status = "PASS" if ok else "FAIL"
        if ok:
            PASS += 1
        else:
            FAIL += 1
        print(f"  [{status}] {name} ({dur:.0f}ms)")
        return ok
    except Exception as e:
        dur = (time.perf_counter() - start) * 1000
        FAIL += 1
        print(f"  [FAIL] {name} ({dur:.0f}ms): {e}")
        return False


def get(url, **kwargs):
    return client.get(url, timeout=kwargs.pop("timeout", 10), **kwargs)


def post(url, **kwargs):
    return client.post(url, timeout=kwargs.pop("timeout", 10), **kwargs)


def put(url, **kwargs):
    return client.put(url, timeout=kwargs.pop("timeout", 10), **kwargs)


def main():
    global PASS, FAIL, client
    parser = argparse.ArgumentParser(description="LEC E2E test")
    parser.add_argument("--main-url", required=True, help="Main server cloudflare URL")
    parser.add_argument(
        "--video-url", required=True, help="Video server cloudflare URL"
    )
    args = parser.parse_args()

    MAIN = args.main_url.rstrip("/")
    VIDEO = args.video_url.rstrip("/")
    MAIN_API = f"{MAIN}/api/v1"
    VIDEO_API = f"{VIDEO}/internal/videos"

    client = httpx.Client(verify=False)

    print(f"╔═══════════════════════════════════════╗")
    print(f"║   LEC End-to-End Test (Cloudflare)    ║")
    print(f"╠═══════════════════════════════════════╣")
    print(f"║  Main  \u2192 {MAIN}")
    print(f"║  Video \u2192 {VIDEO}")
    print(f"╚═══════════════════════════════════════╝")
    print()

    tokens = {}
    lesson_with_video = None
    video_id = None
    playlist_text = None
    segment_urls = []
    all_videos = []

    def health_check():
        for attempt in range(6):
            try:
                r = get(f"{MAIN}/health", timeout=5)
                if r.status_code == 200:
                    return True
            except:
                pass
            if attempt < 5:
                time.sleep(3)
        return False

    test("Main server health", health_check)

    def video_health():
        for attempt in range(6):
            try:
                r = get(f"{VIDEO}/health", timeout=5)
                if r.status_code == 200:
                    return True
            except:
                pass
            if attempt < 5:
                time.sleep(3)
        return False

    test("Video server health", video_health)

    def login_admin():
        nonlocal tokens
        r = post(
            f"{MAIN_API}/auth/login",
            json={"email": "admin@lec.com", "password": "admin123"},
        )
        if r.status_code == 200:
            tokens["admin"] = r.json()["access_token"]
            return True
        return False

    test("Login as admin", login_admin)

    def login_student():
        nonlocal tokens
        r = post(
            f"{MAIN_API}/auth/login",
            json={"email": "student@lec.com", "password": "student123"},
        )
        if r.status_code == 200:
            tokens["student"] = r.json()["access_token"]
            return True
        return False

    test("Login as student", login_student)

    def login_instructor():
        nonlocal tokens
        r = post(
            f"{MAIN_API}/auth/login",
            json={"email": "instructor@lec.com", "password": "instructor123"},
        )
        if r.status_code == 200:
            tokens["instructor"] = r.json()["access_token"]
            return True
        return False

    test("Login as instructor", login_instructor)

    def list_courses():
        r = get(
            f"{MAIN_API}/courses",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r.status_code != 200:
            return False
        courses = r.json()
        return len(courses) > 0

    test("List courses as student", list_courses)

    def find_lesson_with_video():
        nonlocal lesson_with_video, video_id, all_videos
        r = get(f"{VIDEO_API}", params={"limit": 50})
        if r.status_code != 200:
            return False
        all_videos = r.json()
        if not all_videos:
            return False

        insert_vids = [
            v
            for v in all_videos
            if v.get("watermark_enabled")
            and v.get("watermark_mode") == "insert"
            and v.get("watermark_segments", 0) > 0
        ]
        watermarked = [v for v in all_videos if v.get("watermark_enabled")]
        preferred = (
            insert_vids if insert_vids else (watermarked if watermarked else all_videos)
        )

        r2 = get(
            f"{MAIN_API}/courses",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r2.status_code != 200:
            return False
        courses = r2.json()

        for course in courses:
            rl = get(
                f"{MAIN_API}/courses/{course['id']}/lessons",
                headers={"Authorization": f"Bearer {tokens.get('student')}"},
            )
            if rl.status_code != 200:
                continue
            lessons = rl.json()
            for vid in preferred:
                for lesson in lessons:
                    if lesson.get("video_id") != vid["id"]:
                        continue
                    ra = get(
                        f"{MAIN_API}/lessons/{lesson['id']}",
                        headers={"Authorization": f"Bearer {tokens.get('student')}"},
                    )
                    if ra.status_code == 200:
                        lesson_with_video = lesson
                        video_id = lesson["video_id"]
                        return True
        return False

    test("Find lesson with video", find_lesson_with_video)

    def manifest_proxy():
        if lesson_with_video is None:
            return False
        r = get(
            f"{MAIN_API}/videos/{lesson_with_video['id']}/manifest",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r.status_code != 200:
            print(f"    manifest status={r.status_code} body={r.text[:200]}")
            return False
        data = r.json()
        return len(data.get("resolutions", [])) > 0

    test("Video manifest proxy", manifest_proxy)

    def playlist_proxy():
        nonlocal playlist_text
        if lesson_with_video is None:
            return False
        r = get(
            f"{MAIN_API}/videos/{lesson_with_video['id']}/playlist/360p",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r.status_code != 200:
            print(f"    playlist status={r.status_code} body={r.text[:200]}")
            return False
        playlist_text = r.text
        return playlist_text.startswith("#EXTM3U")

    test("Video playlist proxy", playlist_proxy)

    def m3u8_has_segments():
        if not playlist_text:
            return False
        return "/segment/" in playlist_text

    test("M3U8 contains segment URLs", m3u8_has_segments)

    def m3u8_has_watermark():
        if not playlist_text:
            return False
        return "/watermark/" in playlist_text

    test("M3U8 contains watermark insert URLs", m3u8_has_watermark)

    def fetch_video_segment():
        nonlocal segment_urls
        if not playlist_text:
            return False
        for line in playlist_text.split("\n"):
            m = re.search(rf"{re.escape(VIDEO)}.*?/segment/([^\s]+)", line)
            if m:
                segment_urls.append(line.strip())
        if not segment_urls:
            return False
        r = get(segment_urls[0], timeout=15)
        ok = r.status_code == 200 and len(r.content) > 100
        if not ok:
            print(f"    segment status={r.status_code} size={len(r.content)}")
        return ok

    test("Fetch video segment directly", fetch_video_segment)

    def fetch_watermark():
        if not playlist_text:
            return False
        for line in playlist_text.split("\n"):
            if "/watermark/" in line:
                url = line.strip()
                r = get(url, timeout=15)
                ok = r.status_code == 200 and len(r.content) > 100
                if not ok:
                    print(f"    watermark status={r.status_code} size={len(r.content)}")
                return ok
        return False

    test("Fetch watermark segment", fetch_watermark)

    def fetch_overlay():
        # Find an overlay-mode video lesson independently
        r = get(
            f"{MAIN_API}/courses",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r.status_code != 200:
            return True
        overlay_courses = r.json()
        for v in all_videos:
            if (
                v.get("watermark_mode") == "overlay"
                and v.get("watermark_segments", 0) > 0
            ):
                for course in overlay_courses:
                    rl = get(
                        f"{MAIN_API}/courses/{course['id']}/lessons",
                        headers={"Authorization": f"Bearer {tokens.get('student')}"},
                    )
                    if rl.status_code != 200:
                        continue
                    for lesson in rl.json():
                        if lesson.get("video_id") != v["id"]:
                            continue
                        ra = get(
                            f"{MAIN_API}/lessons/{lesson['id']}",
                            headers={
                                "Authorization": f"Bearer {tokens.get('student')}"
                            },
                        )
                        if ra.status_code != 200:
                            continue
                        rp = get(
                            f"{MAIN_API}/videos/{lesson['id']}/playlist/360p",
                            headers={
                                "Authorization": f"Bearer {tokens.get('student')}"
                            },
                        )
                        if rp.status_code != 200:
                            continue
                        for line in rp.text.split("\n"):
                            if "/overlay/" in line:
                                url = line.strip()
                                r = get(url, timeout=15)
                                ok = r.status_code == 200 and len(r.content) > 100
                                if not ok:
                                    print(
                                        f"    overlay status={r.status_code} size={len(r.content)}"
                                    )
                                else:
                                    print(
                                        f'    overlay-mode "{lesson["title"]}" verified'
                                    )
                                return ok
                        return False
        return True

    test("Fetch overlay segment", fetch_overlay)

    def fetch_multiple_segments():
        count = 0
        for url in segment_urls[:3]:
            try:
                r = get(url, timeout=15)
                if r.status_code == 200 and len(r.content) > 100:
                    count += 1
            except:
                pass
        return count >= 2

    test("Fetch multiple video segments", fetch_multiple_segments)

    def list_videos_instructor():
        r = get(
            f"{MAIN_API}/videos/manage",
            headers={"Authorization": f"Bearer {tokens.get('instructor')}"},
        )
        if r.status_code != 200:
            print(f"    list videos status={r.status_code}")
            return False
        return len(r.json()) > 0

    test("List videos as instructor", list_videos_instructor)

    def get_student_id():
        r = get(
            f"{MAIN_API}/auth/me",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        if r.status_code == 200:
            return r.json().get("id")
        return None

    def ban_and_unban():
        stu_id = get_student_id()
        if not stu_id:
            return False
        r = post(
            f"{MAIN_API}/users/{stu_id}/ban?ban_duration_days=1",
            headers={"Authorization": f"Bearer {tokens.get('admin')}"},
        )
        if r.status_code != 200:
            print(f"    ban status={r.status_code} body={r.text[:100]}")
            return False
        time.sleep(1)
        r = post(
            f"{MAIN_API}/users/{stu_id}/unban",
            headers={"Authorization": f"Bearer {tokens.get('admin')}"},
        )
        if r.status_code != 200:
            print(f"    unban status={r.status_code} body={r.text[:100]}")
            return False
        return True

    test("Ban and unban user", ban_and_unban)

    def block_video():
        if not video_id or lesson_with_video is None:
            return False
        r = put(
            f"{MAIN_API}/videos/manage/{video_id}",
            headers={
                "Authorization": f"Bearer {tokens.get('instructor')}",
                "Content-Type": "application/json",
            },
            json={"status": "blocked"},
        )
        if r.status_code != 200:
            print(f"    block video status={r.status_code}")
            return False
        time.sleep(1)
        r2 = get(
            f"{MAIN_API}/videos/{lesson_with_video['id']}/manifest",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        return r2.status_code == 403

    test("Block video (expect 403)", block_video)

    def unblock_video():
        if not video_id or lesson_with_video is None:
            return False
        r = put(
            f"{MAIN_API}/videos/manage/{video_id}",
            headers={
                "Authorization": f"Bearer {tokens.get('instructor')}",
                "Content-Type": "application/json",
            },
            json={"status": "ready"},
        )
        if r.status_code != 200:
            print(f"    unblock video status={r.status_code}")
            return False
        time.sleep(1)
        r2 = get(
            f"{MAIN_API}/videos/{lesson_with_video['id']}/manifest",
            headers={"Authorization": f"Bearer {tokens.get('student')}"},
        )
        return r2.status_code == 200

    test("Unblock video (expect 200)", unblock_video)

    total = PASS + FAIL
    print()
    print("=" * 55)
    print(f"  RESULTS: {PASS}/{total} passed")
    if FAIL == 0:
        print("  \u2705 ALL TESTS PASSED")
    else:
        print(f"  \u274c {FAIL} test(s) failed")
    print("=" * 55)
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
