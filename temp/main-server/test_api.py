#!/usr/bin/env python3
import subprocess
import time
import sys
import requests
import json

BASE_URL = "http://localhost:8000"
API_PREFIX = f"{BASE_URL}/api/v1"
ADMIN_TOKEN = ""


def kill_server():
    subprocess.run(["pkill", "-f", "uvicorn app.main:app"], capture_output=True)
    time.sleep(1)


def start_server():
    proc = subprocess.Popen(
        [".venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"],
        cwd="/home/pxy/projects/lec/main-server",
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
    print("LEC Main Server - Comprehensive Test")
    print("="*60)

    global ADMIN_TOKEN
    print("Killing existing server...")
    kill_server()

    print("Starting main server...")
    proc = start_server()

    total = 0
    passed = 0
    failed = 0
    course_id = ""
    lesson_id = ""
    quiz_id = ""
    question_id = ""
    code = ""

    try:
        # === Auth Tests ===
        def root():
            r = requests.get(f"{BASE_URL}/", timeout=3)
            return "LEC Main Server API" in r.text
        total += 1
        if test("Root Endpoint", root): passed += 1
        else: failed += 1

        def health():
            r = requests.get(f"{BASE_URL}/health", timeout=3)
            return "healthy" in r.text
        total += 1
        if test("Health Check", health): passed += 1
        else: failed += 1

        def login():
            global ADMIN_TOKEN
            r = requests.post(f"{API_PREFIX}/auth/login", json={
                "email": "admin@lec.com",
                "password": "admin123"
            }, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            ADMIN_TOKEN = data.get("access_token", "")
            return bool(ADMIN_TOKEN)
        total += 1
        if test("Login as Admin", login): passed += 1
        else: failed += 1

        def get_me():
            r = requests.get(f"{API_PREFIX}/auth/me", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            return "admin@lec.com" in r.text
        total += 1
        if test("Get Current User", get_me): passed += 1
        else: failed += 1

        # === Course Tests ===
        def create_course():
            global course_id
            r = requests.post(f"{API_PREFIX}/courses", json={
                "title": "Python Masterclass",
                "description": "Learn Python from scratch",
                "visibility": "public",
                "tags": ["python", "programming"]
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            course_id = data.get("id", "")
            print(f"  Course ID: {course_id}")
            # Verify course exists
            verify = requests.get(f"{API_PREFIX}/courses/{course_id}", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if verify.status_code != 200:
                print(f"  Course verification failed: {verify.text}")
                return False
            return bool(course_id)
        total += 1
        if test("Create Course", create_course): passed += 1
        else: failed += 1

        def list_courses():
            r = requests.get(f"{API_PREFIX}/courses", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            return r.status_code == 200
        total += 1
        if test("List Courses", list_courses): passed += 1
        else: failed += 1

        def get_course():
            r = requests.get(f"{API_PREFIX}/courses/{course_id}", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            return r.status_code == 200
        total += 1
        if test("Get Course", get_course): passed += 1
        else: failed += 1

        # === Lesson Tests ===
        def create_lesson():
            global lesson_id, course_id
            print(f"  DEBUG: course_id = '{course_id}'")
            r = requests.post(f"{API_PREFIX}/lessons", json={
                "title": "Introduction to Python",
                "description": "First lesson",
                "course_id": course_id,
                "order": 1,
                "is_published": True
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            lesson_id = data.get("id", "")
            print(f"  Lesson ID: {lesson_id}")
            return bool(lesson_id)
        total += 1
        if test("Create Lesson", create_lesson): passed += 1
        else: failed += 1

        # === Quiz Tests ===
        def create_quiz():
            global quiz_id, lesson_id
            print(f"  DEBUG: lesson_id = '{lesson_id}'")
            r = requests.post(f"{API_PREFIX}/quizzes", json={
                "title": "Python Basics Quiz",
                "description": "Test your knowledge",
                "lesson_id": lesson_id,
                "passing_score": 70.0
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            quiz_id = data.get("id", "")
            print(f"  Quiz ID: {quiz_id}")
            return bool(quiz_id)
        total += 1
        if test("Create Quiz", create_quiz): passed += 1
        else: failed += 1

        def create_question():
            global question_id, quiz_id
            print(f"  DEBUG: quiz_id = '{quiz_id}'")
            r = requests.post(f"{API_PREFIX}/quizzes/{quiz_id}/questions", json={
                "type": "multiple_choice",
                "question": "What is 2+2?",
                "options": ["3", "4", "5", "6"],
                "correct_answer": "4",
                "points": 1.0,
                "order": 1
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            question_id = data.get("id", "")
            print(f"  Question ID: {question_id}")
            print(f"  Options: {data.get('options')}")
            return bool(question_id)
        total += 1
        if test("Create Question", create_question): passed += 1
        else: failed += 1

        def submit_quiz():
            global quiz_id, question_id
            print(f"  DEBUG: quiz_id = '{quiz_id}', question_id = '{question_id}'")
            r = requests.post(f"{API_PREFIX}/quizzes/{quiz_id}/submit", json={
                "answers": {question_id: "4"}
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Score: {data.get('score')}")
            print(f"  Passed: {data.get('passed')}")
            return True
        total += 1
        if test("Submit Quiz", submit_quiz): passed += 1
        else: failed += 1

        # === Access Code Tests ===
        def create_code():
            global code
            r = requests.post(f"{API_PREFIX}/codes", json={
                "course_id": course_id,
                "access_type": "full",
                "access_duration": 30
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            code = data.get("code", "")
            print(f"  Code: {code}")
            return bool(code)
        total += 1
        if test("Create Access Code", create_code): passed += 1
        else: failed += 1

        def validate_code():
            global code
            print(f"  DEBUG: code = '{code}'")
            r = requests.post(f"{API_PREFIX}/codes/validate", json={
                "code": code
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Message: {data.get('message')}")
            return True
        total += 1
        if test("Validate Code", validate_code): passed += 1
        else: failed += 1

        # === Stats Tests ===
        def get_overview_stats():
            r = requests.get(f"{API_PREFIX}/stats/overview", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Total users: {data.get('total_users')}")
            print(f"  Total courses: {data.get('total_courses')}")
            return True
        total += 1
        if test("Get Overview Stats", get_overview_stats): passed += 1
        else: failed += 1

        def get_course_stats():
            global course_id
            print(f"  DEBUG: course_id = '{course_id}'")
            r = requests.get(f"{API_PREFIX}/stats/courses/{course_id}", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Total views: {data.get('total_views')}")
            return True
        total += 1
        if test("Get Course Stats", get_course_stats): passed += 1
        else: failed += 1

        # === Watch History Tests ===
        def record_watch():
            r = requests.post(f"{API_PREFIX}/stats/watch", json={
                "lesson_id": lesson_id,
                "watch_time": 100,
                "completion_percentage": 50,
                "last_position": 60
            }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
            if r.status_code != 200:
                print(f"  Status: {r.status_code}, Body: {r.text}")
                return False
            data = r.json()
            print(f"  Watch time: {data.get('watch_time')}")
            return True
        total += 1
        if test("Record Watch History", record_watch): passed += 1
        else: failed += 1

        # === Benchmark Tests ===
        def benchmark_courses():
            start = time.time()
            for i in range(5):
                r = requests.post(f"{API_PREFIX}/courses", json={
                    "title": f"Benchmark Course {i}",
                    "description": "Benchmark test",
                    "visibility": "public",
                    "tags": ["benchmark"]
                }, headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
                if r.status_code != 200:
                    print(f"  Failed to create course {i}")
                    return False
            end = time.time()
            elapsed = end - start
            print(f"  Created 5 courses in {elapsed:.2f}s")
            print(f"  Average: {elapsed/5*1000:.1f}ms per course")
            return elapsed < 10
        total += 1
        if test("Benchmark: 5 Courses", benchmark_courses): passed += 1
        else: failed += 1

        def benchmark_requests():
            start = time.time()
            for i in range(50):
                r = requests.get(f"{API_PREFIX}/courses", headers={"Authorization": f"Bearer {ADMIN_TOKEN}"}, timeout=3)
                if r.status_code != 200:
                    print(f"  Request {i} failed")
                    return False
            end = time.time()
            elapsed = end - start
            print(f"  50 GET requests in {elapsed:.2f}s")
            print(f"  Throughput: {50/elapsed:.1f} req/sec")
            return elapsed < 10
        total += 1
        if test("Benchmark: 50 Requests", benchmark_requests): passed += 1
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