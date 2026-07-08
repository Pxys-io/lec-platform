#!/bin/bash

BASE_URL="http://localhost:8000"
API_URL="$BASE_URL/api/v1"

echo "=========================================="
echo "LEC Main Server API Test Script"
echo "=========================================="

start_server() {
    echo "Starting server..."
    cd /home/pxy/projects/lec/main-server
    source .venv/bin/activate
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    SERVER_PID=$!
    sleep 3
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "Failed to start server"
        exit 1
    fi
    echo "Server started with PID $SERVER_PID"
}

stop_server() {
    echo "Stopping server..."
    pkill -f "uvicorn app.main:app" 2>/dev/null
    sleep 1
}

get_token() {
    echo "$1"
}

ADMIN_ID=""
STUDENT_ID=""
COURSE_ID=""
LESSON_ID=""
QUIZ_ID=""
ACCESS_TOKEN=""
REFRESH_TOKEN=""

test_auth_register_admin() {
    echo ""
    echo "=== Test: Register Admin User ==="
    RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@lec.com",
            "phone": "+1234567890",
            "password": "admin123",
            "role": "super_admin",
            "first_name": "Admin",
            "last_name": "User"
        }')
    echo "$RESPONSE"
    ADMIN_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Admin ID: $ADMIN_ID"
}

test_auth_login() {
    echo ""
    echo "=== Test: Login ==="
    RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@lec.com",
            "password": "admin123"
        }')
    echo "$RESPONSE"
    ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    REFRESH_TOKEN=$(echo "$RESPONSE" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
    echo "Access Token: ${ACCESS_TOKEN:0:20}..."
}

test_get_me() {
    echo ""
    echo "=== Test: Get Current User ==="
    curl -s -X GET "$API_URL/auth/me" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_create_course() {
    echo ""
    echo "=== Test: Create Course ==="
    RESPONSE=$(curl -s -X POST "$API_URL/courses" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "title": "Python Basics",
            "description": "Learn Python from scratch",
            "visibility": "public",
            "tags": ["default", "python", "programming"]
        }')
    echo "$RESPONSE"
    COURSE_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Course ID: $COURSE_ID"
}

test_list_courses() {
    echo ""
    echo "=== Test: List Courses ==="
    curl -s -X GET "$API_URL/courses" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_get_course() {
    echo ""
    echo "=== Test: Get Course ==="
    curl -s -X GET "$API_URL/courses/$COURSE_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_create_lesson() {
    echo ""
    echo "=== Test: Create Lesson ==="
    RESPONSE=$(curl -s -X POST "$API_URL/lessons" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"course_id\": \"$COURSE_ID\",
            \"title\": \"Introduction to Python\",
            \"description\": \"First lesson\",
            \"order\": 1,
            \"is_published\": true
        }")
    echo "$RESPONSE"
    LESSON_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Lesson ID: $LESSON_ID"
}

test_get_lesson() {
    echo ""
    echo "=== Test: Get Lesson ==="
    curl -s -X GET "$API_URL/lessons/$LESSON_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_create_quiz() {
    echo ""
    echo "=== Test: Create Quiz ==="
    RESPONSE=$(curl -s -X POST "$API_URL/quizzes" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"lesson_id\": \"$LESSON_ID\",
            \"title\": \"Python Quiz 1\",
            \"description\": \"Test your knowledge\",
            \"passing_score\": 70.0
        }")
    echo "$RESPONSE"
    QUIZ_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "Quiz ID: $QUIZ_ID"
}

test_create_question() {
    echo ""
    echo "=== Test: Create Question ==="
    curl -s -X POST "$API_URL/quizzes/$QUIZ_ID/questions" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "quiz_id": "'"$QUIZ_ID"'",
            "type": "multiple_choice",
            "question": "What is 2+2?",
            "options": ["3", "4", "5", "6"],
            "correct_answer": "4",
            "points": 1.0,
            "order": 1
        }'
}

test_get_quiz() {
    echo ""
    echo "=== Test: Get Quiz ==="
    curl -s -X GET "$API_URL/quizzes/$QUIZ_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_create_access_code() {
    echo ""
    echo "=== Test: Create Access Code ==="
    curl -s -X POST "$API_URL/codes" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"course_id\": \"$COURSE_ID\",
            \"access_type\": \"full\",
            \"access_duration\": 30
        }"
}

test_stats_overview() {
    echo ""
    echo "=== Test: Get Stats Overview ==="
    curl -s -X GET "$API_URL/stats/overview" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_video_manifest() {
    echo ""
    echo "=== Test: Get Video Manifest ==="
    curl -s -X GET "$API_URL/videos/$LESSON_ID/manifest" \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

test_health() {
    echo ""
    echo "=== Test: Health Check ==="
    curl -s "$BASE_URL/health"
}

test_root() {
    echo ""
    echo "=== Test: Root Endpoint ==="
    curl -s "$BASE_URL/"
}

echo ""
echo "Starting tests..."
echo ""

start_server

test_root
test_health
test_auth_register_admin
test_auth_login
test_get_me
test_create_course
test_list_courses
test_get_course
test_create_lesson
test_get_lesson
test_create_quiz
test_create_question
test_get_quiz
test_create_access_code
test_stats_overview
test_video_manifest

echo ""
echo "=========================================="
echo "All tests completed!"
echo "=========================================="

stop_server